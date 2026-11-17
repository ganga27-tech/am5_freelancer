import ipaddress
import uuid
import re
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any, Tuple
from urllib.parse import quote, urlencode, urlsplit, urlunsplit
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, desc, update, case

from app.core.security import verify_password, get_password_hash, create_access_token
from app.models.freelancer import Freelancer
from app.models.catalog import ServiceCategory, ServiceSubcategory
from app.services.otp_service import (
    OTPDeliveryUnavailable,
    OTPStoreUnavailable,
    otp_service,
)
from app.services.security_service import security_service
from app.core.config import settings
from app.core.phone_numbers import indian_mobile_variants, normalize_indian_mobile
from app.services.upload_service import upload_service
from freelance_api.models import (
    FreelancerKycDocument,
    FreelancerKycSubmission,
    FreelancerFaceVerificationSession,
    FreelancerReferralLink,
    FreelancerReferralClickEvent,
    FreelancerReferralReward,
    FreelancerInstallationRule,
    FreelancerInstallationTracking,
    FreelancerRewardItem,
    FreelancerWalletTransaction,
    FreelancerPayoutRequest,
    FreelancerSetting,
    FreelancerNotification,
    FreelancerDeviceToken,
    FreelancerSupportTicket,
    FreelancerLegalPage,
    FreelancerLegalAcceptance,
    FreelancerBanner,
    FreelancerDemoVideo,
    FreelancerFaq,
)
from freelance_api.dependencies import mask_account_number
from app.models.vendor import VendorReferralAttribution

# Permanent Vendor destinations are keyed by the stable Freelancer catalog
# subcategory IDs. These paths mirror the published Home Services URLs; they
# must not be derived from display names, which are not URL identifiers.
HOME_SERVICE_VENDOR_SLUG_BY_SUBCATEGORY_ID = {
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

HOME_SERVICE_VENDOR_SLUG_BY_NORMALIZED_NAME = {}
for _vendor_slug in set(HOME_SERVICE_VENDOR_SLUG_BY_SUBCATEGORY_ID.values()):
    HOME_SERVICE_VENDOR_SLUG_BY_NORMALIZED_NAME[_vendor_slug] = _vendor_slug
    for _suffix in ("services", "service"):
        if _vendor_slug.endswith(_suffix):
            HOME_SERVICE_VENDOR_SLUG_BY_NORMALIZED_NAME[
                _vendor_slug[: -len(_suffix)]
            ] = _vendor_slug
HOME_SERVICE_VENDOR_SLUG_BY_NORMALIZED_NAME["24wheelerservices"] = (
    "2and4wheelerservices"
)
HOME_SERVICE_VENDOR_SLUG_BY_NORMALIZED_NAME["24wheeler"] = "2and4wheelerservices"


def home_service_vendor_slug(subcategory_id: int, service_name: Optional[str] = None) -> Optional[str]:
    normalized_name = re.sub(r"[^a-z0-9]", "", (service_name or "").lower())
    if normalized_name:
        # Resolve using the actual catalog row name first so development and
        # production primary keys can differ without changing destinations.
        return HOME_SERVICE_VENDOR_SLUG_BY_NORMALIZED_NAME.get(normalized_name)
    # ID lookup exists for callers without catalog context only. Generation
    # and click routes pass the database row's name and never assume an ID.
    return HOME_SERVICE_VENDOR_SLUG_BY_SUBCATEGORY_ID.get(subcategory_id)


def is_valid_home_service_destination(
    subcategory_id: int, service_url: str, service_name: Optional[str] = None
) -> bool:
    vendor_slug = home_service_vendor_slug(subcategory_id, service_name)
    if vendor_slug is None:
        return False
    parsed = urlsplit(service_url.strip())
    return (
        parsed.scheme == "https"
        and parsed.netloc == "vendor.am5royal.com"
        and parsed.path == f"/map/homeservices/{vendor_slug}"
        and not parsed.query
        and not parsed.fragment
    )


def home_service_referral_url(
    subcategory_id: int, service_name: Optional[str], referral_code: str
) -> Optional[str]:
    """Build the existing Vendor Flutter deep link for a service referral."""
    slug = home_service_vendor_slug(subcategory_id, service_name)
    code = referral_code.strip()
    if slug is None or not code:
        return None
    return (
        f"https://vendor.am5royal.com/map/homeservices/{slug}"
        f"?{urlencode({'ref': code})}"
    )

class ActiveServiceReferralConflict(Exception):
    """Raised when historical data already violates the service-link invariant."""


class ActiveVendorReferralConflict(Exception):
    """Raised when historical data already violates the Vendor-link invariant."""


def public_referral_tracking_base_url() -> str:
    """Refuse to persist share links that point at this machine or a private host."""
    base_url = settings.REFERRAL_TRACKING_BASE_URL.strip().rstrip("/")
    parsed = urlsplit(base_url)
    hostname = (parsed.hostname or "").lower()
    is_private_host = hostname in {"localhost", "localhost.localdomain"} or hostname.endswith(
        (".localhost", ".local", ".internal")
    )
    try:
        ip_address = ipaddress.ip_address(hostname)
        is_private_host = is_private_host or not ip_address.is_global
    except ValueError:
        pass
    if (
        parsed.scheme != "https"
        or not hostname
        or is_private_host
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError(
            "A public HTTPS referral tracking URL must be configured before generating share links"
        )
    return base_url


class FreelanceService:
    @staticmethod
    async def login(db: AsyncSession, identifier: str, password: str) -> Tuple[Freelancer, str]:
        ident = identifier.strip()
        if "@" in ident:
            stmt = select(Freelancer).where(func.lower(Freelancer.email) == ident.lower())
        else:
            variants = indian_mobile_variants(ident)
            if not variants:
                raise ValueError("Invalid email/mobile or password")
            stmt = select(Freelancer).where(Freelancer.phone_number.in_(variants))
        res = await db.execute(stmt)
        matches = res.scalars().all()
        if len(matches) != 1:
            raise ValueError("Invalid email/mobile or password")
        freelancer = matches[0]

        if not verify_password(password, freelancer.hashed_password):
            raise ValueError("Invalid email/mobile or password")

        account_status = (freelancer.status or "active").strip().lower()
        profile_status = (freelancer.profile_status or "active").strip().lower()
        if account_status in ("inactive", "suspended", "blocked", "banned", "deleted") or profile_status in ("inactive", "suspended", "blocked", "banned", "deleted"):
            raise ValueError("This account is not active. Please contact support.")

        try:
            version = await security_service.freelancer_auth_version(freelancer.id)
        except Exception as exc:
            raise OTPStoreUnavailable("Authentication is temporarily unavailable") from None
        token = create_access_token(freelancer.id, additional_claims={"fv": version})
        return freelancer, token

    @staticmethod
    async def register(db: AsyncSession, full_name: str, mobile_number: str, email: str, password: str) -> Freelancer:
        clean_email = email.strip().lower()
        clean_mobile = normalize_indian_mobile(mobile_number)
        if clean_mobile is None:
            raise ValueError("Enter a valid Indian mobile number")

        stmt = select(Freelancer).where(
            or_(
                func.lower(Freelancer.email) == clean_email,
                Freelancer.phone_number.in_(indian_mobile_variants(clean_mobile))
            )
        )
        res = await db.execute(stmt)
        if res.scalar_one_or_none():
            raise ValueError("An account with this email or mobile number already exists")

        name_parts = full_name.strip().split(" ", 1)
        first_name = name_parts[0]
        last_name = name_parts[1] if len(name_parts) > 1 else ""

        rand_suffix = secrets.token_hex(3).upper()
        ref_code = f"AM5{first_name[:3].upper()}{rand_suffix}"

        hashed_pw = get_password_hash(password)

        freelancer = Freelancer(
            first_name=first_name,
            last_name=last_name,
            email=clean_email,
            phone_number=clean_mobile,
            hashed_password=hashed_pw,
            referral_code=ref_code,
            total_points=50,
            status="active",
            profile_completion_percentage=25,
            kyc_status="NOT_STARTED",
            face_verification_status="NOT_STARTED",
            total_earnings=0.00,
            available_balance=0.00,
            pending_balance=0.00,
            processing_balance=0.00,
            total_withdrawn=0.00,
        )
        db.add(freelancer)
        await db.commit()
        await db.refresh(freelancer)

        setting = FreelancerSetting(
            freelancer_id=freelancer.id,
            privacy_preferences={
                "show_profile_in_directory": True,
                "allow_marketing_contact": True,
                "share_activity_status": True,
            },
            notification_preferences={
                "push_notifications": True,
                "email_notifications": True,
                "sms_notifications": True,
                "referral_alerts": True,
                "payout_alerts": True,
            },
            security_preferences={
                "two_factor_enabled": False,
                "login_alerts": True,
            }
        )
        db.add(setting)

        notif = FreelancerNotification(
            freelancer_id=freelancer.id,
            notification_id=f"ntf_{uuid.uuid4().hex[:8]}",
            title="Welcome to AM5 Freelancer!",
            body="Your account has been created. Complete your KYC to start earning rewards.",
            type="SYSTEM",
            deep_link="/profile/kyc"
        )
        db.add(notif)
        await db.commit()

        return freelancer

    @staticmethod
    async def request_password_reset(
        db: AsyncSession,
        identifier: str,
        preferred_channel: str,
        client_ip: str,
    ) -> Tuple[str, int]:
        channel = preferred_channel.strip().lower()
        if channel not in {"email", "sms"}:
            raise ValueError("Choose email or SMS recovery")
        if not otp_service.password_reset_delivery_configured(channel):
            raise OTPDeliveryUnavailable("Password recovery delivery is not configured")

        value = identifier.strip()
        if channel == "email":
            if "@" not in value or any(char.isspace() for char in value):
                raise ValueError("Enter the registered email address")
            normalized = value.lower()
            stmt = select(Freelancer).where(func.lower(Freelancer.email) == normalized)
        else:
            normalized = normalize_indian_mobile(value)
            if normalized is None:
                raise ValueError("Enter a valid Indian mobile number")
            stmt = select(Freelancer).where(
                Freelancer.phone_number.in_(indian_mobile_variants(normalized))
            )

        await otp_service.enforce_password_reset_limits(normalized, client_ip)
        result = await db.execute(stmt)
        matches = result.scalars().all()
        if len(matches) != 1:
            return secrets.token_urlsafe(32), settings.PASSWORD_RESET_OTP_TTL_SECONDS

        freelancer = matches[0]
        destination = (
            (freelancer.email or "").strip().lower()
            if channel == "email"
            else normalize_indian_mobile(freelancer.phone_number)
        )
        if not destination:
            return secrets.token_urlsafe(32), settings.PASSWORD_RESET_OTP_TTL_SECONDS

        challenge_id = secrets.token_urlsafe(32)
        otp = f"{secrets.randbelow(1_000_000):06d}"
        await otp_service.store_password_reset_challenge(
            challenge_id=challenge_id,
            freelancer_id=int(freelancer.id),
            identifier=normalized,
            channel=channel,
            otp=otp,
        )
        sent = (
            await otp_service.send_password_reset_email(destination, otp)
            if channel == "email"
            else await otp_service.send_password_reset_sms(destination, otp)
        )
        if not sent:
            await otp_service.discard_password_reset_challenge(
                challenge_id,
                normalized,
                int(freelancer.id),
            )
            raise OTPDeliveryUnavailable("Password recovery delivery failed")
        return challenge_id, settings.PASSWORD_RESET_OTP_TTL_SECONDS

    @staticmethod
    async def verify_otp(challenge_id: str, otp: str, purpose: str) -> str:
        if purpose != "password_recovery":
            raise ValueError("Invalid OTP purpose")
        freelancer_id = await otp_service.verify_password_reset_challenge(
            challenge_id,
            otp,
        )
        reset_token = secrets.token_urlsafe(32)
        await otp_service.store_password_reset_token(reset_token, freelancer_id)
        return reset_token

    @staticmethod
    async def reset_password(db: AsyncSession, reset_token: str, new_password: str) -> None:
        freelancer_id = await otp_service.consume_password_reset_token(reset_token)
        stmt = select(Freelancer).where(Freelancer.id == freelancer_id)
        res = await db.execute(stmt)
        freelancer = res.scalar_one_or_none()
        if not freelancer:
            raise ValueError("Freelancer account not found")

        await security_service.revoke_freelancer_sessions(freelancer_id)
        freelancer.hashed_password = get_password_hash(new_password)
        await db.commit()
        await otp_service.invalidate_password_reset_state(freelancer_id)

    @staticmethod
    async def change_password(db: AsyncSession, freelancer: Freelancer, current_pw: str, new_pw: str) -> None:
        if not verify_password(current_pw, freelancer.hashed_password):
            raise ValueError("Current password does not match")
        if verify_password(new_pw, freelancer.hashed_password):
            raise ValueError("New password must differ from the current password")
        await security_service.revoke_freelancer_sessions(int(freelancer.id))
        freelancer.hashed_password = get_password_hash(new_pw)
        await db.commit()
        await otp_service.invalidate_password_reset_state(int(freelancer.id))

    @staticmethod
    def calculate_completion(freelancer: Freelancer) -> Tuple[int, List[str], List[str]]:
        completed = []
        missing = []

        if freelancer.first_name and freelancer.email and freelancer.phone_number:
            completed.append("basic_info")
        else:
            missing.append("basic_info")

        if freelancer.city and freelancer.address and freelancer.pincode:
            completed.append("address_details")
        else:
            missing.append("address_details")

        if freelancer.bank_account_number and freelancer.bank_ifsc_code:
            completed.append("bank_details")
        else:
            missing.append("bank_details")

        if freelancer.kyc_status == "VERIFIED":
            completed.append("kyc_verification")
        else:
            missing.append("kyc_verification")

        total_pct = int((len(completed) / 4) * 100)
        return total_pct, completed, missing

    @staticmethod
    async def update_profile(db: AsyncSession, freelancer: Freelancer, update_data: Dict[str, Any]) -> Freelancer:
        for k, v in update_data.items():
            if v is not None and hasattr(freelancer, k):
                setattr(freelancer, k, v)

        pct, _, _ = FreelanceService.calculate_completion(freelancer)
        freelancer.profile_completion_percentage = pct
        await db.commit()
        await db.refresh(freelancer)
        return freelancer

    @staticmethod
    async def update_bank_details(db: AsyncSession, freelancer: Freelancer, data: Dict[str, Any]) -> Freelancer:
        ifsc = data["ifsc_code"].strip().upper()
        if not re.match(r"^[A-Z]{4}0[A-Z0-9]{6}$", ifsc):
            raise ValueError("Invalid IFSC code format (e.g. HDFC0001234)")

        freelancer.bank_account_name = data["account_holder_name"].strip()
        freelancer.bank_account_number = data["account_number"].strip()
        freelancer.bank_ifsc_code = ifsc
        freelancer.bank_name = data["bank_name"].strip()
        freelancer.bank_verification_status = "PENDING"

        pct, _, _ = FreelanceService.calculate_completion(freelancer)
        freelancer.profile_completion_percentage = pct
        await db.commit()
        await db.refresh(freelancer)
        return freelancer

    @staticmethod
    async def generate_referral_link(
        db: AsyncSession,
        freelancer: Freelancer,
        referral_type: str,
        validity_days: int = 15,
        target_sub_service_id: Optional[int] = None,
        target_service_url: Optional[str] = None,
    ) -> Tuple[FreelancerReferralLink, bool]:
        if validity_days not in {7, 15}:
            raise ValueError("Referral validity must be 7 or 15 days")
        if referral_type not in {"customer", "vendor", "service"}:
            raise ValueError("Referral type must be customer, vendor, or service")
        if referral_type == "vendor" and validity_days != 15:
            raise ValueError("Vendor referrals must be valid for exactly 15 days")

        if referral_type == "service":
            return await FreelanceService._generate_or_reuse_service_referral_link(
                db=db,
                freelancer=freelancer,
                validity_days=validity_days,
                target_sub_service_id=target_sub_service_id,
                target_service_url=target_service_url,
            )
        if referral_type == "vendor":
            return await FreelanceService._generate_or_reuse_vendor_referral_link(
                db=db,
                freelancer=freelancer,
            )

        validity = validity_days
        created_at = datetime.now(timezone.utc).replace(tzinfo=None)
        expires_at = created_at + timedelta(days=validity)
        unique_token = secrets.token_urlsafe(32)
        code = f"{freelancer.referral_code}-{unique_token}"

        target_service_name = None
        target_service_category_id = None
        target_url = f"https://am5royal.com/ref/{code}"

        if referral_type == "vendor":
            target_url = (
                f"{settings.REFERRAL_TRACKING_BASE_URL.rstrip('/')}/api/v1/referrals/vendor/click/"
                + quote(code, safe="")
            )
        else:
            referral_type = "customer"
            target_url = f"https://am5royal.com/signup?ref={code}"

        link = FreelancerReferralLink(
            freelancer_id=freelancer.id,
            referral_code=code,
            referral_type=referral_type,
            target_service_category_id=target_service_category_id,
            target_sub_service_id=target_sub_service_id,
            target_sub_service_name=target_service_name,
            url=target_url,
            validity_days=validity,
            status="active",
            created_at=created_at,
            expires_at=expires_at,
        )
        db.add(link)
        await db.commit()
        await db.refresh(link)
        return link, False

    @staticmethod
    async def _generate_or_reuse_vendor_referral_link(
        db: AsyncSession,
        freelancer: Freelancer,
    ) -> Tuple[FreelancerReferralLink, bool]:
        tracking_base_url = public_referral_tracking_base_url()
        # Serialize Vendor-link generation for this Freelancer, matching the
        # lock used by service referrals. Keep old links and their events.
        locked_freelancer_id = await db.scalar(
            select(Freelancer.id)
            .where(Freelancer.id == freelancer.id)
            .with_for_update()
        )
        if locked_freelancer_id is None:
            raise ValueError("Freelancer account is unavailable")

        now = datetime.now(timezone.utc).replace(tzinfo=None)
        conditions = (
            FreelancerReferralLink.freelancer_id == freelancer.id,
            FreelancerReferralLink.referral_type == "vendor",
        )
        await db.execute(
            update(FreelancerReferralLink)
            .where(
                *conditions,
                FreelancerReferralLink.status == "active",
                FreelancerReferralLink.expires_at <= now,
            )
            .values(status="expired")
        )
        active_result = await db.execute(
            select(FreelancerReferralLink)
            .where(
                *conditions,
                FreelancerReferralLink.status == "active",
                FreelancerReferralLink.expires_at > now,
            )
            .order_by(
                FreelancerReferralLink.created_at.desc(),
                FreelancerReferralLink.id.desc(),
            )
        )
        active_links = list(active_result.scalars().all())
        if len(active_links) > 1:
            await db.commit()
            raise ActiveVendorReferralConflict(
                "Multiple active Vendor referral links already exist for this Freelancer"
            )
        if active_links:
            link = active_links[0]
            await db.commit()
            await db.refresh(link)
            return link, True

        code = f"{freelancer.referral_code}-{secrets.token_urlsafe(32)}"
        link = FreelancerReferralLink(
            freelancer_id=freelancer.id,
            referral_code=code,
            referral_type="vendor",
            target_service_category_id=None,
            target_sub_service_id=None,
            target_sub_service_name=None,
            url=(
                f"{tracking_base_url}/api/v1/referrals/vendor/click/"
                + quote(code, safe="")
            ),
            validity_days=15,
            status="active",
            created_at=now,
            expires_at=now + timedelta(days=15),
        )
        db.add(link)
        await db.commit()
        await db.refresh(link)
        return link, False

    @staticmethod
    async def _generate_or_reuse_service_referral_link(
        db: AsyncSession,
        freelancer: Freelancer,
        validity_days: int,
        target_sub_service_id: Optional[int],
        target_service_url: Optional[str],
    ) -> Tuple[FreelancerReferralLink, bool]:
        if (target_sub_service_id or 0) <= 0:
            raise ValueError("A valid subcategory is required for service referrals")

        subcategory_result = await db.execute(
            select(ServiceSubcategory).where(
                ServiceSubcategory.id == target_sub_service_id,
                ServiceSubcategory.is_active.is_(True),
            )
        )
        subcategory = subcategory_result.scalar_one_or_none()
        if not subcategory:
            raise ValueError("The selected subcategory does not exist or is inactive")
        if subcategory.main_category_id != 37:
            raise ValueError("Service referrals are available only for Home Services")

        service_url = (target_service_url or "").strip()
        if not is_valid_home_service_destination(
            target_sub_service_id, service_url, subcategory.name
        ):
            raise ValueError(
                "The Vendor URL must match the selected Home Service destination"
            )

        # Lock the owning Freelancer row so concurrent API requests for any
        # of their services serialize before checking or creating a link.
        locked_freelancer_id = await db.scalar(
            select(Freelancer.id)
            .where(Freelancer.id == freelancer.id)
            .with_for_update()
        )
        if locked_freelancer_id is None:
            raise ValueError("Freelancer account is unavailable")

        now = datetime.now(timezone.utc).replace(tzinfo=None)
        key_conditions = (
            FreelancerReferralLink.freelancer_id == freelancer.id,
            FreelancerReferralLink.referral_type == "service",
            FreelancerReferralLink.target_sub_service_id == target_sub_service_id,
        )
        # Keep expired history and click events; only mark naturally expired
        # active service links so a fresh link can be created for this key.
        await db.execute(
            update(FreelancerReferralLink)
            .where(
                *key_conditions,
                FreelancerReferralLink.status == "active",
                FreelancerReferralLink.expires_at <= now,
            )
            .values(status="expired")
        )

        recorded_click_count = (
            select(func.count(FreelancerReferralClickEvent.id))
            .where(
                FreelancerReferralClickEvent.referral_id
                == FreelancerReferralLink.id
            )
            .correlate(FreelancerReferralLink)
            .scalar_subquery()
        )
        attribution_count = (
            select(func.count(VendorReferralAttribution.id))
            .where(
                VendorReferralAttribution.referral_link_id
                == FreelancerReferralLink.id
            )
            .correlate(FreelancerReferralLink)
            .scalar_subquery()
        )
        click_count_score = case(
            (
                recorded_click_count > FreelancerReferralLink.clicks_count,
                recorded_click_count,
            ),
            else_=FreelancerReferralLink.clicks_count,
        )
        active_result = await db.execute(
            select(FreelancerReferralLink)
            .where(
                *key_conditions,
                FreelancerReferralLink.status == "active",
                FreelancerReferralLink.expires_at > now,
            )
            .order_by(
                # When old duplicate rows exist, retain the most established
                # link: attribution history first, then recorded clicks, then
                # the original creation order. This never edits or revokes
                # the other historical links.
                attribution_count.desc(),
                click_count_score.desc(),
                FreelancerReferralLink.created_at.asc(),
                FreelancerReferralLink.id.asc(),
            )
        )
        active_links = list(active_result.scalars().all())
        if active_links:
            # Reuse one canonical active row even if historical duplicate
            # rows remain. Do not change its code, validity, or expiry.
            existing = active_links[0]
            # Persist any expired-status updates before releasing the row lock.
            await db.commit()
            await db.refresh(existing)
            return existing, True

        created_at = now
        code = f"{freelancer.referral_code}-{secrets.token_urlsafe(32)}"
        url = home_service_referral_url(
            subcategory.id, subcategory.name, code
        )
        if url is None:
            raise ValueError("The selected Home Service has no supported Vendor route")
        link = FreelancerReferralLink(
            freelancer_id=freelancer.id,
            referral_code=code,
            referral_type="service",
            target_service_category_id=subcategory.main_category_id,
            target_sub_service_id=subcategory.id,
            target_sub_service_name=subcategory.name,
            url=url,
            validity_days=validity_days,
            status="active",
            created_at=created_at,
            expires_at=created_at + timedelta(days=validity_days),
        )
        db.add(link)
        await db.commit()
        await db.refresh(link)
        return link, False

    @staticmethod
    async def validate_referral_code(db: AsyncSession, code: str) -> Dict[str, Any]:
        stmt = select(FreelancerReferralLink).where(FreelancerReferralLink.referral_code == code.strip())
        res = await db.execute(stmt)
        link = res.scalar_one_or_none()

        if not link:
            stmt_f = select(Freelancer).where(Freelancer.referral_code == code.strip())
            res_f = await db.execute(stmt_f)
            free = res_f.scalar_one_or_none()
            if free and free.status == "active":
                return {
                    "valid": True,
                    "status": "active",
                    "referral_type": "general",
                    "target_service": None,
                    "expires_at": None,
                    "referrer_name": free.full_name
                }
            return {"valid": False, "status": "not_found"}

        now = datetime.now(timezone.utc).replace(tzinfo=None)
        is_expired = link.expires_at <= now
        if link.status == "active" and is_expired:
            link.status = "expired"
            await db.commit()
        if link.status != "active" or is_expired:
            return {
                "valid": False,
                "status": "expired" if is_expired else link.status,
                "referral_type": link.referral_type,
                "expires_at": link.expires_at.isoformat() + "Z",
            }

        target_service = None
        if link.target_sub_service_id:
            service_result = await db.execute(
                select(ServiceSubcategory).where(
                    ServiceSubcategory.id == link.target_sub_service_id
                )
            )
            service_row = service_result.scalar_one_or_none()
            service_category_id = (
                link.target_service_category_id
                if link.target_service_category_id is not None
                else service_row.main_category_id if service_row else None
            )
            target_service = {
                "id": link.target_sub_service_id,
                "name": service_row.name if service_row else link.target_sub_service_name,
                "main_category_id": service_category_id,
            }

        stmt_f = select(Freelancer).where(Freelancer.id == link.freelancer_id)
        res_f = await db.execute(stmt_f)
        free = res_f.scalar_one_or_none()

        return {
            "valid": True,
            "status": "active",
            "referral_id": link.id,
            "referral_type": link.referral_type,
            "target_service": target_service,
            "expires_at": link.expires_at.isoformat() + "Z",
            "referrer_name": free.full_name if free else "AM5 Partner"
        }

    @staticmethod
    async def get_level_progress(freelancer: Freelancer) -> Dict[str, Any]:
        points = freelancer.total_points or 0

        if points < 250:
            level = "Bronze"
            next_level = "Silver"
            target = 250
            req = target - points
            pct = round((points / target) * 100, 1)
            benefits = ["Standard 5% commission on customer referrals", "Weekly payout cycle"]
        elif points < 1000:
            level = "Silver"
            next_level = "Gold"
            target = 1000
            req = target - points
            pct = round(((points - 250) / 750) * 100, 1)
            benefits = ["7.5% commission on referrals", "Priority customer lead routing", "48-hr fast payouts"]
        elif points < 3000:
            level = "Gold"
            next_level = "Platinum"
            target = 3000
            req = target - points
            pct = round(((points - 1000) / 2000) * 100, 1)
            benefits = ["10% commission on referrals", "Dedicated partner support", "24-hr express payouts", "Amazon vouchers"]
        else:
            level = "Platinum"
            next_level = None
            target = points
            req = 0
            pct = 100.0
            benefits = ["15% VIP commission rate", "Executive account manager", "Instant wallet withdrawals", "Exclusive milestone bonuses"]

        return {
            "current_level": level,
            "next_level": next_level,
            "current_points": points,
            "points_required_to_next_level": req,
            "progress_percentage": min(100.0, max(0.0, pct)),
            "benefits": benefits
        }

    @staticmethod
    async def get_installation_statistics(db: AsyncSession, freelancer: Freelancer) -> Dict[str, Any]:
        stmt = select(
            FreelancerInstallationTracking.app_type,
            func.count(FreelancerInstallationTracking.id).label("total_installs"),
            func.count(FreelancerInstallationTracking.activation_date).label("total_activations"),
            func.sum(
                case((FreelancerInstallationTracking.retention_status.in_(["eligible", "retained"]), 1), else_=0)
            ).label("total_eligible"),
        ).where(
            FreelancerInstallationTracking.freelancer_id == freelancer.id
        ).group_by(FreelancerInstallationTracking.app_type)

        res = await db.execute(stmt)
        rows = res.all()

        stats = {
            "customer_installs": 0,
            "customer_activations": 0,
            "customer_eligible": 0,
            "vendor_installs": 0,
            "vendor_activations": 0,
            "vendor_eligible": 0,
            "as_of_date": datetime.utcnow().isoformat() + "Z"
        }

        for row in rows:
            app_t = row.app_type.lower()
            if "customer" in app_t:
                stats["customer_installs"] = int(row.total_installs or 0)
                stats["customer_activations"] = int(row.total_activations or 0)
                stats["customer_eligible"] = int(row.total_eligible or 0)
            elif "vendor" in app_t:
                stats["vendor_installs"] = int(row.total_installs or 0)
                stats["vendor_activations"] = int(row.total_activations or 0)
                stats["vendor_eligible"] = int(row.total_eligible or 0)

        return stats

    @staticmethod
    async def get_milestone_eligibility(db: AsyncSession, freelancer: Freelancer, app_type: str = "customer") -> List[Dict[str, Any]]:
        stmt_rules = select(FreelancerInstallationRule).where(
            and_(
                FreelancerInstallationRule.app_type == app_type,
                FreelancerInstallationRule.is_active.is_(True)
            )
        ).order_by(FreelancerInstallationRule.milestone_target)
        rules_res = await db.execute(stmt_rules)
        rules = rules_res.scalars().all()

        stmt_count = select(func.count(FreelancerInstallationTracking.id)).where(
            and_(
                FreelancerInstallationTracking.freelancer_id == freelancer.id,
                FreelancerInstallationTracking.app_type == app_type,
                FreelancerInstallationTracking.retention_status.in_(["eligible", "retained"])
            )
        )
        count_res = await db.execute(stmt_count)
        current_count = count_res.scalar() or 0

        milestones = []
        for r in rules:
            target = r.milestone_target
            achieved = current_count >= target
            pct = min(100.0, round((current_count / target) * 100, 1)) if target > 0 else 100.0

            milestones.append({
                "milestone_id": r.id,
                "app_type": r.app_type,
                "target": target,
                "current_eligible_count": current_count,
                "progress_percentage": pct,
                "achieved": achieved,
                "is_eligible": achieved,
                "reward_amount": float(r.reward_amount),
                "voucher_title": r.voucher_title,
                # Eligibility is derived from the rule and current count. A
                # claimed state requires a persisted claim record and cannot
                # be inferred from milestone completion.
                "reward_status": "eligible" if achieved else "locked"
            })

        return milestones

    @staticmethod
    async def create_payout_request(db: AsyncSession, freelancer: Freelancer, amount: float) -> FreelancerPayoutRequest:
        if amount <= 0:
            raise ValueError("Payout amount must be greater than zero")

        # Serialize balance changes for this freelancer so concurrent requests
        # cannot both spend the same available balance on PostgreSQL.
        locked_result = await db.execute(
            select(Freelancer).where(Freelancer.id == freelancer.id).with_for_update()
        )
        locked_freelancer = locked_result.scalar_one_or_none()
        if locked_freelancer is None:
            raise ValueError("Freelancer account was not found")
        freelancer = locked_freelancer

        if not freelancer.bank_account_number or not freelancer.bank_ifsc_code:
            raise ValueError("Bank details are required before requesting a payout")

        avail = float(freelancer.available_balance or 0.0)
        if amount > avail:
            raise ValueError(f"Insufficient available balance. Current available: ₹{avail:.2f}")

        min_payout = 500.0
        if amount < min_payout:
            raise ValueError(f"Minimum withdrawal amount is ₹{min_payout:.2f}")

        freelancer.available_balance = avail - amount
        freelancer.processing_balance = float(freelancer.processing_balance or 0.0) + amount

        payout_id = f"PO-{datetime.utcnow().strftime('%Y%m')}-{secrets.token_hex(3).upper()}"
        payout = FreelancerPayoutRequest(
            freelancer_id=freelancer.id,
            payout_id=payout_id,
            amount=amount,
            currency="INR",
            bank_name=freelancer.bank_name,
            bank_account_number=mask_account_number(freelancer.bank_account_number),
            bank_ifsc_code=freelancer.bank_ifsc_code,
            status="pending"
        )
        db.add(payout)

        txn_id = f"TXN-{uuid.uuid4().hex[:10].upper()}"
        txn = FreelancerWalletTransaction(
            freelancer_id=freelancer.id,
            transaction_id=txn_id,
            transaction_type="debit",
            category="withdrawal",
            description=f"Withdrawal request {payout_id} to bank {freelancer.bank_name}",
            amount=amount,
            balance_after=freelancer.available_balance,
            currency="INR",
            status="pending",
            reference_id=payout_id
        )
        db.add(txn)
        await db.commit()
        await db.refresh(payout)
        return payout

    @staticmethod
    async def submit_kyc_document(
        db: AsyncSession,
        freelancer: Freelancer,
        document_type: str,
        document_number: Optional[str],
        file_bytes: bytes,
        filename: str,
        content_type: str
    ) -> FreelancerKycDocument:
        url = await upload_service.upload_file(
            file_bytes, filename, content_type, require_public_storage=True
        )
        if not url:
            raise ValueError("KYC document storage is not configured or is unavailable")

        doc = FreelancerKycDocument(
            freelancer_id=freelancer.id,
            document_type=document_type.lower().strip(),
            document_number=document_number,
            file_url=url,
            file_name=filename,
            file_size_bytes=len(file_bytes),
            mime_type=content_type,
            status="PENDING"
        )
        db.add(doc)
        await db.commit()
        await db.refresh(doc)
        return doc

    @staticmethod
    async def submit_kyc_application(
        db: AsyncSession,
        freelancer: Freelancer,
        aadhaar: Optional[str],
        pan: Optional[str],
        gst: Optional[str],
        document_ids: List[int]
    ) -> FreelancerKycSubmission:
        sub_id = f"KYC-{datetime.utcnow().strftime('%Y%m')}-{secrets.token_hex(3).upper()}"
        sub = FreelancerKycSubmission(
            freelancer_id=freelancer.id,
            submission_id=sub_id,
            aadhaar_number=aadhaar,
            pan_number=pan,
            gst_number=gst,
            document_ids=document_ids,
            status="PENDING"
        )
        db.add(sub)
        freelancer.kyc_status = "PENDING"
        pct, _, _ = FreelanceService.calculate_completion(freelancer)
        freelancer.profile_completion_percentage = pct

        await db.commit()
        await db.refresh(sub)
        return sub

    @staticmethod
    async def start_face_verification(db: AsyncSession, freelancer: Freelancer) -> FreelancerFaceVerificationSession:
        ver_id = f"fv_{secrets.token_hex(6)}"
        token = f"fvs_{secrets.token_urlsafe(24)}"
        expires_at = datetime.utcnow() + timedelta(minutes=20)

        session = FreelancerFaceVerificationSession(
            freelancer_id=freelancer.id,
            verification_id=ver_id,
            session_token=token,
            provider="hyperverge",
            status="PENDING",
            expires_at=expires_at
        )
        db.add(session)
        freelancer.face_verification_status = "PENDING"
        await db.commit()
        await db.refresh(session)
        return session

    @staticmethod
    async def process_face_verification_webhook(
        db: AsyncSession,
        session_token: str,
        verification_id: str,
        status_val: str,
        liveness_score: Optional[float] = None,
        reason: Optional[str] = None
    ) -> FreelancerFaceVerificationSession:
        stmt = select(FreelancerFaceVerificationSession).where(
            and_(
                FreelancerFaceVerificationSession.session_token == session_token,
                FreelancerFaceVerificationSession.verification_id == verification_id
            )
        )
        res = await db.execute(stmt)
        session = res.scalar_one_or_none()
        if not session:
            raise ValueError("Verification session not found")

        status_norm = status_val.upper()
        if status_norm not in ("VERIFIED", "FAILED", "PENDING"):
            status_norm = "FAILED"

        session.status = status_norm
        session.liveness_score = liveness_score
        session.failure_reason = reason
        if status_norm == "VERIFIED":
            session.verified_at = datetime.utcnow()

        stmt_f = select(Freelancer).where(Freelancer.id == session.freelancer_id)
        res_f = await db.execute(stmt_f)
        freelancer = res_f.scalar_one_or_none()
        if freelancer:
            freelancer.face_verification_status = status_norm
            notif = FreelancerNotification(
                freelancer_id=freelancer.id,
                notification_id=f"ntf_{uuid.uuid4().hex[:8]}",
                title="Face Verification Update",
                body="Your face verification has been verified successfully." if status_norm == "VERIFIED" else f"Face verification was not successful: {reason or 'Please re-try.'}",
                type="FACE_VERIFICATION",
                reference_id=verification_id,
                deep_link="/profile/verification"
            )
            db.add(notif)

        await db.commit()
        await db.refresh(session)
        return session

    @staticmethod
    async def search_content(
        db: AsyncSession,
        query: str,
        scope: str = "all",
        page: int = 1,
        limit: int = 10
    ) -> Tuple[List[Dict[str, Any]], int]:
        q_term = f"%{query.strip().lower()}%"
        results: List[Dict[str, Any]] = []

        if scope in ("all", "services"):
            stmt_sub = select(ServiceSubcategory).where(
                and_(
                    ServiceSubcategory.is_active.is_(True),
                    or_(
                        func.lower(ServiceSubcategory.name).like(q_term),
                        func.lower(ServiceSubcategory.description).like(q_term)
                    )
                )
            ).limit(20)
            res_sub = await db.execute(stmt_sub)
            for sub in res_sub.scalars().all():
                results.append({
                    "id": f"service_{sub.id}",
                    "type": "service",
                    "title": sub.name,
                    "subtitle": sub.description or "AM5 Home Service",
                    "imageUrl": sub.icon_url,
                    "slug": sub.name.lower().replace(" ", "-"),
                    "targetUrl": f"/services/{sub.id}"
                })

        if scope in ("all", "faqs"):
            stmt_faq = select(FreelancerFaq).where(
                and_(
                    FreelancerFaq.is_active.is_(True),
                    or_(
                        func.lower(FreelancerFaq.question).like(q_term),
                        func.lower(FreelancerFaq.answer).like(q_term)
                    )
                )
            ).limit(10)
            res_faq = await db.execute(stmt_faq)
            for faq in res_faq.scalars().all():
                results.append({
                    "id": faq.faq_id,
                    "type": "faq",
                    "title": faq.question,
                    "subtitle": faq.answer[:120] + "..." if len(faq.answer) > 120 else faq.answer,
                    "imageUrl": None,
                    "slug": f"faq-{faq.id}",
                    "targetUrl": f"/support/faqs#{faq.faq_id}"
                })

        if scope in ("all", "videos"):
            stmt_vid = select(FreelancerDemoVideo).where(
                and_(
                    FreelancerDemoVideo.is_active.is_(True),
                    func.lower(FreelancerDemoVideo.title).like(q_term)
                )
            ).limit(10)
            res_vid = await db.execute(stmt_vid)
            for vid in res_vid.scalars().all():
                results.append({
                    "id": vid.video_id,
                    "type": "video",
                    "title": vid.title,
                    "subtitle": f"Demo video ({vid.duration})",
                    "imageUrl": vid.thumbnail_url,
                    "slug": vid.video_type,
                    "targetUrl": vid.video_url
                })

        total = len(results)
        offset = (page - 1) * limit
        paged_items = results[offset : offset + limit]
        return paged_items, total
