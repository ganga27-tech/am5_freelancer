import asyncio
import hashlib
import hmac
import httpx
import json
import logging
import re
import secrets
import smtplib
import ssl
import time
import redis.asyncio as redis
from app.core.config import settings
from typing import Optional
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.phone_numbers import normalize_indian_mobile

logger = logging.getLogger(__name__)


class OTPStoreUnavailable(RuntimeError):
    """OTP operations cannot safely proceed without their configured store."""


class OTPRecoveryRateLimited(RuntimeError):
    """A recovery request exceeded an account, IP, or resend limit."""


class OTPDeliveryUnavailable(RuntimeError):
    """The configured OTP provider did not accept a message."""


class OTPService:
    def __init__(self):
        self._memory_store = {}
        self._http_client: Optional[httpx.AsyncClient] = None
        try:
            self.redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            self.redis_client = None

    def _sms_client(self) -> httpx.AsyncClient:
        if self._http_client is None or self._http_client.is_closed:
            self._http_client = httpx.AsyncClient(
                timeout=httpx.Timeout(10.0, connect=5.0),
                limits=httpx.Limits(max_keepalive_connections=10, max_connections=20),
            )
        return self._http_client

    async def aclose(self) -> None:
        if self._http_client is not None and not self._http_client.is_closed:
            await self._http_client.aclose()
            self._http_client = None

    @staticmethod
    def _identifier_key(identifier: str) -> str:
        secret = OTPService._secret_key()
        value = identifier.strip()
        mobile = normalize_indian_mobile(value)
        normalized = mobile or value.lower()
        digest = hmac.new(
            secret,
            normalized.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        return f"otp:v2:{digest}"

    @staticmethod
    def _otp_digest(key: str, otp: str) -> str:
        return hmac.new(
            OTPService._secret_key(),
            f"{key}:{otp.strip()}".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

    @staticmethod
    def _secret_key() -> bytes:
        key = settings.SECRET_KEY.strip()
        if len(key) < 32:
            raise OTPStoreUnavailable("Authentication security is not configured")
        return key.encode("utf-8")

    @staticmethod
    def _allow_memory_fallback() -> bool:
        return settings.ENVIRONMENT.strip().lower() in {"development", "dev", "test"}

    async def store_otp(self, identifier: str, otp: str):
        """Store only an HMAC digest; production requires reachable Redis."""
        key = self._identifier_key(identifier)
        digest = self._otp_digest(key, otp)
        if self.redis_client:
            try:
                await asyncio.wait_for(
                    self.redis_client.setex(key, 300, digest),
                    timeout=2.0,
                )
                return
            except Exception as exc:
                logger.error("OTP storage failed (%s)", type(exc).__name__)
                if not self._allow_memory_fallback():
                    raise OTPStoreUnavailable("OTP storage is temporarily unavailable") from None

        if not self._allow_memory_fallback():
            raise OTPStoreUnavailable("OTP storage is temporarily unavailable")
        self._memory_store[key] = (digest, time.monotonic() + 300, 0)

    async def delete_otp(self, identifier: str) -> None:
        key = self._identifier_key(identifier)
        self._memory_store.pop(key, None)
        if self.redis_client:
            try:
                await self.redis_client.delete(key, f"{key}:attempts")
            except Exception as exc:
                logger.error("OTP cleanup failed (%s)", type(exc).__name__)

    async def generate_otp(self, phone: str, *, length: int = 6) -> str:
        """
        Generate a cryptographically random OTP and store only its digest.
        """
        if length not in {5, 6}:
            raise ValueError("OTP length must be 5 or 6 digits")
        maximum = 10**length
        otp = f"{secrets.randbelow(maximum):0{length}d}"
        await self.store_otp(phone, otp)
        return otp

    async def send_otp_sms(self, phone: str, otp: str) -> bool:
        """
        Send an account-verification OTP through the configured SMS gateway.
        """
        message = (
            f"Welcome to AM5ROYAL! Your OTP for registration is {otp}. "
            "Please enter this code to complete your sign-up. Do not share this code "
            "with anyone. Thank you for choosing AM5ROYAL!"
        )
        return await self._send_sms(phone, message, settings.SMS_OTP_TPID)

    def password_reset_delivery_configured(self, channel: str) -> bool:
        if channel == "email":
            required = {
                "SMTP_HOST": settings.SMTP_HOST,
                "SMTP_PORT": settings.SMTP_PORT,
                "SMTP_USER": settings.SMTP_USER,
                "SMTP_PASSWORD": settings.SMTP_PASSWORD,
                "EMAILS_FROM_EMAIL": settings.EMAILS_FROM_EMAIL,
            }
        elif channel == "sms":
            required = {
                "SMS_USER_ID": settings.SMS_USER_ID,
                "SMS_PASSWORD": settings.SMS_PASSWORD,
                "SMS_SENDER_ID": settings.SMS_SENDER_ID,
                "SMS_PEID": settings.SMS_PEID,
                "SMS_PASSWORD_RESET_TPID": settings.SMS_PASSWORD_RESET_TPID,
                "SMS_PASSWORD_RESET_TEMPLATE": (
                    settings.SMS_PASSWORD_RESET_TEMPLATE
                    if "{otp}" in settings.SMS_PASSWORD_RESET_TEMPLATE
                    else ""
                ),
            }
        else:
            return False

        missing = [name for name, value in required.items() if not value]
        if missing:
            logger.error(
                "Password-recovery %s is not configured; missing settings: %s",
                channel,
                ", ".join(missing),
            )
            return False
        return True

    async def send_password_reset_sms(self, phone: str, otp: str) -> bool:
        template = settings.SMS_PASSWORD_RESET_TEMPLATE
        if not template or "{otp}" not in template:
            logger.warning("Password-reset SMS DLT template is not configured")
            return False
        logger.info("Password-reset SMS dispatch started")
        accepted = await self._send_sms(
            phone,
            template.replace("{otp}", otp),
            settings.SMS_PASSWORD_RESET_TPID,
        )
        logger.info(
            "Password-reset SMS provider %s the request",
            "accepted" if accepted else "did not accept",
        )
        return accepted

    def _recovery_digest(self, purpose: str, value: str) -> str:
        return hmac.new(
            self._secret_key(),
            f"{purpose}:{value}".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

    def _require_redis(self):
        if not self.redis_client:
            raise OTPStoreUnavailable("OTP storage is temporarily unavailable")
        self._secret_key()
        return self.redis_client

    async def enforce_password_reset_limits(self, identifier: str, client_ip: str) -> None:
        redis_client = self._require_redis()
        identifier_key = self._recovery_digest("account", identifier)
        ip_key = self._recovery_digest("ip", client_ip or "unknown")
        window = settings.PASSWORD_RESET_RATE_WINDOW_SECONDS
        limits = (
            (f"password-reset:limit:account:{identifier_key}", settings.PASSWORD_RESET_ACCOUNT_LIMIT),
            (f"password-reset:limit:ip:{ip_key}", settings.PASSWORD_RESET_IP_LIMIT),
        )
        try:
            for key, maximum in limits:
                count = await redis_client.incr(key)
                if count == 1:
                    await redis_client.expire(key, window)
                if count > maximum:
                    raise OTPRecoveryRateLimited

            cooldown_key = f"password-reset:cooldown:{identifier_key}"
            accepted = await redis_client.set(
                cooldown_key,
                "1",
                ex=settings.OTP_RESEND_COOLDOWN_SECONDS,
                nx=True,
            )
            if not accepted:
                raise OTPRecoveryRateLimited
        except OTPRecoveryRateLimited:
            raise
        except Exception as exc:
            logger.error("Password-recovery limiter failed (%s)", type(exc).__name__)
            raise OTPStoreUnavailable("OTP storage is temporarily unavailable") from None

    async def store_password_reset_challenge(
        self,
        *,
        challenge_id: str,
        freelancer_id: int,
        identifier: str,
        channel: str,
        otp: str,
    ) -> None:
        redis_client = self._require_redis()
        identity_hash = self._recovery_digest("account", identifier)
        challenge_key = f"password-reset:challenge:{challenge_id}"
        active_key = f"password-reset:active:{identity_hash}"
        attempt_key = f"{challenge_key}:attempts"
        user_keys_key = f"password-reset:user:{freelancer_id}:keys"
        ttl = settings.PASSWORD_RESET_OTP_TTL_SECONDS
        state = json.dumps(
            {
                "freelancer_id": freelancer_id,
                "channel": channel,
                "identity_hash": identity_hash,
                "purpose": "password_recovery",
                "otp_hash": self._recovery_digest("otp", f"{challenge_id}:{otp}"),
                "expires_at": int(time.time()) + ttl,
            },
            separators=(",", ":"),
        )
        try:
            prior_challenge = await redis_client.get(active_key)
            async with redis_client.pipeline(transaction=True) as pipe:
                if prior_challenge:
                    prior_key = f"password-reset:challenge:{prior_challenge}"
                    pipe.delete(prior_key, f"{prior_key}:attempts")
                pipe.setex(challenge_key, ttl, state)
                pipe.setex(active_key, ttl, challenge_id)
                pipe.sadd(user_keys_key, challenge_key, active_key)
                pipe.expire(user_keys_key, ttl + settings.PASSWORD_RESET_TOKEN_TTL_SECONDS)
                await pipe.execute()
        except Exception as exc:
            logger.error("Password-recovery challenge storage failed (%s)", type(exc).__name__)
            raise OTPStoreUnavailable("OTP storage is temporarily unavailable") from None

    async def discard_password_reset_challenge(
        self,
        challenge_id: str,
        identifier: str,
        freelancer_id: int,
    ) -> None:
        redis_client = self._require_redis()
        identity_hash = self._recovery_digest("account", identifier)
        challenge_key = f"password-reset:challenge:{challenge_id}"
        active_key = f"password-reset:active:{identity_hash}"
        user_keys_key = f"password-reset:user:{freelancer_id}:keys"
        try:
            await redis_client.eval(
                "if redis.call('GET', KEYS[2]) == ARGV[1] then "
                "redis.call('DEL', KEYS[1], KEYS[2], KEYS[3]); return 1 end; "
                "redis.call('DEL', KEYS[1], KEYS[3]); return 0",
                3,
                challenge_key,
                active_key,
                f"{challenge_key}:attempts",
                challenge_id,
            )
            await redis_client.srem(user_keys_key, challenge_key)
        except Exception as exc:
            logger.error("Password-recovery challenge cleanup failed (%s)", type(exc).__name__)

    async def verify_password_reset_challenge(self, challenge_id: str, otp: str) -> int:
        redis_client = self._require_redis()
        challenge_key = f"password-reset:challenge:{challenge_id}"
        try:
            raw_state = await redis_client.get(challenge_key)
            if not raw_state:
                raise ValueError("Verification challenge expired or invalid")
            state = json.loads(raw_state)
            identity_hash = state.get("identity_hash")
            if not isinstance(identity_hash, str):
                raise ValueError("Verification challenge expired or invalid")
            active_key = f"password-reset:active:{identity_hash}"
            attempt_key = f"{challenge_key}:attempts"
            candidate_hash = self._recovery_digest("otp", f"{challenge_id}:{otp.strip()}")
            result = await redis_client.eval(
                "local raw=redis.call('GET',KEYS[1]); "
                "if not raw then return 'missing' end; "
                "if redis.call('GET',KEYS[2]) ~= ARGV[1] then return 'invalid' end; "
                "local s=cjson.decode(raw); "
                "if s.purpose ~= 'password_recovery' then return 'invalid' end; "
                "if tonumber(s.expires_at) <= tonumber(ARGV[4]) then "
                "redis.call('DEL',KEYS[1],KEYS[2],KEYS[3]); return 'expired' end; "
                "local n=tonumber(redis.call('GET',KEYS[3]) or '0'); "
                "if n >= tonumber(ARGV[3]) then "
                "redis.call('DEL',KEYS[1],KEYS[2],KEYS[3]); return 'locked' end; "
                "if s.otp_hash ~= ARGV[2] then "
                "n=redis.call('INCR',KEYS[3]); redis.call('EXPIRE',KEYS[3],ARGV[5]); "
                "if n >= tonumber(ARGV[3]) then "
                "redis.call('DEL',KEYS[1],KEYS[2],KEYS[3]); return 'locked' end; "
                "return 'incorrect' end; "
                "redis.call('DEL',KEYS[1],KEYS[2],KEYS[3]); "
                "return 'verified:' .. tostring(s.freelancer_id)",
                3,
                challenge_key,
                active_key,
                attempt_key,
                challenge_id,
                candidate_hash,
                settings.OTP_MAX_ATTEMPTS,
                int(time.time()),
                settings.PASSWORD_RESET_OTP_TTL_SECONDS,
            )
        except ValueError:
            raise
        except Exception as exc:
            logger.error("Password-recovery verification failed (%s)", type(exc).__name__)
            raise OTPStoreUnavailable("OTP verification is temporarily unavailable") from None

        result = str(result)
        if result.startswith("verified:"):
            return int(result.split(":", 1)[1])
        if result == "locked":
            raise ValueError("Too many incorrect codes. Request a new code.")
        if result == "expired":
            raise ValueError("OTP expired. Request a new code.")
        if result == "incorrect":
            raise ValueError("Incorrect OTP")
        raise ValueError("Verification challenge expired or invalid")

    async def store_password_reset_token(self, token: str, freelancer_id: int) -> None:
        redis_client = self._require_redis()
        token_hash = self._recovery_digest("reset-token", token)
        token_key = f"password-reset:grant:{token_hash}"
        user_keys_key = f"password-reset:user:{freelancer_id}:keys"
        try:
            async with redis_client.pipeline(transaction=True) as pipe:
                pipe.setex(
                    token_key,
                    settings.PASSWORD_RESET_TOKEN_TTL_SECONDS,
                    str(freelancer_id),
                )
                pipe.sadd(user_keys_key, token_key)
                pipe.expire(
                    user_keys_key,
                    settings.PASSWORD_RESET_TOKEN_TTL_SECONDS,
                )
                await pipe.execute()
        except Exception as exc:
            logger.error("Password-reset authorization storage failed (%s)", type(exc).__name__)
            raise OTPStoreUnavailable("Password reset is temporarily unavailable") from None

    async def consume_password_reset_token(self, token: str) -> int:
        redis_client = self._require_redis()
        token_hash = self._recovery_digest("reset-token", token)
        token_key = f"password-reset:grant:{token_hash}"
        try:
            user_id = await redis_client.eval(
                "local value=redis.call('GET',KEYS[1]); "
                "if value then redis.call('DEL',KEYS[1]); return value end; "
                "return false",
                1,
                token_key,
            )
        except Exception as exc:
            logger.error("Password-reset authorization lookup failed (%s)", type(exc).__name__)
            raise OTPStoreUnavailable("Password reset is temporarily unavailable") from None
        if not user_id:
            raise ValueError("Reset token is invalid or expired")
        return int(user_id)

    async def invalidate_password_reset_state(self, freelancer_id: int) -> None:
        redis_client = self._require_redis()
        user_keys_key = f"password-reset:user:{freelancer_id}:keys"
        try:
            keys = await redis_client.smembers(user_keys_key)
            if keys:
                await redis_client.delete(*keys)
            await redis_client.delete(user_keys_key)
        except Exception as exc:
            logger.error("Password-reset state invalidation failed (%s)", type(exc).__name__)
            raise OTPStoreUnavailable("Password reset is temporarily unavailable") from None

    async def _send_sms(self, phone: str, message: str, tpid: str) -> bool:
        clean_phone = normalize_indian_mobile(phone)
        if clean_phone is None:
            logger.warning("SMS dispatch rejected because the number is invalid")
            return False
        if not all((settings.SMS_USER_ID, settings.SMS_PASSWORD,
                    settings.SMS_SENDER_ID, settings.SMS_PEID, tpid)):
            logger.warning("SMS dispatch is not configured")
            return False

        params = {
            "userid": settings.SMS_USER_ID,
            "password": settings.SMS_PASSWORD,
            "sender": settings.SMS_SENDER_ID,
            "mobileno": clean_phone,
            "msg": message,
            "msgtype": "0",
            "peid": settings.SMS_PEID,
            "tpid": tpid,
        }
        try:
            response = await self._sms_client().get(
                "https://sms.mytext.in/websms/sendsms.aspx",
                params=params,
            )
            response.raise_for_status()
            provider_response = response.text.strip().casefold()
            accepted = bool(
                re.match(r"^(success|successful|accepted)(?:\b|\||:)", provider_response)
            )
            if not accepted:
                logger.warning("SMS provider did not accept the message")
            return accepted
        except Exception as exc:
            logger.error("SMS dispatch failed (%s)", type(exc).__name__)
            return False

    async def send_custom_sms(self, phone: str, message: str, tpid: Optional[str] = None) -> bool:
        """
        Send a custom SMS message via mytext.in SMS API.
        """
        return await self._send_sms(
            phone,
            message,
            tpid or settings.SMS_OTP_TPID,
        )

    async def send_booking_otp_sms(self, phone: str, otp: str) -> bool:
        """
        Send booking confirmation OTP using the Website OTP DLT template.
        """
        message = (
            f"Welcome to AM5ROYAL! Your OTP for service booking is {otp}. "
            "Please enter this code to confirm your booking. Do not share this code "
            "with anyone. Thank you for choosing AM5ROYAL!"
        )
        return await self.send_custom_sms(
            phone=phone,
            message=message,
            tpid=settings.SMS_BOOKING_OTP_TPID,
        )

    async def send_vendor_new_booking_sms(
        self,
        phone: str,
        customer_name: str,
        booking_id: str,
    ) -> bool:
        """
        Notify vendor of a new booking using the Customer Details DLT template.
        """
        message = (
            "Welcome to AM5ROYAL! Dear Vendor,You have received a new booking "
            f"through AM5ROYAL.Customer Name: {customer_name}, Booking ID: {booking_id}. "
            "Please log in to your AM5ROYAL account, review the booking details, "
            "and confirm the booking at the earliest. Thank you for choosing AM5ROYAL."
        )
        return await self.send_custom_sms(
            phone=phone,
            message=message,
            tpid=settings.SMS_VENDOR_BOOKING_TPID,
        )

    async def send_customer_vendor_assigned_sms(
        self,
        phone: str,
        vendor_name: str,
        booking_id: str,
        vendor_contact: str,
        service_name: str,
    ) -> bool:
        """
        Notify customer that a vendor accepted their booking (Vendor Details DLT template).
        """
        message = (
            "Welcome to AM5ROYAL! Dear Customer, your service booking has been successfully "
            f"assigned to a vendor. Vendor Name: {vendor_name}, Booking ID: {booking_id}, "
            f"Contact number: {vendor_contact}, Service:{service_name}. "
            "Please check your AM5ROYAL account for the vendor details and booking information. "
            "The assigned vendor will contact you to confirm the service schedule. "
            "Thank you for choosing AM5ROYAL. We look forward to serving you!"
        )
        return await self.send_custom_sms(
            phone=phone,
            message=message,
            tpid=settings.SMS_CUSTOMER_VENDOR_ASSIGNED_TPID,
        )

    def _send_email_sync(self, email: str, otp: str, purpose: str = "verification") -> bool:
        if not all((
            settings.SMTP_HOST,
            settings.SMTP_PORT,
            settings.SMTP_USER,
            settings.SMTP_PASSWORD,
            settings.EMAILS_FROM_EMAIL,
        )):
            logger.warning("SMTP delivery is not configured")
            return False

        is_password_reset = purpose == "password_reset"
        subject = "AM5 ROYAL password reset code" if is_password_reset else "AM5 ROYAL verification code"
        heading = "Reset your password" if is_password_reset else "Verify your account"
        instruction = (
            "Use this code to reset your AM5 ROYAL password."
            if is_password_reset
            else "Use this code to verify your AM5 ROYAL account."
        )
        message = MIMEMultipart("alternative")
        message["From"] = f"{settings.EMAILS_FROM_NAME} <{settings.EMAILS_FROM_EMAIL}>"
        message["To"] = email
        message["Subject"] = subject
        message.attach(MIMEText(
            f"{instruction} Your one-time code is {otp}. It expires in 5 minutes. "
            "Do not share this code with anyone.",
            "plain",
            "utf-8",
        ))
        message.attach(MIMEText(
            "<html><body style='font-family:Arial,sans-serif;color:#142b6f'>"
            "<h2>AM5 ROYAL</h2>"
            f"<h3>{heading}</h3><p>{instruction}</p>"
            f"<p style='font-size:28px;font-weight:bold;letter-spacing:6px'>{otp}</p>"
            "<p>This one-time code expires in 5 minutes. Do not share it.</p>"
            "</body></html>",
            "html",
            "utf-8",
        ))

        try:
            context = ssl.create_default_context()
            if settings.SMTP_PORT == 465:
                with smtplib.SMTP_SSL(
                    settings.SMTP_HOST,
                    settings.SMTP_PORT,
                    timeout=10,
                    context=context,
                ) as server:
                    server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                    refused = server.send_message(message)
            else:
                with smtplib.SMTP(
                    settings.SMTP_HOST,
                    settings.SMTP_PORT,
                    timeout=10,
                ) as server:
                    server.ehlo()
                    server.starttls(context=context)
                    server.ehlo()
                    server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                    refused = server.send_message(message)

            if refused:
                logger.warning("SMTP provider rejected one or more recipients")
                return False
            return True
        except Exception as exc:
            logger.error("SMTP dispatch failed (%s)", type(exc).__name__)
            return False

    async def send_otp_email(self, email: str, otp: str) -> bool:
        return await asyncio.to_thread(self._send_email_sync, email, otp)

    async def send_password_reset_email(self, email: str, otp: str) -> bool:
        logger.info("Password-reset email dispatch started")
        accepted = await asyncio.to_thread(
            self._send_email_sync,
            email,
            otp,
            "password_reset",
        )
        logger.info(
            "Password-reset email provider %s the request",
            "accepted" if accepted else "did not accept",
        )
        return accepted
    async def verify_otp(self, identifier: str, otp: str) -> bool:
        """
        Verify a hashed, short-lived OTP once and lock it after five failures.
        """
        key = self._identifier_key(identifier)
        attempts_key = f"{key}:attempts"
        if self.redis_client:
            try:
                stored_digest = await self.redis_client.get(key)
                if not stored_digest:
                    return False
                attempts = int(await self.redis_client.get(attempts_key) or 0)
                if attempts >= 5:
                    await self.redis_client.delete(key, attempts_key)
                    return False

                candidate = self._otp_digest(key, otp)
                if hmac.compare_digest(stored_digest, candidate):
                    consumed = await self.redis_client.eval(
                        "local v=redis.call('GET',KEYS[1]); "
                        "if v==ARGV[1] then redis.call('DEL',KEYS[1],KEYS[2]); return 1 end; "
                        "return 0",
                        2,
                        key,
                        attempts_key,
                        stored_digest,
                    )
                    return bool(consumed)

                attempts = await self.redis_client.incr(attempts_key)
                if attempts == 1:
                    await self.redis_client.expire(attempts_key, 300)
                if attempts >= 5:
                    await self.redis_client.delete(key, attempts_key)
                return False
            except Exception as exc:
                logger.error("OTP verification store failed (%s)", type(exc).__name__)
                if not self._allow_memory_fallback():
                    raise OTPStoreUnavailable(
                        "OTP verification is temporarily unavailable"
                    ) from None

        if not self._allow_memory_fallback():
            raise OTPStoreUnavailable("OTP verification is temporarily unavailable")
        entry = self._memory_store.get(key)
        if not entry:
            return False
        stored_digest, expires_at, attempts = entry
        if expires_at <= time.monotonic() or attempts >= 5:
            self._memory_store.pop(key, None)
            return False
        candidate = self._otp_digest(key, otp)
        if hmac.compare_digest(stored_digest, candidate):
            self._memory_store.pop(key, None)
            return True
        self._memory_store[key] = (stored_digest, expires_at, attempts + 1)
        return False

otp_service = OTPService()
