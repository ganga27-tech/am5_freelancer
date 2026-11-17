"""No database setup is needed for these pure provider utility tests.

Keep this directory free of autouse create_all/drop_all fixtures: those fixtures
used the application engine and could otherwise target a configured real DB.
"""
import pytest


@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"
