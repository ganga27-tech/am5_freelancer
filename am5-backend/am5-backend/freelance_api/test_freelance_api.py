import asyncio
import uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import parse_qs, urlsplit
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.pool import StaticPool
from jose import jwt

from app.main import app
from app.db.base_class import Base
from app.db.session import get_db
from app.models.vendor import Vendor, VendorReferralAttribution
from app.models.catalog import ServiceCategory, ServiceSubcategory
from app.models.user_location import User
from app.core.security import create_access_token
from app.dependencies.auth import get_current_admin
import freelance_api.models
from freelance_api.models import FreelancerReferralActionEvent
from freelance_api.service import (
    home_service_referral_url,
    is_valid_home_service_destination,
)
from freelance_api.seed_data import seed_freelance_defaults

test_engine = create_async_engine(
    "sqlite+aiosqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

async def override_get_db():
    async with TestingSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

app.dependency_overrides[get_db] = override_get_db


def test_home_service_destinations_match_all_permanent_vendor_urls():
    destinations = {
        3: "petcareservices",
        6: "acrepairservices",
        7: "plumbingservices",
        16: "cookingservices",
        11: "cleaningservices",
        13: "immediateservices",
        14: "pestcontrolservices",
        18: "labtest",
        9: "smartandnormalelectricalservices",
        8: "smartandnormalappliancerepairservices",
        19: "nursingservice",
        20: "painting",
        21: "physiotherapy",
        22: "waterproofing",
        5: "beautyandwellness",
        17: "homeandonlineclasses",
        10: "modularworksandinteriordesign",
        15: "caretakerservices",
        1: "2and4wheelerservices",
        12: "driverservices",
        43: "solarservices",
    }
    assert len(destinations) == 21
    assert is_valid_home_service_destination(
        999, "https://vendor.am5royal.com/map/homeservices/solarservices", "Solar Services"
    )
    assert not is_valid_home_service_destination(
        999, "https://vendor.am5royal.com/map/homeservices/other", "Solar Services"
    )
    for subcategory_id, slug in destinations.items():
        permanent_url = (
            "https://vendor.am5royal.com/map/homeservices/" + slug
        )
        assert is_valid_home_service_destination(
            subcategory_id, permanent_url
        ), f"service id {subcategory_id}: {permanent_url}"
        assert home_service_vendor_slug(999, slug) == slug
        assert is_valid_home_service_destination(
            subcategory_id, permanent_url + "?ref=unique-test-code"
        ) is False

    assert not is_valid_home_service_destination(
        14, "https://vendor.am5royal.com/map/homeservices/plumbingservices"
    )


def test_home_service_referral_urls_cover_all_21_vendor_routes():
    services = {
        3: ("Pet Care Services", "petcareservices"),
        6: ("AC Repair Services", "acrepairservices"),
        7: ("Plumbing Services", "plumbingservices"),
        16: ("Cooking Services", "cookingservices"),
        11: ("Cleaning Services", "cleaningservices"),
        12: ("Driver Services", "driverservices"),
        13: ("Immediate Services", "immediateservices"),
        14: ("Pest Control Services", "pestcontrolservices"),
        18: ("Lab Test", "labtest"),
        9: (
            "Smart and Normal Electrical Services",
            "smartandnormalelectricalservices",
        ),
        19: ("Nursing Service", "nursingservice"),
        20: ("Painting", "painting"),
        21: ("Physiotherapy", "physiotherapy"),
        22: ("Water Proofing", "waterproofing"),
        5: ("Beauty and Wellness", "beautyandwellness"),
        17: ("Home and Online Classes", "homeandonlineclasses"),
        10: (
            "Modular Works and Interior Design",
            "modularworksandinteriordesign",
        ),
        15: ("Caretaker Services", "caretakerservices"),
        1: ("2 and 4 Wheeler Services", "2and4wheelerservices"),
        8: (
            "Smart and Normal Appliance Repair Services",
            "smartandnormalappliancerepairservices",
        ),
        43: ("Solar Services", "solarservices"),
    }
    assert len(services) == 21

    generated_urls = set()
    for service_id, (name, slug) in services.items():
        code = f"FREELANCER-{service_id}-GENUINE-TEST-CODE"
        url = home_service_referral_url(service_id, name, code)
        assert url == (
            f"https://vendor.am5royal.com/map/homeservices/{slug}?ref={code}"
        )
        assert url not in generated_urls
        generated_urls.add(url)

@pytest.fixture(autouse=True)
def setup_test_db(monkeypatch):
    import asyncio
    from app.core.config import settings
    from app.main import app
    from limits.storage import MemoryStorage
    limiter = app.state.limiter

    # Each test uses in-memory SQLite and starts with a clean in-memory rate
    # limit counter. Limits stay enabled while individual tests remain isolated.
    monkeypatch.setattr(settings, "ENVIRONMENT", "test")
    monkeypatch.setattr(settings, "REFERRAL_TRACKING_BASE_URL", "https://api.am5royal.com")
    monkeypatch.setattr(
        settings,
        "SECRET_KEY",
        "test-only-jwt-signing-secret-never-use-in-production",
    )
    test_rate_limit_storage = MemoryStorage()
    monkeypatch.setattr(limiter, "_storage", test_rate_limit_storage)
    monkeypatch.setattr(limiter.limiter, "storage", test_rate_limit_storage)

    async def init():
        async with test_engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        async with TestingSessionLocal() as session:
            await seed_freelance_defaults(session)
    asyncio.run(init())
    yield

@pytest.mark.asyncio
async def test_legal_pages_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/legal-pages")
        assert response.status_code == 200
        json_data = response.json()
        assert json_data["success"] is True
        assert len(json_data["data"]) >= 2
        slugs = [p["slug"] for p in json_data["data"]]
        assert "privacy-policy" in slugs
        assert "terms-and-conditions" in slugs

@pytest.mark.asyncio
async def test_installation_rules_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/installation-rewards/rules?app_type=customer")
        assert response.status_code == 200
        json_data = response.json()
        assert json_data["success"] is True
        milestones = json_data["data"]["milestones"]
        assert len(milestones) >= 4

@pytest.mark.asyncio
async def test_installation_rules_do_not_return_unconfigured_fallback_values():
    from sqlalchemy import delete
    from freelance_api.models import FreelancerInstallationRule

    async with TestingSessionLocal() as session:
        await session.execute(delete(FreelancerInstallationRule))
        await session.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/installation-rewards/rules")
    assert response.status_code == 503
    assert "not configured" in response.json()["detail"]

@pytest.mark.asyncio
async def test_referral_rules_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/referrals/rules")
        assert response.status_code == 200
        json_data = response.json()
        assert json_data["success"] is True
        assert len(json_data["data"]["rules"]) == 4

@pytest.mark.asyncio
async def test_faqs_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/faqs?audience=freelancer")
        assert response.status_code == 200
        json_data = response.json()
        assert json_data["success"] is True

@pytest.mark.asyncio
async def test_search_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/search?q=earn&scope=all")
        assert response.status_code == 200
        json_data = response.json()
        assert json_data["success"] is True
        assert "items" in json_data["data"]

@pytest.mark.asyncio
async def test_home_banner_endpoint_maps_seeded_image_fields():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get(
            "/api/v1/banners",
            params={"placement": "home", "audience": "freelancer"},
        )

    assert response.status_code == 200
    result = response.json()
    assert result["success"] is True
    assert len(result["data"]) == 1
    banner = result["data"][0]
    assert banner["id"] == "bnr_home_01"
    assert banner["image_url"].startswith("https://")
    assert banner["mobile_image_url"].startswith("https://")
    assert banner["placement"] == "home"
    assert banner["target_audience"] == "freelancer"

def test_forgot_password_path_is_registered_at_flutter_client_route():
    registered = {
        route.path
        for route in app.routes
        if "POST" in getattr(route, "methods", set())
    }
    assert "/api/v1/freelancer/auth/forgot-password" in registered

@pytest.mark.asyncio
async def test_settings_preferences_persist_and_are_user_scoped():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        tokens = []
        for suffix, mobile in (("first", "9876500011"), ("second", "9876500012")):
            payload = {
                "full_name": f"Test User {suffix}",
                "mobile_number": mobile,
                    "email": f"settings.{suffix}@example.com",
                "password": "Password123",
                "confirm_password": "Password123",
            }
            registration = await ac.post("/api/v1/auth/register", json=payload)
            assert registration.status_code == 201
            login = await ac.post(
                "/api/v1/auth/login",
                json={"identifier": payload["email"], "password": payload["password"]},
            )
            assert login.status_code == 200
            tokens.append(login.json()["data"]["access_token"])

        first_headers = {"Authorization": f"Bearer {tokens[0]}"}
        second_headers = {"Authorization": f"Bearer {tokens[1]}"}
        changed = await ac.patch(
            "/api/v1/freelancer/settings/notifications",
            json={"email_notifications": False, "payout_alerts": False},
            headers=first_headers,
        )
        assert changed.status_code == 200
        assert changed.json()["data"]["email_notifications"] is False

        first_reload = await ac.get("/api/v1/freelancer/settings", headers=first_headers)
        second_reload = await ac.get("/api/v1/freelancer/settings", headers=second_headers)
        assert first_reload.status_code == second_reload.status_code == 200
        assert first_reload.json()["data"]["notifications"]["email_notifications"] is False
        assert second_reload.json()["data"]["notifications"]["email_notifications"] is True

@pytest.mark.asyncio
async def test_rewards_wallet_and_installation_reads_are_user_scoped():
    from decimal import Decimal
    from datetime import datetime, timedelta
    from freelance_api.models import (
        FreelancerInstallationTracking,
        FreelancerRewardItem,
        FreelancerWalletTransaction,
    )

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        tokens = []
        user_ids = []
        for suffix, mobile in (("one", "9876500021"), ("two", "9876500022")):
            payload = {
                "full_name": f"Audit User {suffix}",
                "mobile_number": mobile,
                "email": f"audit.{suffix}@example.com",
                "password": "Password123",
                "confirm_password": "Password123",
            }
            registration = await ac.post("/api/v1/auth/register", json=payload)
            assert registration.status_code == 201
            user_ids.append(registration.json()["data"]["user_id"])
            login = await ac.post(
                "/api/v1/auth/login",
                json={"identifier": payload["email"], "password": payload["password"]},
            )
            assert login.status_code == 200
            tokens.append(login.json()["data"]["access_token"])

        async with TestingSessionLocal() as session:
            session.add_all([
                FreelancerRewardItem(
                    freelancer_id=user_ids[0], reward_id="test-cashback-1",
                    reward_type="cashback", title="Test cashback",
                    amount=Decimal("12.50"), status="approved",
                ),
                FreelancerWalletTransaction(
                    freelancer_id=user_ids[0], transaction_id="test-wallet-1",
                    transaction_type="credit", category="cashback",
                    description="Test cashback credit", amount=Decimal("12.50"),
                    balance_after=Decimal("12.50"), status="completed",
                ),
                FreelancerInstallationTracking(
                    freelancer_id=user_ids[0], tracking_id="test-install-1",
                    referral_code="TESTREF1", app_type="customer",
                    install_date=datetime.utcnow(),
                    activation_date=datetime.utcnow() - timedelta(days=31),
                    retention_days_completed=30, retention_status="eligible",
                    eligibility_status="eligible", reward_status="pending",
                ),
            ])
            await session.commit()

        first_headers = {"Authorization": f"Bearer {tokens[0]}"}
        second_headers = {"Authorization": f"Bearer {tokens[1]}"}
        first_reads = await asyncio.gather(
            ac.get("/api/v1/rewards/history", headers=first_headers),
            ac.get("/api/v1/wallet/transactions", headers=first_headers),
            ac.get("/api/v1/installation-rewards/tracking", headers=first_headers),
        )
        second_reads = await asyncio.gather(
            ac.get("/api/v1/rewards/history", headers=second_headers),
            ac.get("/api/v1/wallet/transactions", headers=second_headers),
            ac.get("/api/v1/installation-rewards/tracking", headers=second_headers),
        )
        assert all(response.status_code == 200 for response in (*first_reads, *second_reads))
        assert len(first_reads[0].json()["data"]["items"]) == 1
        assert len(first_reads[1].json()["data"]["items"]) == 1
        assert len(first_reads[2].json()["data"]["items"]) == 1
        assert second_reads[0].json()["data"]["items"] == []
        assert second_reads[1].json()["data"]["items"] == []
        assert second_reads[2].json()["data"]["items"] == []

@pytest.mark.asyncio
async def test_payout_minimum_and_balance_persistence_use_test_database():
    from decimal import Decimal
    from app.models.freelancer import Freelancer

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        payload = {
            "full_name": "Wallet Audit User",
            "mobile_number": "9876500023",
            "email": "wallet.audit@example.com",
            "password": "Password123",
            "confirm_password": "Password123",
        }
        registration = await ac.post("/api/v1/auth/register", json=payload)
        assert registration.status_code == 201
        login = await ac.post(
            "/api/v1/auth/login",
            json={"identifier": payload["email"], "password": payload["password"]},
        )
        assert login.status_code == 200
        user_id = registration.json()["data"]["user_id"]
        headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}

        async with TestingSessionLocal() as session:
            user = await session.get(Freelancer, user_id)
            user.available_balance = Decimal("1000.00")
            user.bank_account_number = "123456789012"
            user.bank_ifsc_code = "HDFC0001234"
            user.bank_name = "HDFC Bank"
            await session.commit()

        rejected = await ac.post(
            "/api/v1/wallet/payout-request", json={"amount": 100}, headers=headers
        )
        assert rejected.status_code == 400
        assert "Minimum withdrawal" in rejected.json()["detail"]

        accepted = await ac.post(
            "/api/v1/wallet/payout-request", json={"amount": 500}, headers=headers
        )
        assert accepted.status_code == 201
        assert accepted.json()["data"]["amount"] == 500
        assert accepted.json()["data"]["status"] == "pending"

        async with TestingSessionLocal() as session:
            user = await session.get(Freelancer, user_id)
            assert Decimal(str(user.available_balance)) == Decimal("500.00")
            assert Decimal(str(user.processing_balance)) == Decimal("500.00")

@pytest.mark.asyncio
async def test_auth_registration_and_login():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        reg_payload = {
            "full_name": "Ravi Kumar",
            "mobile_number": "9876543210",
            "email": "ravi.kumar@example.com",
            "password": "Password123",
            "confirm_password": "Password123"
        }
        reg_res = await ac.post("/api/v1/auth/register", json=reg_payload)
        assert reg_res.status_code == 201
        reg_data = reg_res.json()
        assert reg_data["success"] is True
        user_id = reg_data["data"]["user_id"]

        login_payload = {
            "identifier": "ravi.kumar@example.com",
            "password": "Password123"
        }
        invalid_login = await ac.post(
            "/api/v1/auth/login",
            json={**login_payload, "password": "WrongPassword123"},
        )
        assert invalid_login.status_code == 401
        login_res = await ac.post("/api/v1/auth/login", json=login_payload)
        assert login_res.status_code == 200
        login_data = login_res.json()
        assert login_data["success"] is True
        token = login_data["data"]["access_token"]
        assert token is not None

        headers = {"Authorization": f"Bearer {token}"}
        prof_res = await ac.get("/api/v1/freelancer/profile", headers=headers)
        assert prof_res.status_code == 200
        prof_data = prof_res.json()
        assert prof_data["success"] is True
        assert prof_data["data"]["user_id"] == user_id
        assert prof_data["data"]["full_name"] == "Ravi Kumar"

        update_res = await ac.patch(
            "/api/v1/freelancer/profile",
            json={
                "full_name": "Ravi Updated",
                "address": "12 Test Road",
                "city": "Vijayawada",
                "state": "Andhra Pradesh",
                "pincode": "520001",
            },
            headers=headers,
        )
        assert update_res.status_code == 200
        assert update_res.json()["data"]["full_name"] == "Ravi Updated"
        assert update_res.json()["data"]["address"] == "12 Test Road"
        assert update_res.json()["data"]["city"] == "Vijayawada"
        assert update_res.json()["data"]["state"] == "Andhra Pradesh"
        assert update_res.json()["data"]["pincode"] == "520001"

        refreshed = await ac.get("/api/v1/freelancer/profile", headers=headers)
        refreshed_data = refreshed.json()["data"]
        assert refreshed_data["user_id"] == user_id
        assert refreshed_data["full_name"] == "Ravi Updated"
        assert refreshed_data["mobile"] == "9876543210"
        assert refreshed_data["email"] == "ravi.kumar@example.com"
        assert refreshed_data["address"] == "12 Test Road"
        assert refreshed_data["city"] == "Vijayawada"
        assert refreshed_data["state"] == "Andhra Pradesh"
        assert refreshed_data["pincode"] == "520001"
        assert refreshed_data["completion_percentage"] == 50

        bank_res = await ac.put(
            "/api/v1/freelancer/bank-details",
            json={
                "account_holder_name": "Ravi Kumar",
                "account_number": "123456789012",
                "ifsc_code": "HDFC0001234",
                "bank_name": "HDFC Bank",
            },
            headers=headers,
        )
        assert bank_res.status_code == 200
        assert bank_res.json()["data"]["masked_account_number"].endswith("9012")
        assert "123456789012" not in bank_res.text

        refreshed = await ac.get("/api/v1/freelancer/profile", headers=headers)
        assert refreshed.json()["data"]["completion_percentage"] == 75


@pytest.mark.asyncio
async def test_referral_links_create_list_and_enforce_owner_scope():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        suffix = f"{uuid.uuid4().int % 1_000_000_000:09d}"
        tokens = []
        for role, prefix in (("owner", "7"), ("other", "8")):
            payload = {
                "full_name": f"Referral {role}",
                "mobile_number": prefix + suffix,
                "email": f"referral.{role}.{suffix}@example.com",
                "password": "Password123",
                "confirm_password": "Password123",
            }
            registered = await ac.post("/api/v1/auth/register", json=payload)
            assert registered.status_code == 201
            login = await ac.post(
                "/api/v1/auth/login",
                json={"identifier": payload["email"], "password": payload["password"]},
            )
            assert login.status_code == 200
            tokens.append(login.json()["data"]["access_token"])

        owner = {"Authorization": f"Bearer {tokens[0]}"}
        other = {"Authorization": f"Bearer {tokens[1]}"}
        generated = await ac.post(
            "/api/v1/referrals/links",
            json={"referral_type": "customer", "validity_days": 7},
            headers=owner,
        )
        assert generated.status_code == 201
        link = generated.json()["data"]
        assert link["referral_code"] and link["url"].startswith("https://")
        assert link["referral_type"] == "customer"
        assert link["created_at"] and link["expires_at"]
        customer_created = datetime.fromisoformat(link["created_at"].replace("Z", "+00:00"))
        customer_expires = datetime.fromisoformat(link["expires_at"].replace("Z", "+00:00"))
        customer_validity = customer_expires - customer_created
        assert timedelta(days=7) - timedelta(minutes=1) < customer_validity <= timedelta(days=7)

        second_link = await ac.post(
            "/api/v1/referrals/links",
            json={"referral_type": "vendor", "validity_days": 15},
            headers=owner,
        )
        assert second_link.status_code == 201
        vendor_link = second_link.json()["data"]
        assert vendor_link["referral_type"] == "vendor"
        assert vendor_link["referral_code"]
        assert vendor_link["referral_code"] != link["referral_code"]
        assert vendor_link["referral_id"] != link["referral_id"]
        reused_vendor = await ac.post(
            "/api/v1/referrals/links",
            json={"referral_type": "vendor", "validity_days": 15},
            headers=owner,
        )
        assert reused_vendor.status_code == 200
        reused_vendor_data = reused_vendor.json()["data"]
        assert reused_vendor_data["reused_existing"] is True
        for key in ("referral_id", "referral_code", "url", "created_at", "expires_at"):
            assert reused_vendor_data[key] == vendor_link[key]
        other_vendor_link_response = await ac.post(
            "/api/v1/referrals/links",
            json={"referral_type": "vendor", "validity_days": 15},
            headers=other,
        )
        assert other_vendor_link_response.status_code == 201
        assert (
            other_vendor_link_response.json()["data"]["referral_code"]
            != vendor_link["referral_code"]
        )
        vendor_url = urlsplit(vendor_link["url"])
        assert vendor_url.scheme == "https"
        assert vendor_url.netloc == "api.am5royal.com"
        assert vendor_url.path == (
            "/api/v1/referrals/vendor/click/" + vendor_link["referral_code"]
        )
        click_response = await ac.get(vendor_link["url"], follow_redirects=False)
        assert click_response.status_code == 302
        play_store_url = urlsplit(click_response.headers["location"])
        assert play_store_url.scheme == "https"
        assert play_store_url.netloc == "play.google.com"
        assert play_store_url.path == "/store/apps/details"
        assert parse_qs(play_store_url.query)["id"] == ["com.am5royal.am5royal"]
        campaign = parse_qs(play_store_url.query)["referrer"][0]
        campaign_params = parse_qs(campaign)
        assert campaign_params["referral_type"] == ["vendor"]
        assert campaign_params["referral_code"] == [vendor_link["referral_code"]]
        assert campaign_params["referrer_name"] == ["Referral owner"]
        click_id = campaign_params["click_id"][0]
        second_click_response = await ac.get(vendor_link["url"], follow_redirects=False)
        assert second_click_response.status_code == 302
        second_campaign = parse_qs(
            parse_qs(urlsplit(second_click_response.headers["location"]).query)["referrer"][0]
        )
        assert second_campaign["click_id"][0] != click_id
        vendor_created = datetime.fromisoformat(vendor_link["created_at"].replace("Z", "+00:00"))
        vendor_expires = datetime.fromisoformat(vendor_link["expires_at"].replace("Z", "+00:00"))
        vendor_validity = vendor_expires - vendor_created
        assert vendor_validity == timedelta(days=15)

        invalid_vendor_validity = await ac.post(
            "/api/v1/referrals/links",
            json={"referral_type": "vendor", "validity_days": 7},
            headers=owner,
        )
        assert invalid_vendor_validity.status_code == 422

        install_payload = {
            "referral_code": vendor_link["referral_code"],
            "click_id": click_id,
            "referrer_click_timestamp_seconds": int(datetime.now(timezone.utc).timestamp()),
            "install_begin_timestamp_seconds": int(datetime.now(timezone.utc).timestamp()),
        }
        invalid_click_install = await ac.post(
            "/api/v1/referrals/vendor/install",
            json={**install_payload, "click_id": "0" * 64},
        )
        assert invalid_click_install.status_code == 404
        first_install = await ac.post(
            "/api/v1/referrals/vendor/install", json=install_payload
        )
        second_install = await ac.post(
            "/api/v1/referrals/vendor/install", json=install_payload
        )
        assert first_install.status_code == second_install.status_code == 200
        assert first_install.json()["data"]["duplicate"] is False
        assert second_install.json()["data"]["duplicate"] is True

        active_customer = await ac.get(
            f"/api/v1/referrals/validate/{link['referral_code']}"
        )
        assert active_customer.status_code == 200
        assert active_customer.json()["data"]["valid"] is True

        async with TestingSessionLocal() as session:
            stored_vendor_link = (
                await session.execute(
                    select(freelance_api.models.FreelancerReferralLink).where(
                        freelance_api.models.FreelancerReferralLink.referral_code
                        == vendor_link["referral_code"]
                    )
                )
            ).scalar_one()
            stored_vendor_link.expires_at = (
                datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=1)
            )
            await session.commit()

        expired_vendor = await ac.get(
            f"/api/v1/referrals/validate/{vendor_link['referral_code']}"
        )
        assert expired_vendor.status_code == 200
        assert expired_vendor.json()["success"] is False
        assert expired_vendor.json()["data"]["valid"] is False
        assert expired_vendor.json()["data"]["status"] == "expired"

        replacement = await ac.post(
            "/api/v1/referrals/links",
            json={"referral_type": "vendor", "validity_days": 15},
            headers=owner,
        )
        assert replacement.status_code == 201
        replacement_link = replacement.json()["data"]
        assert replacement_link["referral_code"] != vendor_link["referral_code"]
        assert replacement_link["referral_id"] != vendor_link["referral_id"]

        invalid_referral = await ac.get(
            "/api/v1/referrals/validate/not-a-real-referral-code"
        )
        assert invalid_referral.status_code == 200
        assert invalid_referral.json()["success"] is False
        assert invalid_referral.json()["data"]["valid"] is False
        assert invalid_referral.json()["data"]["status"] == "not_found"

        owner_links = await ac.get("/api/v1/referrals/links", headers=owner)
        other_links = await ac.get("/api/v1/referrals/links", headers=other)
        assert owner_links.status_code == other_links.status_code == 200
        assert any(row["referral_code"] == link["referral_code"] for row in owner_links.json()["data"]["items"])
        assert all(row["referral_code"] != link["referral_code"] for row in other_links.json()["data"]["items"])

        owner_freelancer_id = int(jwt.get_unverified_claims(tokens[0])["sub"])
        async with TestingSessionLocal() as session:
            attributed_vendor_id = int(uuid.uuid4().int % 900_000_000) + 8_000_000_000
            session.add(
                Vendor(
                    id=attributed_vendor_id,
                    user_id=int(uuid.uuid4().int % 900_000_000) + 9_000_000_000,
                    freelancer_id=owner_freelancer_id,
                    business_name="Referral Dashboard Test Vendor",
                    city="Test City",
                    state="Test State",
                    status="active",
                )
            )
            session.add(
                VendorReferralAttribution(
                    vendor_id=attributed_vendor_id,
                    freelancer_id=owner_freelancer_id,
                    referral_link_id=int(replacement_link["referral_id"].removeprefix("ref_")),
                    referral_code=replacement_link["referral_code"],
                    service_id=None,
                    attributed_at=datetime.now(timezone.utc),
                )
            )
            session.add(
                freelance_api.models.FreelancerInstallationTracking(
                    freelancer_id=owner_freelancer_id,
                    tracking_id=f"test-vendor-install-{uuid.uuid4().hex}",
                    referral_code=replacement_link["referral_code"],
                    app_type="vendor",
                    activation_date=datetime.now(timezone.utc),
                )
            )
            await session.commit()

        owner_dashboard = await ac.get(
            "/api/v1/referrals/vendor/dashboard", headers=owner
        )
        other_dashboard = await ac.get(
            "/api/v1/referrals/vendor/dashboard", headers=other
        )
        assert owner_dashboard.status_code == other_dashboard.status_code == 200
        owner_stats = owner_dashboard.json()["data"]
        other_stats = other_dashboard.json()["data"]
        assert owner_stats["freelancer_name"] == "Referral owner"
        assert owner_stats["total_invitations"] == 2
        assert owner_stats["total_referral_link_clicks"] == 1
        assert owner_stats["unique_link_opens"] == 1
        assert owner_stats["play_store_clicks"] == 1
        assert owner_stats["app_installs"] == 2
        assert owner_stats["vendor_registrations"] == 1
        assert owner_stats["active_vendors"] == 1
        assert owner_stats["pending_registrations"] == 1
        assert other_stats["total_invitations"] == 0
        assert other_stats["app_installs"] == 0
        assert other_stats["vendor_registrations"] == 0


@pytest.mark.asyncio
async def test_referral_links_accept_only_supported_validity_days():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        suffix = f"{uuid.uuid4().int % 1_000_000_000:09d}"
        payload = {
            "full_name": "Referral Validity",
            "mobile_number": "7" + suffix,
            "email": f"referral.validity.{suffix}@example.com",
            "password": "Password123",
            "confirm_password": "Password123",
        }
        registered = await ac.post("/api/v1/auth/register", json=payload)
        assert registered.status_code == 201
        login = await ac.post(
            "/api/v1/auth/login",
            json={"identifier": payload["email"], "password": payload["password"]},
        )
        headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}
        invalid = await ac.post(
            "/api/v1/referrals/links",
            json={"referral_type": "vendor", "validity_days": 30},
            headers=headers,
        )
        assert invalid.status_code == 422


@pytest.mark.asyncio
async def test_home_service_referral_urls_keep_service_and_exact_validity(
    monkeypatch
):
    from app.core.config import settings

    # Home Services deep links do not require a public tracking origin.
    monkeypatch.setattr(settings, "REFERRAL_TRACKING_BASE_URL", "http://127.0.0.1:8001")
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        suffix = f"{uuid.uuid4().int % 1_000_000_000:09d}"
        payload = {
            "full_name": "Home Referral Test",
            "mobile_number": "7" + suffix,
            "email": f"home.referral.{suffix}@example.com",
            "password": "Password123",
            "confirm_password": "Password123",
        }
        registered = await ac.post("/api/v1/auth/register", json=payload)
        assert registered.status_code == 201
        login = await ac.post(
            "/api/v1/auth/login",
            json={"identifier": payload["email"], "password": payload["password"]},
        )
        headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}

        async with TestingSessionLocal() as session:
            category = await session.get(ServiceCategory, 37)
            if category is None:
                category = ServiceCategory(id=37, name="Home Services", is_active=True)
                session.add(category)
            service_fixtures = (
                (3, "Pet Care Services"),
                (7, "Plumbing Services"),
                (21, "Physiotherapy"),
            )
            for service_id, service_name in service_fixtures:
                existing_service = await session.get(ServiceSubcategory, service_id)
                if existing_service is None:
                    session.add(ServiceSubcategory(
                        id=service_id,
                        main_category_id=37,
                        name=service_name,
                        is_active=True,
                    ))
                else:
                    assert existing_service.main_category_id == 37
                    assert existing_service.name == service_name
            await session.commit()

        for days, service_id, service_name, slug in (
            (7, 3, "Pet Care Services", "petcareservices"),
            (15, 7, "Plumbing Services", "plumbingservices"),
            (7, 21, "Physiotherapy", "physiotherapy"),
        ):
            service_url = f"https://vendor.am5royal.com/map/homeservices/{slug}"
            created = await ac.post(
                "/api/v1/referrals/links",
                json={
                    "referral_type": "service",
                    "target_sub_service_id": service_id,
                    "target_service_url": service_url,
                    "validity_days": days,
                },
                headers=headers,
            )
            assert created.status_code == 201, created.text
            link = created.json()["data"]
            assert link["referral_type"] == "service"
            assert link["validity_days"] == days
            assert link["reused_existing"] is False
            assert link["target_service_category_id"] == 37
            assert link["target_service_id"] == service_id

            if days == 7:
                reused = await ac.post(
                    "/api/v1/referrals/links",
                    json={
                        "referral_type": "service",
                        "target_sub_service_id": service_id,
                        "target_service_url": service_url,
                        "validity_days": 15,
                    },
                    headers=headers,
                )
                assert reused.status_code == 200, reused.text
                reused_link = reused.json()["data"]
                assert reused_link["reused_existing"] is True
                assert reused_link["referral_id"] == link["referral_id"]
                assert reused_link["referral_code"] == link["referral_code"]
                assert reused_link["url"] == link["url"]
                assert reused_link["created_at"] == link["created_at"]
                assert reused_link["expires_at"] == link["expires_at"]
                assert reused_link["validity_days"] == 7
                third_request = await ac.post(
                    "/api/v1/referrals/links",
                    json={
                        "referral_type": "service",
                        "target_sub_service_id": service_id,
                        "target_service_url": service_url,
                        "validity_days": 7,
                    },
                    headers=headers,
                )
                assert third_request.status_code == 200
                assert third_request.json()["data"]["referral_id"] == link["referral_id"]
                assert third_request.json()["data"]["referral_code"] == link["referral_code"]
                async with TestingSessionLocal() as session:
                    stored = await session.get(
                        freelance_api.models.FreelancerReferralLink,
                        int(link["referral_id"].removeprefix("ref_")),
                    )
                    count = await session.scalar(
                        select(func.count(freelance_api.models.FreelancerReferralLink.id)).where(
                            freelance_api.models.FreelancerReferralLink.freelancer_id
                            == stored.freelancer_id,
                            freelance_api.models.FreelancerReferralLink.referral_type
                            == "service",
                            freelance_api.models.FreelancerReferralLink.target_sub_service_id
                            == service_id,
                        )
                    )
                    assert count == 1

            history = await ac.get(
                "/api/v1/referrals/links",
                params={"type": "service", "page": 1, "limit": 100},
                headers=headers,
            )
            assert history.status_code == 200, history.text
            history_link = next(
                item for item in history.json()["data"]["items"]
                if item["referral_code"] == link["referral_code"]
            )
            assert history_link["target_service_category_id"] == 37
            assert history_link["target_service_id"] == service_id
            assert history_link["url"] == link["url"]
            assert link["url"] == f"{service_url}?ref={link['referral_code']}"
            visitor_token = f"qa-visitor-{days}"
            event_token = f"qa-event-{days}"
            cookie_header = (
                f"__Host-am5_referral_visitor={visitor_token}; "
                f"__Host-am5_referral_event={event_token}"
            )
            clicked = await ac.get(
                f"/api/v1/referrals/service/click/{link['referral_code']}",
                headers={"cookie": cookie_header},
                follow_redirects=False,
            )
            assert clicked.status_code == 302
            first_click_id = parse_qs(
                urlsplit(clicked.headers["location"]).query
            )["click_id"][0]
            assert clicked.headers["location"] == (
                service_url + f"?ref={link['referral_code']}&click_id={first_click_id}"
            )
            assert len(first_click_id) == 64
            verified_existing_click = await ac.get(
                f"/api/v1/referrals/service/click/{link['referral_code']}",
                params={"verify_click": "true", "click_id": first_click_id},
                follow_redirects=False,
            )
            assert verified_existing_click.status_code == 200
            assert verified_existing_click.json()["data"]["click_id"] == first_click_id
            tracked_without_redirect = await ac.get(
                f"/api/v1/referrals/service/click/{link['referral_code']}",
                params={"redirect": "false"},
                headers={"cookie": cookie_header},
                follow_redirects=False,
            )
            assert tracked_without_redirect.status_code == 200
            second_click_destination = tracked_without_redirect.json()["data"]["destination_url"]
            assert second_click_destination.startswith(
                service_url + f"?ref={link['referral_code']}&click_id="
            )
            assert second_click_destination != clicked.headers["location"]
            async with TestingSessionLocal() as session:
                tracked = (await session.execute(
                    select(freelance_api.models.FreelancerReferralClickEvent).where(
                        freelance_api.models.FreelancerReferralClickEvent.referral_id
                        == int(link["referral_id"].removeprefix("ref_"))
                    )
                )).scalars().all()
                assert len(tracked) == 2
                assert all(event.destination_type == "SERVICE" for event in tracked)
                assert all(event.service_id == service_id for event in tracked)
                assert clicked.headers["location"] in [event.destination_url for event in tracked]
            retry = await ac.get(
                f"/api/v1/referrals/service/click/{link['referral_code']}",
                headers={"cookie": cookie_header},
                follow_redirects=False,
            )
            assert retry.status_code == 302
            async with TestingSessionLocal() as session:
                tracked_count = await session.scalar(
                    select(func.count(freelance_api.models.FreelancerReferralClickEvent.id)).where(
                        freelance_api.models.FreelancerReferralClickEvent.referral_id
                        == int(link["referral_id"].removeprefix("ref_"))
                    )
                )
                assert tracked_count == 3
            if days == 7:
                for recipient in range(10):
                    recipient_cookies = (
                        f"__Host-am5_referral_visitor=qa-recipient-{recipient}; "
                        f"__Host-am5_referral_event=qa-recipient-event-{recipient}"
                    )
                    recipient_click = await ac.get(
                        f"/api/v1/referrals/service/click/{link['referral_code']}",
                        headers={"cookie": recipient_cookies},
                        follow_redirects=False,
                    )
                    assert recipient_click.status_code == 302
                    recipient_destination = recipient_click.headers["location"]
                    assert recipient_destination.startswith(
                        service_url + f"?ref={link['referral_code']}&click_id="
                    )
                async with TestingSessionLocal() as session:
                    recipient_click_count = await session.scalar(
                        select(func.count(freelance_api.models.FreelancerReferralClickEvent.id)).where(
                            freelance_api.models.FreelancerReferralClickEvent.referral_id
                            == int(link["referral_id"].removeprefix("ref_"))
                        )
                    )
                    recipient_unique_ids = await session.scalar(
                        select(func.count(func.distinct(
                            freelance_api.models.FreelancerReferralClickEvent.event_id
                        ))).where(
                            freelance_api.models.FreelancerReferralClickEvent.referral_id
                            == int(link["referral_id"].removeprefix("ref_"))
                        )
                    )
                    assert recipient_click_count == 13
                    assert recipient_unique_ids == 13
            created_at = datetime.fromisoformat(link["created_at"].replace("Z", "+00:00"))
            expires_at = datetime.fromisoformat(link["expires_at"].replace("Z", "+00:00"))
            assert expires_at - created_at == timedelta(days=days)

            validated = await ac.get(
                f"/api/v1/referrals/validate/{link['referral_code']}"
            )
            data = validated.json()["data"]
            assert data["valid"] is True
            assert data["referral_type"] == "service"
            assert data["referral_id"] == int(link["referral_id"].removeprefix("ref_"))
            assert data["target_service"] == {
                "id": service_id,
                "name": service_name,
                "main_category_id": 37,
            }
            async with TestingSessionLocal() as session:
                validated_link = await session.get(
                    freelance_api.models.FreelancerReferralLink,
                    int(link["referral_id"].removeprefix("ref_")),
                )
                assert validated_link.clicks_count == 0

            async with TestingSessionLocal() as session:
                stored_link = await session.get(
                    freelance_api.models.FreelancerReferralLink,
                    int(link["referral_id"].removeprefix("ref_")),
                )
                stored_link.expires_at = (
                    datetime.now(timezone.utc).replace(tzinfo=None)
                    - timedelta(minutes=1)
                )
                await session.commit()

            expired = await ac.get(
                f"/api/v1/referrals/validate/{link['referral_code']}"
            )
            assert expired.status_code == 200
            assert expired.json()["success"] is False
            assert expired.json()["data"]["valid"] is False
            assert expired.json()["data"]["status"] == "expired"

            expired_click = await ac.get(
                f"/api/v1/referrals/service/click/{link['referral_code']}",
                follow_redirects=False,
            )
            assert expired_click.status_code == 404
            async with TestingSessionLocal() as session:
                expired_click_count = await session.scalar(
                    select(func.count(freelance_api.models.FreelancerReferralClickEvent.id)).where(
                        freelance_api.models.FreelancerReferralClickEvent.referral_id
                        == int(link["referral_id"].removeprefix("ref_"))
                    )
                )
                assert expired_click_count == (13 if days == 7 else 3)

            replacement = await ac.post(
                "/api/v1/referrals/links",
                json={
                    "referral_type": "service",
                    "target_sub_service_id": service_id,
                    "target_service_url": service_url,
                    "validity_days": days,
                },
                headers=headers,
            )
            assert replacement.status_code == 201, replacement.text
            replacement_link = replacement.json()["data"]
            assert replacement_link["referral_code"] != link["referral_code"]
            assert replacement_link["referral_id"] != link["referral_id"]
            assert replacement_link["validity_days"] == days

            replacement_id = int(
                replacement_link["referral_id"].removeprefix("ref_")
            )
            async with TestingSessionLocal() as session:
                old_id = int(link["referral_id"].removeprefix("ref_"))
                old_link = await session.get(
                    freelance_api.models.FreelancerReferralLink,
                    old_id,
                )
                assert old_link.status == "expired"
                preserved_clicks = await session.scalar(
                    select(func.count(freelance_api.models.FreelancerReferralClickEvent.id)).where(
                        freelance_api.models.FreelancerReferralClickEvent.referral_id
                        == old_id
                    )
                )
                assert preserved_clicks == (13 if days == 7 else 3)
                inactive_link = await session.get(
                    freelance_api.models.FreelancerReferralLink,
                    replacement_id,
                )
                inactive_link.status = "inactive"
                await session.commit()

            inactive_click = await ac.get(
                f"/api/v1/referrals/service/click/{replacement_link['referral_code']}",
                follow_redirects=False,
            )
            assert inactive_click.status_code == 404
            invalid_click = await ac.get(
                "/api/v1/referrals/service/click/not-a-real-referral-code",
                follow_redirects=False,
            )
            assert invalid_click.status_code == 404
            async with TestingSessionLocal() as session:
                rejected_click_count = await session.scalar(
                    select(func.count(freelance_api.models.FreelancerReferralClickEvent.id)).where(
                        freelance_api.models.FreelancerReferralClickEvent.referral_id
                        == replacement_id
                    )
                )
                assert rejected_click_count == 0

            history = await ac.get("/api/v1/referrals/links", headers=headers)
            history_codes = {
                item["referral_code"] for item in history.json()["data"]["items"]
            }
            assert link["referral_code"] in history_codes
            assert replacement_link["referral_code"] in history_codes

        invalid_destination = await ac.post(
            "/api/v1/referrals/links",
            json={
                "referral_type": "service",
                "target_sub_service_id": service_id,
                "target_service_url": (
                    "https://vendor.am5royal.com/map/homeservices/plumbingservices"
                ),
                "validity_days": 7,
            },
            headers=headers,
        )
        assert invalid_destination.status_code == 422


@pytest.mark.asyncio
async def test_vendor_registration_records_referral_attribution_once():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        suffix = f"{uuid.uuid4().int % 1_000_000_000:09d}"
        payload = {
            "full_name": "Attribution Owner",
            "mobile_number": "7" + suffix,
            "email": f"attribution.owner.{suffix}@example.com",
            "password": "Password123",
            "confirm_password": "Password123",
        }
        await ac.post("/api/v1/auth/register", json=payload)
        login = await ac.post(
            "/api/v1/auth/login",
            json={"identifier": payload["email"], "password": payload["password"]},
        )
        freelancer_id = int(jwt.get_unverified_claims(
            login.json()["data"]["access_token"]
        )["sub"])
        headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}

        async with TestingSessionLocal() as session:
            if await session.get(ServiceCategory, 37) is None:
                session.add(ServiceCategory(id=37, name="Home Services", is_active=True))
            service_id = 7
            session.add(ServiceSubcategory(
                id=service_id,
                main_category_id=37,
                name="Plumbing Services",
                is_active=True,
            ))
            user_id = int(uuid.uuid4().int % 900_000_000) + 8_000_000_000
            session.add(User(id=user_id, mobile=f"8{suffix}", role="VENDOR"))
            vendor_id = int(uuid.uuid4().int % 900_000_000) + 7_000_000_000
            session.add(Vendor(
                id=vendor_id,
                user_id=user_id,
                status="onboarding",
                lead_source="company_website",
            ))
            await session.commit()

        referral = await ac.post(
            "/api/v1/referrals/links",
            json={
                "referral_type": "service",
                "target_sub_service_id": service_id,
                "target_service_url": (
                    "https://vendor.am5royal.com/map/homeservices/plumbingservices"
                ),
                "validity_days": 7,
            },
            headers=headers,
        )
        assert referral.status_code == 201
        link = referral.json()["data"]
        vendor_token = create_access_token(subject=str(user_id))
        vendor_headers = {"Authorization": f"Bearer {vendor_token}"}
        registration = {
            "first_name": "Referral",
            "last_name": "Vendor",
            "business_name": "Referral Vendor Co",
            "aadhaar_number": "123456789012",
            "address": "Test Address",
            "city": "Test City",
            "state": "Test State",
            "pincode": "123456",
            "categories": [{"main_category_id": 37, "sub_category_ids": [service_id]}],
            "referral_code": link["referral_code"],
            "referral_service_id": service_id,
        }

        first = await ac.post(
            "/api/v1/auth/vendor/register",
            json=registration,
            headers=vendor_headers,
        )
        assert first.status_code == 200, first.text
        second = await ac.post(
            "/api/v1/auth/vendor/register",
            json=registration,
            headers=vendor_headers,
        )
        assert second.status_code == 200, second.text

        async with TestingSessionLocal() as session:
            vendor = await session.get(Vendor, vendor_id)
            attribution = (await session.execute(
                select(VendorReferralAttribution).where(
                    VendorReferralAttribution.vendor_id == vendor_id
                )
            )).scalars().all()
            stored_link = (await session.execute(
                select(freelance_api.models.FreelancerReferralLink).where(
                    freelance_api.models.FreelancerReferralLink.id
                    == int(link["referral_id"].removeprefix("ref_"))
                )
            )).scalar_one()
            assert stored_link.target_service_category_id == 37
            assert vendor.freelancer_id == freelancer_id
            assert len(attribution) == 1
            assert attribution[0].referral_code == link["referral_code"]
            assert attribution[0].service_id == service_id
            assert attribution[0].attributed_at is not None
            assert stored_link.conversions_count == 1

        vendor_invitation = await ac.post(
            "/api/v1/referrals/links",
            json={"referral_type": "vendor", "validity_days": 15},
            headers=headers,
        )
        assert vendor_invitation.status_code == 201, vendor_invitation.text
        vendor_link = vendor_invitation.json()["data"]
        vendor_click = await ac.get(vendor_link["url"], follow_redirects=False)
        assert vendor_click.status_code == 302
        vendor_campaign = parse_qs(
            parse_qs(urlsplit(vendor_click.headers["location"]).query)["referrer"][0]
        )
        install_tracking_id = vendor_campaign["click_id"][0]
        install_response = await ac.post(
            "/api/v1/referrals/vendor/install",
            json={
                "referral_code": vendor_link["referral_code"],
                "click_id": install_tracking_id,
            },
        )
        assert install_response.status_code == 200, install_response.text
        vendor_user_id = int(uuid.uuid4().int % 900_000_000) + 6_000_000_000
        invited_vendor_id = int(uuid.uuid4().int % 900_000_000) + 5_000_000_000
        async with TestingSessionLocal() as session:
            session.add(User(id=vendor_user_id, mobile=f"9{suffix}", role="VENDOR"))
            session.add(Vendor(
                id=invited_vendor_id,
                user_id=vendor_user_id,
                status="onboarding",
                lead_source="company_website",
            ))
            await session.commit()

        vendor_registration = {
            "first_name": "Play Store",
            "last_name": "Referral",
            "business_name": "Invited Vendor",
            "aadhaar_number": "123456789012",
            "address": "Test Address",
            "city": "Test City",
            "state": "Test State",
            "pincode": "123456",
            "categories": [],
            "referral_code": vendor_link["referral_code"],
            "referral_installation_id": install_tracking_id,
        }
        vendor_auth_headers = {
            "Authorization": f"Bearer {create_access_token(subject=str(vendor_user_id))}"
        }
        vendor_response = await ac.post(
            "/api/v1/auth/vendor/register",
            json=vendor_registration,
            headers=vendor_auth_headers,
        )
        assert vendor_response.status_code == 200, vendor_response.text
        repeated_vendor_response = await ac.post(
            "/api/v1/auth/vendor/register",
            json=vendor_registration,
            headers=vendor_auth_headers,
        )
        assert repeated_vendor_response.status_code == 200

        async with TestingSessionLocal() as session:
            invited_vendor = await session.get(Vendor, invited_vendor_id)
            attribution = (await session.execute(
                select(VendorReferralAttribution).where(
                    VendorReferralAttribution.vendor_id == invited_vendor_id
                )
            )).scalar_one()
            stored_vendor_link = (await session.execute(
                select(freelance_api.models.FreelancerReferralLink).where(
                    freelance_api.models.FreelancerReferralLink.referral_code
                    == vendor_link["referral_code"]
                )
            )).scalar_one()
            assert invited_vendor.freelancer_id == freelancer_id
            assert invited_vendor.lead_source == "freelancer"
            assert attribution.freelancer_id == freelancer_id
            assert attribution.referral_code == vendor_link["referral_code"]
            assert attribution.installation_tracking_id == install_tracking_id
            assert attribution.service_id is None
            assert stored_vendor_link.conversions_count == 1
            install = (await session.execute(
                select(freelance_api.models.FreelancerInstallationTracking).where(
                    freelance_api.models.FreelancerInstallationTracking.tracking_id
                    == install_tracking_id
                )
            )).scalar_one()
            assert install.activation_date is not None

@pytest.mark.asyncio
async def test_admin_referral_report_is_admin_only_and_uses_persisted_tables():
    from types import SimpleNamespace

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        denied = await ac.get("/api/v1/admin/referrals/report")
        assert denied.status_code in {401, 403}

        app.dependency_overrides[get_current_admin] = lambda: SimpleNamespace(role="admin")
        try:
            response = await ac.get("/api/v1/admin/referrals/report")
        finally:
            app.dependency_overrides.pop(get_current_admin, None)

    assert response.status_code == 200
    data = response.json()["data"]
    assert {"summary", "freelancers", "vendors", "services", "daily", "monthly"} <= set(data)
    assert {"total_referrals", "clicks", "registrations", "first_logins", "subsequent_logins"} <= set(data["summary"])



@pytest.mark.asyncio
async def test_referral_action_event_is_authenticated_and_idempotent():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        denied = await ac.post(
            "/api/v1/referrals/links/1/events",
            json={"event_id": "local-test-event-no-token", "event_type": "copy"},
        )
        assert denied.status_code == 401

        suffix = uuid.uuid4().hex[:12]
        phone_suffix = f"{uuid.uuid4().int % 1_000_000_000:09d}"
        register = await ac.post("/api/v1/freelancer/auth/register", json={
            "full_name": "Referral Action Test",
            "mobile_number": "7" + phone_suffix,
            "email": f"referral.action.{suffix}@example.com",
            "password": "TestOnlyPassword123!",
            "confirm_password": "TestOnlyPassword123!",
        })
        assert register.status_code == 201
        login = await ac.post("/api/v1/freelancer/auth/login", json={
            "identifier": f"referral.action.{suffix}@example.com",
            "password": "TestOnlyPassword123!",
        })
        assert login.status_code == 200
        headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}
        generated = await ac.post(
            "/api/v1/referrals/links",
            json={"referral_type": "customer", "validity_days": 7},
            headers=headers,
        )
        assert generated.status_code == 201
        referral_id = int(generated.json()["data"]["referral_id"].removeprefix("ref_"))
        payload = {
            "event_id": f"copy-event-{uuid.uuid4().hex}",
            "event_type": "copy",
            "platform": "web",
        }
        first = await ac.post(
            f"/api/v1/referrals/links/{referral_id}/events",
            json=payload,
            headers=headers,
        )
        duplicate = await ac.post(
            f"/api/v1/referrals/links/{referral_id}/events",
            json=payload,
            headers=headers,
        )
        assert first.status_code == 200
        assert first.json()["data"]["duplicate"] is False
        assert duplicate.status_code == 200
        assert duplicate.json()["data"]["duplicate"] is True
        history = await ac.get(
            f"/api/v1/referrals/links/{referral_id}/events",
            headers=headers,
        )
        assert history.status_code == 200
        event_types = [row["event_type"] for row in history.json()["data"]["events"]]
        assert event_types.count("link_created") == 1
        assert event_types.count("copy") == 1

    async with TestingSessionLocal() as session:
        rows = (await session.execute(
            select(FreelancerReferralActionEvent).where(
                FreelancerReferralActionEvent.referral_id == referral_id,
            )
        )).scalars().all()
        assert len(rows) == 1
        assert rows[0].event_type == "copy"
        assert rows[0].platform == "web"


@pytest.mark.asyncio
async def test_service_referral_dashboard_uses_owned_postgres_model_data():
    async with TestingSessionLocal() as session:
        category = await session.get(ServiceCategory, 37)
        if category is None:
            session.add(ServiceCategory(id=37, name="Home services", is_active=True))
        service = await session.get(ServiceSubcategory, 43)
        if service is None:
            session.add(ServiceSubcategory(
                id=43,
                main_category_id=37,
                name="Solar Services",
                is_active=True,
                sort_order=1,
            ))
        else:
            assert service.main_category_id == 37
            assert service.name == "Solar Services"
        await session.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        suffix = uuid.uuid4().hex[:12]
        phone_suffix = f"{uuid.uuid4().int % 1_000_000_000:09d}"
        register = await ac.post("/api/v1/freelancer/auth/register", json={
            "full_name": "Service Report Test",
            "mobile_number": "7" + phone_suffix,
            "email": f"service.report.{suffix}@example.com",
            "password": "TestOnlyPassword123!",
            "confirm_password": "TestOnlyPassword123!",
        })
        assert register.status_code == 201
        login = await ac.post("/api/v1/freelancer/auth/login", json={
            "identifier": f"service.report.{suffix}@example.com",
            "password": "TestOnlyPassword123!",
        })
        assert login.status_code == 200
        headers = {"Authorization": f"Bearer {login.json()['data']['access_token']}"}
        generated = await ac.post(
            "/api/v1/referrals/links",
            json={
                "referral_type": "service",
                "target_sub_service_id": 43,
                "target_service_url": "https://vendor.am5royal.com/map/homeservices/solarservices",
                "validity_days": 7,
            },
            headers=headers,
        )
        assert generated.status_code == 201
        report = await ac.get("/api/v1/referrals/services/dashboard", headers=headers)
        assert report.status_code == 200
        data = report.json()["data"]
        assert data["summary"]["total_links"] == 1
        assert data["summary"]["seven_day_links"] == 1
        solar = next(row for row in data["services"] if row["service_id"] == 43)
        assert solar["service_name"] == "Solar Services"
        assert solar["total_links"] == 1
        assert solar["clicks"] == 0
        assert isinstance(data["daily"], list)
        assert isinstance(data["monthly"], list)
