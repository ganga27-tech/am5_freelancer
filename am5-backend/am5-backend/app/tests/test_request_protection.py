import importlib
import asyncio


def run_immediate(coroutine):
    """Run an async unit under test when all mocked awaits complete inline."""
    try:
        coroutine.send(None)
    except StopIteration as completed:
        return completed.value
    raise AssertionError("mocked operation unexpectedly yielded to an event loop")
from app.core.config import settings


def test_local_environment_uses_in_memory_rate_limit_storage(monkeypatch):
    import app.core.rate_limit as rate_limit

    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    reloaded = importlib.reload(rate_limit)
    try:
        assert reloaded.USE_LOCAL_RATE_LIMIT_STORAGE is True
        assert reloaded.RATE_LIMIT_STORAGE_URI == "memory://"
        assert reloaded.limiter.enabled is True
    finally:
        importlib.reload(rate_limit)


def test_production_environment_keeps_redis_rate_limit_storage(monkeypatch):
    import app.core.rate_limit as rate_limit

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "REDIS_URL", "redis://redis.example:6379/0")
    reloaded = importlib.reload(rate_limit)
    try:
        assert reloaded.USE_LOCAL_RATE_LIMIT_STORAGE is False
        assert reloaded.RATE_LIMIT_STORAGE_URI == "redis://redis.example:6379/0"
    finally:
        importlib.reload(rate_limit)


def test_health_reports_redis_available(monkeypatch):
    from app import main

    class FakeRedis:
        async def ping(self):
            return True

        async def aclose(self):
            return None

    monkeypatch.setattr(main.redis, "from_url", lambda *args, **kwargs: FakeRedis())
    monkeypatch.setattr(main.asyncio, "wait_for", lambda awaitable, timeout: awaitable)
    assert run_immediate(main.health_check()) == {
        "status": "ok",
        "dependencies": {"redis": "available"},
    }


def test_health_stays_healthy_and_reports_redis_unavailable(monkeypatch):
    from app import main

    class FakeRedis:
        async def ping(self):
            raise ConnectionError("Redis is offline")

        async def aclose(self):
            return None

    monkeypatch.setattr(main.redis, "from_url", lambda *args, **kwargs: FakeRedis())
    monkeypatch.setattr(main.asyncio, "wait_for", lambda awaitable, timeout: awaitable)
    assert run_immediate(main.health_check()) == {
        "status": "ok",
        "dependencies": {"redis": "unavailable"},
    }


def test_protected_endpoint_still_requires_authentication(monkeypatch):
    from app import main
    from app.dependencies.accounting_auth import get_current_accounting_user

    route = next(
        route for route in main.app.routes
        if getattr(route, "path", None) == "/api/v1/accounting/dashboard/summary"
    )
    dependency_calls = {dependency.call for dependency in route.dependant.dependencies}
    assert get_current_accounting_user in dependency_calls
