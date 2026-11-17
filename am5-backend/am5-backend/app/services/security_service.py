import asyncio
import time
import redis.asyncio as redis
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

_LOCAL_ENVIRONMENTS = {"local", "development", "dev", "test"}

class SecurityService:
    def __init__(self):
        self.redis_client = redis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
            socket_connect_timeout=1,
            socket_timeout=1,
        )
        self._local_blacklist = {}
        self._local_auth_versions = {}

    @staticmethod
    def _allow_local_fallback() -> bool:
        return settings.ENVIRONMENT.strip().lower() in _LOCAL_ENVIRONMENTS

    def _is_locally_blacklisted(self, token: str) -> bool:
        expires_at = self._local_blacklist.get(token, 0)
        if expires_at <= time.monotonic():
            self._local_blacklist.pop(token, None)
            return False
        return True

    async def blacklist_token(self, token: str, expiry: int = 604800): # 7 days
        """
        Blacklist a JWT token in Redis.
        """
        try:
            await asyncio.wait_for(
                self.redis_client.setex(f"blacklist:{token}", expiry, "true"),
                timeout=1.5,
            )
        except Exception as exc:
            if not self._allow_local_fallback():
                raise
            logger.warning("Using process-local session revocation (%s)", type(exc).__name__)
            self._local_blacklist[token] = time.monotonic() + max(expiry, 0)

    async def is_token_blacklisted(self, token: str) -> bool:
        """
        Check if a token is blacklisted.
        """
        try:
            return bool(await asyncio.wait_for(
                self.redis_client.exists(f"blacklist:{token}"), timeout=1.5
            ))
        except Exception as exc:
            if not self._allow_local_fallback():
                raise
            logger.warning("Using process-local session lookup (%s)", type(exc).__name__)
            return self._is_locally_blacklisted(token)

    async def freelancer_auth_version(self, freelancer_id: int) -> int:
        try:
            value = await asyncio.wait_for(
                self.redis_client.get(f"freelancer:auth-version:{freelancer_id}"),
                timeout=1.5,
            )
            return int(value or 0)
        except Exception as exc:
            if not self._allow_local_fallback():
                raise
            logger.warning("Using process-local auth version (%s)", type(exc).__name__)
            return self._local_auth_versions.get(int(freelancer_id), 0)

    async def revoke_freelancer_sessions(self, freelancer_id: int) -> int:
        """Increment the account version so all earlier Freelancer JWTs fail."""
        try:
            return int(await asyncio.wait_for(
                self.redis_client.incr(f"freelancer:auth-version:{freelancer_id}"),
                timeout=1.5,
            ))
        except Exception as exc:
            if not self._allow_local_fallback():
                raise
            logger.warning("Using process-local session revocation (%s)", type(exc).__name__)
            freelancer_id = int(freelancer_id)
            version = self._local_auth_versions.get(freelancer_id, 0) + 1
            self._local_auth_versions[freelancer_id] = version
            return version

security_service = SecurityService()
