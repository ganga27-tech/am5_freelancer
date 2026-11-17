from contextlib import asynccontextmanager
import asyncio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.v1.api import api_router
from app.exceptions.handlers import setup_exception_handlers
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from redis.exceptions import ConnectionError as RedisConnectionError
from redis.exceptions import TimeoutError as RedisTimeoutError
from app.core.rate_limit import limiter, rate_limit_storage_unavailable
import redis.asyncio as redis
from app.db.session import engine
from app.db.base_class import Base
import app.models  # Ensure all models are registered

from app.core.firebase_config import init_firebase
import logging

logger = logging.getLogger(__name__)

def configure_background_jobs() -> bool:
    """Start scheduled business jobs only when explicitly enabled."""
    if not settings.ENABLE_BACKGROUND_JOBS:
        return False

    from app.workers.cron_jobs import setup_cron_jobs
    setup_cron_jobs()
    return True

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Auto-create all missing tables on startup (non-destructive CREATE TABLE IF NOT EXISTS)
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        # Ensure new columns on existing freelancers table and seed defaults
        from sqlalchemy import text
        from app.db.session import AsyncSessionLocal
        from freelance_api.seed_data import seed_freelance_defaults

        async with AsyncSessionLocal() as session:
            alter_queries = [
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS photo_url VARCHAR;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS city VARCHAR;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS state VARCHAR;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS address TEXT;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS pincode VARCHAR;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS bio TEXT;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS profile_status VARCHAR DEFAULT 'active';",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS profile_completion_percentage INTEGER DEFAULT 25;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS bank_verification_status VARCHAR DEFAULT 'NOT_VERIFIED';",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS kyc_status VARCHAR DEFAULT 'NOT_STARTED';",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS face_verification_status VARCHAR DEFAULT 'NOT_STARTED';",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS total_earnings NUMERIC(12, 2) DEFAULT 0.00;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS available_balance NUMERIC(12, 2) DEFAULT 0.00;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS pending_balance NUMERIC(12, 2) DEFAULT 0.00;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS processing_balance NUMERIC(12, 2) DEFAULT 0.00;",
                "ALTER TABLE freelancers ADD COLUMN IF NOT EXISTS total_withdrawn NUMERIC(12, 2) DEFAULT 0.00;",
            ]
            for q in alter_queries:
                try:
                    await session.execute(text(q))
                except Exception:
                    pass
            await session.commit()

            try:
                await seed_freelance_defaults(session)
            except Exception:
                pass
    except Exception as e:
        import structlog
        structlog.get_logger().error("db_table_init_error", error=str(e))
        
    # Initialize Firebase Admin SDK
    init_firebase()

    
    # Setup Logging
    from app.logging.config import setup_logging
    setup_logging()
    
    # Initialize APScheduler cron jobs
    if not configure_background_jobs():
        logger.info("Background jobs disabled by ENABLE_BACKGROUND_JOBS")
    
    yield

    from app.services.otp_service import otp_service
    await otp_service.aclose()

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# Rate Limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_exception_handler(RedisConnectionError, rate_limit_storage_unavailable)
app.add_exception_handler(RedisTimeoutError, rate_limit_storage_unavailable)
app.add_middleware(SlowAPIMiddleware)

# Allowed origins for CORS
allowed_origins = [
    "https://am5royal.com",
    "https://www.am5royal.com",
    "https://vendor.am5royal.com",
    "https://admin.am5royal.com",
    "https://am5vendor.web.app",
    "https://am5vendor.firebaseapp.com",
    "https://fb-chi-nine.vercel.app",
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:8000",
]

# Add any origins from settings
origins = [str(origin) for origin in settings.BACKEND_CORS_ORIGINS] if settings.BACKEND_CORS_ORIGINS else []
for o in origins:
    if o not in allowed_origins and o != "*":
        allowed_origins.append(o)

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_origin_regex=r"https://([a-zA-Z0-9-]+\.)?am5royal\.com|https://.*\.web\.app|https://.*\.firebaseapp\.com|https://.*\.vercel\.app|http://localhost(:\d+)?|http://127\.0\.0\.1(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

setup_exception_handlers(app)

app.include_router(api_router, prefix=settings.API_V1_STR)

@limiter.exempt
@app.get("/health")
async def health_check():
    # Application liveness is independent of optional Redis availability.
    redis_client = redis.from_url(settings.REDIS_URL, socket_connect_timeout=1)
    try:
        await asyncio.wait_for(redis_client.ping(), timeout=1.0)
        redis_status = "available"
    except Exception:
        redis_status = "unavailable"
    finally:
        try:
            await redis_client.aclose()
        except Exception as exc:
            logger.debug("Redis health-check client cleanup failed (%s)", type(exc).__name__)
    return {"status": "ok", "dependencies": {"redis": redis_status}}
