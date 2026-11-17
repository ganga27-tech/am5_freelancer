import logging

from fastapi import Request
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.util import get_remote_address
from app.core.config import settings

logger = logging.getLogger(__name__)

# Local development is a single-process setup, so SlowAPI's built-in memory
# backend keeps request limits active without requiring Redis. Production and
# every other environment continue to use Redis and fail closed if it is down.
LOCAL_ENVIRONMENTS = {"local", "development", "dev", "test"}
USE_LOCAL_RATE_LIMIT_STORAGE = settings.ENVIRONMENT.strip().lower() in LOCAL_ENVIRONMENTS
RATE_LIMIT_STORAGE_URI = "memory://" if USE_LOCAL_RATE_LIMIT_STORAGE else settings.REDIS_URL

limiter = Limiter(
    key_func=get_remote_address,
    storage_uri=RATE_LIMIT_STORAGE_URI,
    default_limits=["1000 per hour", "100 per minute"]
)


def rate_limit_storage_unavailable(request: Request, exc: Exception) -> JSONResponse:
    """Fail closed without leaking Redis connection details or crashing in SlowAPI."""
    logger.error("Rate-limit storage unavailable (%s)", type(exc).__name__)
    return JSONResponse(
        status_code=503,
        content={
            "success": False,
            "message": "Request protection is temporarily unavailable. Please try again.",
        },
        headers={"Retry-After": "30"},
    )
