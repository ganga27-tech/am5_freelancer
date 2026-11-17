from app import main
from app.core.config import settings


def test_background_jobs_can_be_disabled_without_starting_scheduler(monkeypatch):
    from app.workers import cron_jobs

    def fail_if_started():
        raise AssertionError("scheduler must stay stopped when disabled")

    monkeypatch.setattr(settings, "ENABLE_BACKGROUND_JOBS", False)
    monkeypatch.setattr(cron_jobs, "setup_cron_jobs", fail_if_started)

    assert main.configure_background_jobs() is False


def test_background_jobs_remain_enabled_by_default_behavior(monkeypatch):
    from app.workers import cron_jobs

    calls = []
    monkeypatch.setattr(settings, "ENABLE_BACKGROUND_JOBS", True)
    monkeypatch.setattr(cron_jobs, "setup_cron_jobs", lambda: calls.append("started"))

    assert main.configure_background_jobs() is True
    assert calls == ["started"]
