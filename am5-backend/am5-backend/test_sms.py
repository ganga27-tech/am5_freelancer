"""Opt-in live SMS check; requires a dedicated test recipient and provider setup."""
import os
import re
import secrets

import httpx
import pytest
from dotenv import load_dotenv

load_dotenv()

_REQUIRED = (
    "SMS_USER_ID",
    "SMS_PASSWORD",
    "SMS_SENDER_ID",
    "SMS_PEID",
    "SMS_PASSWORD_RESET_TPID",
    "SMS_PASSWORD_RESET_TEMPLATE",
    "SMS_TEST_DESTINATION",
)
_READY = all(os.getenv(name) for name in _REQUIRED) and "{otp}" in os.getenv(
    "SMS_PASSWORD_RESET_TEMPLATE", ""
)


@pytest.mark.asyncio
@pytest.mark.skipif(
    not _READY,
    reason="Requires configured SMS provider and dedicated SMS_TEST_DESTINATION",
)
async def test_sms_provider_accepts_dedicated_test_request():
    otp = f"{secrets.randbelow(1_000_000):06d}"
    params = {
        "userid": os.environ["SMS_USER_ID"],
        "password": os.environ["SMS_PASSWORD"],
        "sender": os.environ["SMS_SENDER_ID"],
        "mobileno": os.environ["SMS_TEST_DESTINATION"],
        "msg": os.environ["SMS_PASSWORD_RESET_TEMPLATE"].replace("{otp}", otp),
        "msgtype": "0",
        "peid": os.environ["SMS_PEID"],
        "tpid": os.environ["SMS_PASSWORD_RESET_TPID"],
    }
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            response = await client.get(
                "https://sms.mytext.in/websms/sendsms.aspx", params=params
            )
        response.raise_for_status()
        accepted = bool(re.match(
            r"^(success|successful|accepted)(?:\b|\||:)",
            response.text.strip().casefold(),
        ))
    except Exception as exc:
        pytest.fail(f"SMS provider request failed ({type(exc).__name__})")
    assert accepted, "SMS provider did not accept the test request"
    # Provider acceptance is not proof of receipt; a tester must confirm delivery.
