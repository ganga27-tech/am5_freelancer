import pytest

from app.core.config import settings
from app.core.phone_numbers import normalize_indian_mobile
from app.core.rate_limit import rate_limit_storage_unavailable
from app.services.otp_service import OTPService, OTPDeliveryUnavailable
from fastapi import Request


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("9000000000", "9000000000"),
        ("+919000000000", "9000000000"),
        ("919000000000", "9000000000"),
        ("00919000000000", "9000000000"),
        ("09000000000", "9000000000"),
        ("5000000000", None),
        ("90000000", None),
    ],
)
def test_indian_mobile_normalization(value, expected):
    assert normalize_indian_mobile(value) == expected


@pytest.mark.asyncio
async def test_generic_otp_is_hashed_and_consumed_once(monkeypatch):
    monkeypatch.setattr(settings, "SECRET_KEY", "unit-test-secret-value-32-bytes-minimum")
    monkeypatch.setattr(settings, "ENVIRONMENT", "test")
    service = OTPService()
    service.redis_client = None

    await service.store_otp("+919000000000", "123456")
    storage_key = service._identifier_key("9000000000")
    stored_digest, _, _ = service._memory_store[storage_key]

    assert stored_digest != "123456"
    assert await service.verify_otp("919000000000", "123456") is True
    assert await service.verify_otp("9000000000", "123456") is False


@pytest.mark.asyncio
async def test_generic_otp_locks_after_maximum_attempts(monkeypatch):
    monkeypatch.setattr(settings, "SECRET_KEY", "unit-test-secret-value-32-bytes-minimum")
    monkeypatch.setattr(settings, "ENVIRONMENT", "test")
    service = OTPService()
    service.redis_client = None

    await service.store_otp("9000000000", "123456")
    for _ in range(5):
        assert await service.verify_otp("9000000000", "000000") is False
    assert await service.verify_otp("9000000000", "123456") is False


def test_rate_limit_storage_error_returns_safe_503():
    request = Request(
        {
            "type": "http",
            "asgi": {"version": "3.0", "spec_version": "2.3"},
            "http_version": "1.1",
            "method": "POST",
            "scheme": "http",
            "path": "/api/v1/freelancer/auth/forgot-password",
            "raw_path": b"/api/v1/freelancer/auth/forgot-password",
            "query_string": b"",
            "headers": [],
            "client": ("127.0.0.1", 50000),
            "server": ("testserver", 80),
        }
    )

    response = rate_limit_storage_unavailable(request, ConnectionError())

    assert response.status_code == 503
    assert response.headers["retry-after"] == "30"


@pytest.mark.asyncio
async def test_password_recovery_calls_email_provider(monkeypatch):
    from types import SimpleNamespace

    from freelance_api.service import FreelanceService
    from app.services.otp_service import otp_service

    monkeypatch.setattr(settings, "SMTP_USER", "unit-test-user")
    monkeypatch.setattr(settings, "SMTP_PASSWORD", "unit-test-password")
    monkeypatch.setattr(settings, "EMAILS_FROM_EMAIL", "no-reply@example.invalid")

    calls = []
    freelancer = SimpleNamespace(id=123, email="test@example.invalid", phone_number="9000000000")

    class Result:
        @staticmethod
        def scalars():
            return SimpleNamespace(all=lambda: [freelancer])

    class FakeDb:
        @staticmethod
        async def execute(_statement):
            return Result()

    async def no_op(*_args, **_kwargs):
        return None

    async def send_email(email, otp):
        calls.append(("email", email, len(otp)))
        return True

    monkeypatch.setattr(otp_service, "enforce_password_reset_limits", no_op)
    monkeypatch.setattr(otp_service, "store_password_reset_challenge", no_op)
    monkeypatch.setattr(otp_service, "send_password_reset_email", send_email)

    challenge_id, ttl = await FreelanceService.request_password_reset(
        FakeDb(), "test@example.invalid", "email", "127.0.0.1"
    )

    assert challenge_id
    assert ttl == settings.PASSWORD_RESET_OTP_TTL_SECONDS
    assert calls == [("email", "test@example.invalid", 6)]


@pytest.mark.asyncio
async def test_password_recovery_provider_failure_discards_challenge(monkeypatch):
    from types import SimpleNamespace

    from freelance_api.service import FreelanceService
    from app.services.otp_service import OTPDeliveryUnavailable, otp_service

    monkeypatch.setattr(settings, "SMS_USER_ID", "unit-test-user")
    monkeypatch.setattr(settings, "SMS_PASSWORD", "unit-test-password")
    monkeypatch.setattr(settings, "SMS_PASSWORD_RESET_TPID", "unit-test-template-id")
    monkeypatch.setattr(settings, "SMS_PASSWORD_RESET_TEMPLATE", "Code {otp}")

    calls = []
    freelancer = SimpleNamespace(id=123, email="test@example.invalid", phone_number="9000000000")

    class Result:
        @staticmethod
        def scalars():
            return SimpleNamespace(all=lambda: [freelancer])

    class FakeDb:
        @staticmethod
        async def execute(_statement):
            return Result()

    async def no_op(*_args, **_kwargs):
        return None

    async def send_sms(phone, otp):
        calls.append(("sms", phone, len(otp)))
        return False

    async def discard(challenge_id, identifier, freelancer_id):
        calls.append(("discard", bool(challenge_id), identifier, freelancer_id))

    monkeypatch.setattr(otp_service, "enforce_password_reset_limits", no_op)
    monkeypatch.setattr(otp_service, "store_password_reset_challenge", no_op)
    monkeypatch.setattr(otp_service, "send_password_reset_sms", send_sms)
    monkeypatch.setattr(otp_service, "discard_password_reset_challenge", discard)

    with pytest.raises(OTPDeliveryUnavailable):
        await FreelanceService.request_password_reset(
            FakeDb(), "9000000000", "sms", "127.0.0.1"
        )

    assert calls[0] == ("sms", "9000000000", 6)
    assert calls[1][0] == "discard"


def test_missing_email_settings_log_names_without_values(monkeypatch, caplog):
    from app.services.otp_service import OTPService

    monkeypatch.setattr(settings, "SMTP_USER", "")
    monkeypatch.setattr(settings, "SMTP_PASSWORD", "secret-test-value")
    monkeypatch.setattr(settings, "EMAILS_FROM_EMAIL", "")

    assert OTPService().password_reset_delivery_configured("email") is False
    assert "SMTP_USER" in caplog.text
    assert "EMAILS_FROM_EMAIL" in caplog.text
    assert "secret-test-value" not in caplog.text
