from typing import Optional
import hashlib
import hmac
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request, status, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text, select, delete

from app.db.session import get_db
from app.schemas.auth import (
    SendOTPRequest,
    VerifyOTPRequest,
    TokenResponse,
    BookingSecurityVerifyRequest,
    BookingSecurityResponse,
)
from app.core.security import create_access_token
from app.core.phone_numbers import normalize_indian_mobile
from app.core.rate_limit import limiter
from app.dependencies.auth import get_current_token_payload, get_current_customer
from app.schemas.vendor_registration import VendorRegistrationRequest
from app.models.user_location import User
from app.models.vendor import Vendor, VendorSubCategory, VendorReferralAttribution, VendorLoginEvent
from app.core.config import settings
from freelance_api.models import FreelancerReferralLink, FreelancerInstallationTracking
from app.models.user_location import Customer as CustomerModel

router = APIRouter()

from app.services.otp_service import otp_service
from app.services.otp_service import OTPStoreUnavailable

def normalize_phone_number(val: Optional[str]) -> Optional[str]:
    return normalize_indian_mobile(val)


@router.post("/vendor/send-otp")
@limiter.limit("5/minute")
async def send_vendor_otp(
    payload: SendOTPRequest,
    request: Request,
):
    if not payload.mobile and not payload.email:
        raise HTTPException(status_code=400, detail="Mobile or email is required")

    identifier = (payload.mobile or payload.email).strip()
    phone_10 = normalize_phone_number(identifier)
    if not phone_10 and "@" not in identifier:
        raise HTTPException(status_code=422, detail="Enter a valid mobile number or email")
    identifier = phone_10 or identifier.lower()

    try:
        otp = await otp_service.generate_otp(identifier)
        sent = (
            await otp_service.send_otp_sms(phone_10, otp)
            if phone_10
            else await otp_service.send_otp_email(identifier, otp)
        )
        if not sent:
            await otp_service.delete_otp(identifier)
            raise HTTPException(
                status_code=503,
                detail="OTP delivery is temporarily unavailable",
            )
    except OTPStoreUnavailable:
        raise HTTPException(
            status_code=503,
            detail="OTP service is temporarily unavailable",
        ) from None

    return {
        "message": "Verification code accepted by the delivery provider",
    }

@router.post("/vendor/verify-otp", response_model=TokenResponse)
@limiter.limit("10/minute")
async def verify_vendor_otp(payload: VerifyOTPRequest, request: Request, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    if not payload.mobile and not payload.email:
        raise HTTPException(status_code=400, detail="Mobile or email is required")
        
    identifier = (payload.mobile or payload.email).strip()
    phone_10 = normalize_phone_number(identifier)
    
    try:
        is_valid = await otp_service.verify_otp(
            phone_10 or identifier.strip().lower(),
            payload.otp,
        )
    except OTPStoreUnavailable:
        raise HTTPException(status_code=503, detail="OTP verification is temporarily unavailable") from None
                    
    if not is_valid:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")
    
    # Check if user exists
    if phone_10:
        user_query = await db.execute(
            select(User).where(
                (User.mobile == identifier) |
                (User.mobile == phone_10) |
                (User.mobile == f"+91{phone_10}") |
                (User.mobile == f"91{phone_10}") |
                (User.email == identifier)
            ).order_by(User.id.asc())
        )
    else:
        user_query = await db.execute(
            select(User).where((User.mobile == identifier) | (User.email == identifier)).order_by(User.id.asc())
        )
    user = user_query.scalars().first()
    
    if user and user.deletion_scheduled_at:
        if user.deletion_scheduled_at <= datetime.utcnow():
            raise HTTPException(status_code=403, detail="Account deleted")
        else:
            # User came back within 30 days
            user.deletion_scheduled_at = None
            db.add(user)
            await db.flush()
    
    if not user:
        # Create User
        is_mobile = identifier.isdigit() or (identifier.startswith('+') and identifier[1:].isdigit())
        mobile = identifier if is_mobile else None
        email = identifier if not is_mobile else None
        
        user = User(
            mobile=mobile,
            email=email,
            role="VENDOR",
            is_active=True,
            otp_verified=True
        )
        db.add(user)
        await db.flush()
    else:
        # Ensure role contains VENDOR
        if not user.role:
            user.role = "VENDOR"
            db.add(user)
            await db.flush()
        elif "VENDOR" not in str(user.role):
            user.role = user.role + ",VENDOR"
            db.add(user)
            await db.flush()

    # Check if vendor exists for this user
    vendor_query = await db.execute(
        select(Vendor).where(Vendor.user_id == user.id).order_by(Vendor.id.asc())
    )
    vendor = vendor_query.scalars().first()
    
    is_new_user = False
    lead_src = "company_website" if payload.platform == "web" else "company_mobile"
    if not vendor:
        is_new_user = True
        # Create Vendor in onboarding state
        vendor = Vendor(
            user_id=user.id,
            status="onboarding",
            lead_source=lead_src
        )
        db.add(vendor)
        await db.flush()
    else:
        if vendor.status == "onboarding":
            is_new_user = True
        if not vendor.lead_source:
            vendor.lead_source = lead_src
            db.add(vendor)

    if payload.fcm_token:
        user.fcm_token = payload.fcm_token
        db.add(user)
        await db.flush()
    elif not user.fcm_token:
        from app.models.device import DeviceInstallation
        # 1. Try to find device with user_id
        device_query = await db.execute(
            select(DeviceInstallation)
            .where(DeviceInstallation.user_id == user.id, DeviceInstallation.fcm_token.is_not(None))
            .order_by(DeviceInstallation.last_active_at.desc())
        )
        device = device_query.scalars().first()
        
        if device and device.fcm_token:
            user.fcm_token = device.fcm_token
            device.user_id = user.id
            db.add(device)
            db.add(user)
            await db.flush()

    # Persist only a keyed digest as the authentication event identifier. The
    # OTP, access token, refresh token, and password are never stored here.
    now_utc = datetime.now(timezone.utc)
    client_event_key = (request.headers.get("Idempotency-Key") or "").strip()
    if len(client_event_key) > 128:
        client_event_key = ""
    retry_nonce = client_event_key or (
        f"otp-retry:{payload.otp}:{int(now_utc.timestamp()) // 30}"
    )
    event_id = hmac.new(
        settings.SECRET_KEY.encode("utf-8"),
        f"vendor-login:{user.id}:{vendor.id}:{retry_nonce}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    # Serialize successful logins per Vendor so only one event can be marked
    # as the first login, including concurrent OTP verifications.
    await db.execute(
        select(Vendor.id).where(Vendor.id == vendor.id).with_for_update()
    )
    existing_event = (await db.execute(
        select(VendorLoginEvent.id).where(VendorLoginEvent.event_id == event_id)
    )).scalar_one_or_none()
    if existing_event is None:
        attribution_id = (await db.execute(
            select(VendorReferralAttribution.id).where(
                VendorReferralAttribution.vendor_id == vendor.id
            )
        )).scalar_one_or_none()
        previous_login = (await db.execute(
            select(VendorLoginEvent.id)
            .where(VendorLoginEvent.vendor_id == vendor.id)
            .limit(1)
        )).scalar_one_or_none()
        db.add(VendorLoginEvent(
            event_id=event_id,
            user_id=user.id,
            vendor_id=vendor.id,
            referral_attribution_id=attribution_id,
            login_at=now_utc,
            login_method="otp",
            session_event_id=event_id,
            login_result="success",
            is_first_login=previous_login is None,
        ))

    await db.commit()

    # Generate standard permanent token
    access_token = create_access_token(subject=str(user.id))
    
    # Send Login Success Push Notification
    from app.services.notification_service import send_user_push_notification
    background_tasks.add_task(
        send_user_push_notification,
        user_id=user.id,
        title="Login Successful",
        body="Welcome to AM5Royal! You have logged in successfully.",
    )

    return TokenResponse(
        access_token=access_token,
        is_new_user=is_new_user
    )

@router.post("/customer/send-otp")
@limiter.limit("5/minute")
async def send_customer_otp(
    request: SendOTPRequest,
    http_request: Request,
):
    if not request.mobile and not request.email:
        raise HTTPException(status_code=400, detail="Mobile or email is required")

    identifier = (request.mobile or request.email).strip()
    phone_10 = normalize_phone_number(identifier)
    if not phone_10 and "@" not in identifier:
        raise HTTPException(status_code=422, detail="Enter a valid mobile number or email")
    identifier = phone_10 or identifier.lower()

    try:
        otp = await otp_service.generate_otp(identifier)
        sent = (
            await otp_service.send_otp_sms(phone_10, otp)
            if phone_10
            else await otp_service.send_otp_email(identifier, otp)
        )
        if not sent:
            await otp_service.delete_otp(identifier)
            raise HTTPException(
                status_code=503,
                detail="OTP delivery is temporarily unavailable",
            )
    except OTPStoreUnavailable:
        raise HTTPException(
            status_code=503,
            detail="OTP service is temporarily unavailable",
        ) from None

    return {
        "message": "Verification code accepted by the delivery provider",
    }

@router.post("/customer/verify-otp", response_model=TokenResponse)
@limiter.limit("10/minute")
async def verify_customer_otp(request: VerifyOTPRequest, http_request: Request, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    if not request.mobile and not request.email:
        raise HTTPException(status_code=400, detail="Mobile or email is required")
        
    identifier = (request.mobile or request.email).strip()
    phone_10 = normalize_phone_number(identifier)
    
    try:
        is_valid = await otp_service.verify_otp(
            phone_10 or identifier.strip().lower(),
            request.otp,
        )
    except OTPStoreUnavailable:
        raise HTTPException(status_code=503, detail="OTP verification is temporarily unavailable") from None
                    
    if not is_valid:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")
    
    # Check if user exists
    if phone_10:
        user_query = await db.execute(
            select(User).where(
                (User.mobile == identifier) | 
                (User.mobile == phone_10) | 
                (User.mobile == f"+91{phone_10}") | 
                (User.mobile == f"91{phone_10}") | 
                (User.email == identifier)
            ).order_by(User.id.asc())
        )
    else:
        user_query = await db.execute(
            select(User).where((User.mobile == identifier) | (User.email == identifier)).order_by(User.id.asc())
        )
    user = user_query.scalars().first()
    
    if user and user.deletion_scheduled_at:
        from datetime import datetime
        if user.deletion_scheduled_at <= datetime.utcnow():
            raise HTTPException(status_code=403, detail="Account deleted")
        else:
            # User came back within 30 days
            user.deletion_scheduled_at = None
            db.add(user)
            await db.flush()
    
    is_new_user = False
    if not user:
        is_new_user = True
        # Create User
        is_mobile = bool(phone_10)
        mobile = phone_10 if is_mobile else None
        email = identifier if not is_mobile else f"customer_{phone_10}@am5royal.com"
        
        user = User(
            mobile=mobile,
            email=email,
            role="CUSTOMER",
            is_active=True,
            otp_verified=True
        )
        db.add(user)
        await db.flush()
    else:
        # Ensure role contains CUSTOMER
        if not user.role:
            user.role = "CUSTOMER"
            db.add(user)
            await db.flush()
        elif "CUSTOMER" not in str(user.role):
            user.role = user.role + ",CUSTOMER"
            db.add(user)
            await db.flush()

    # Ensure a customers row exists for booking APIs (linked via user_id).
    customer_query = await db.execute(
        select(CustomerModel).where(CustomerModel.user_id == user.id)
    )
    customer = customer_query.scalar_one_or_none()
    if not customer:
        display_name = "Customer"
        phone = user.mobile or identifier
        email = user.email if user.email and "@" in user.email else None
        customer = CustomerModel(
            user_id=user.id,
            full_name=display_name,
            phone=phone,
            email=email,
        )
        db.add(customer)
        await db.flush()
    elif is_new_user:
        if not customer.phone and user.mobile:
            customer.phone = user.mobile
            db.add(customer)
            await db.flush()

    if request.fcm_token:
        user.fcm_token = request.fcm_token
        db.add(user)
        await db.flush()
    elif not user.fcm_token:
        from app.models.device import DeviceInstallation
        device_query = await db.execute(
            select(DeviceInstallation)
            .where(DeviceInstallation.user_id == user.id, DeviceInstallation.fcm_token.is_not(None))
            .order_by(DeviceInstallation.last_active_at.desc())
        )
        device = device_query.scalars().first()
        if device and device.fcm_token:
            user.fcm_token = device.fcm_token
            db.add(user)
            await db.flush()

    await db.commit()

    # Generate standard permanent token
    access_token = create_access_token(subject=str(user.id))
    
    # Send Welcome Push Notification after OTP Verification (new users only)
    if is_new_user:
        from app.services.notification_service import send_user_push_notification
        background_tasks.add_task(
            send_user_push_notification,
            user_id=user.id,
            title="Welcome to AM5 Royal",
            body="Welcome to AM5 Royal! Your login was successful.",
        )

    return TokenResponse(
        access_token=access_token,
        is_new_user=is_new_user
    )


@router.post("/customer/booking-security/send-otp")
@limiter.limit("5/minute")
async def send_booking_security_otp(
    request: Request,
    current_customer: CustomerModel = Depends(get_current_customer),
):
    """
    Send booking security OTP to the customer's registered mobile number.
    Uses the Website OTP SMS template.
    """
    phone = (current_customer.phone or "").strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Customer phone number not found")

    try:
        otp = await otp_service.generate_otp(phone, length=5)
        sent = await otp_service.send_booking_otp_sms(phone, otp)
        if not sent:
            await otp_service.delete_otp(phone)
            raise HTTPException(
                status_code=503,
                detail="OTP delivery is temporarily unavailable",
            )
    except OTPStoreUnavailable:
        raise HTTPException(status_code=503, detail="OTP service is temporarily unavailable") from None

    return {
        "message": "Security OTP sent successfully",
        "customer_id": current_customer.id,
    }


@router.post(
    "/customer/booking-security/verify-otp",
    response_model=BookingSecurityResponse,
)
@limiter.limit("10/minute")
async def verify_booking_security_otp(
    request: BookingSecurityVerifyRequest,
    http_request: Request,
    current_customer: CustomerModel = Depends(get_current_customer),
):
    """
    Verify the booking security OTP before order creation.
    """
    phone = (current_customer.phone or "").strip()
    if not phone:
        raise HTTPException(status_code=400, detail="Customer phone number not found")

    try:
        is_valid = await otp_service.verify_otp(phone, request.otp)
    except OTPStoreUnavailable:
        raise HTTPException(status_code=503, detail="OTP verification is temporarily unavailable") from None
    if not is_valid:
        raise HTTPException(status_code=400, detail="Invalid or expired security OTP")

    return BookingSecurityResponse(
        message="Security verification successful",
        verified=True,
    )


@router.post("/vendor/register", response_model=TokenResponse)
async def register_vendor(
    request: VendorRegistrationRequest,
    db: AsyncSession = Depends(get_db),
    token_payload: dict = Depends(get_current_token_payload)
):
    """
    Register a new vendor profile or complete the onboarding for an existing one.
    """
    token_sub = str(token_payload.get("sub", ""))
    
    if not token_sub.isdigit():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid token for registration"
        )
        
    user_id = int(token_sub)
    
    # Check if vendor already exists
    vendor_query = await db.execute(select(Vendor).where(Vendor.user_id == user_id))
    existing_vendor = vendor_query.scalar_one_or_none()
    
    if not existing_vendor:
        raise HTTPException(status_code=404, detail="Vendor profile not found. Verify OTP first.")
        
    if existing_vendor.status == "active":
        raise HTTPException(status_code=400, detail="Vendor is already fully registered")

    referral_link = None
    existing_attribution = (await db.execute(
        select(VendorReferralAttribution).where(
            VendorReferralAttribution.vendor_id == existing_vendor.id
        )
    )).scalar_one_or_none()
    # A stored referral is immutable. A later link open/login cannot replace it.
    if existing_attribution is None and existing_vendor.freelancer_id is None and request.referral_code:
        candidate = (await db.execute(
            select(FreelancerReferralLink).where(
                FreelancerReferralLink.referral_code == request.referral_code.strip(),
            )
        )).scalar_one_or_none()
        now_utc = datetime.now(timezone.utc).replace(tzinfo=None)

        if request.referral_service_id is not None:
            # Keep the Home Services referral contract unchanged.
            service_selected = any(
                cat.main_category_id == 37 and request.referral_service_id in cat.sub_category_ids
                for cat in request.categories
            )
            if not service_selected:
                raise HTTPException(status_code=422, detail="Choose the invited Home Service to continue.")
            if (
                candidate is None
                or candidate.status != "active"
                or candidate.referral_type != "service"
                or candidate.target_service_category_id != 37
                or candidate.target_sub_service_id != request.referral_service_id
                or candidate.expires_at <= now_utc
            ):
                raise HTTPException(status_code=400, detail="This service invitation is invalid or has expired. Please request a new link.")
            referral_link = candidate
        elif candidate is not None and candidate.referral_type == "vendor":
            # A verified install remains attributable after link expiry when
            # its backend-validated Install Referrer timestamp fell inside the
            # link's validity window. The click ID is never trusted by itself.
            if (
                candidate.status == "active"
                and candidate.expires_at > now_utc
            ):
                referral_link = candidate
            elif (
                candidate.status in {"active", "expired"}
                and request.referral_installation_id
            ):
                install_tracking = (await db.execute(
                    select(FreelancerInstallationTracking).where(
                        FreelancerInstallationTracking.tracking_id
                        == request.referral_installation_id
                    )
                )).scalar_one_or_none()
                install_at = install_tracking.install_date if install_tracking else None
                if install_at is not None and install_at.tzinfo is not None:
                    install_at = install_at.astimezone(timezone.utc).replace(tzinfo=None)
                if (
                    install_tracking is None
                    or install_tracking.referral_code != candidate.referral_code
                    or install_tracking.freelancer_id != candidate.freelancer_id
                    or (install_tracking.app_type or "").lower() != "vendor"
                    or install_at is None
                    or install_at < candidate.created_at
                    or install_at > candidate.expires_at
                ):
                    raise HTTPException(
                        status_code=409,
                        detail="Install tracking does not match a valid Vendor referral click",
                    )
                referral_link = candidate
            elif request.referral_installation_id:
                raise HTTPException(
                    status_code=409,
                    detail="Install tracking does not match an eligible Vendor referral",
                )
        elif request.referral_installation_id:
            raise HTTPException(
                status_code=409,
                detail="Install tracking does not match a Vendor referral",
            )
        elif candidate is not None and candidate.referral_type == "service":
            raise HTTPException(status_code=422, detail="The service invitation is incomplete. Please reopen the link.")
        
    # Update Vendor Profile
    existing_vendor.first_name = request.first_name
    existing_vendor.last_name = request.last_name
    existing_vendor.father_name = request.father_name
    if request.email:
        existing_vendor.email = request.email
    if request.mobile:
        existing_vendor.mobile = request.mobile
    if request.alternative_number:
        existing_vendor.alternative_number = request.alternative_number
    existing_vendor.business_name = request.business_name
    existing_vendor.aadhaar_number = request.aadhaar_number
    existing_vendor.address = request.address
    existing_vendor.street = request.street
    existing_vendor.city = request.city
    existing_vendor.district = request.district
    existing_vendor.state = request.state
    existing_vendor.pincode = request.pincode
    existing_vendor.latitude = request.latitude
    existing_vendor.longitude = request.longitude
    existing_vendor.service_radius_km = request.service_radius_km
    existing_vendor.profile_image = request.profile_image
    existing_vendor.status = "registration"

    if existing_attribution is not None:
        existing_vendor.freelancer_id = existing_attribution.freelancer_id
    elif referral_link is not None:
        existing_vendor.freelancer_id = referral_link.freelancer_id
        existing_vendor.lead_source = "freelancer"
    
    db.add(existing_vendor)
    vendor_id = existing_vendor.id

    if referral_link is not None:
        db.add(VendorReferralAttribution(
            vendor_id=vendor_id,
            user_id=user_id,
            freelancer_id=referral_link.freelancer_id,
            referral_link_id=referral_link.id,
            referral_code=referral_link.referral_code,
            service_id=referral_link.target_sub_service_id,
            installation_tracking_id=(
                request.referral_installation_id
                if referral_link.referral_type == "vendor"
                else None
            ),
            registration_status="success",
            registration_source=(
                "install_referrer"
                if referral_link.referral_type == "vendor"
                and request.referral_installation_id
                else "home_service_referral"
                if referral_link.referral_type == "service"
                else "vendor_referral"
            ),
            attributed_at=datetime.now(timezone.utc),
        ))
        referral_link.conversions_count = (referral_link.conversions_count or 0) + 1
        db.add(referral_link)
        if (
            referral_link.referral_type == "vendor"
            and request.referral_installation_id
        ):
            tracking_result = await db.execute(
                select(FreelancerInstallationTracking).where(
                    FreelancerInstallationTracking.tracking_id
                    == request.referral_installation_id
                )
            )
            install_tracking = tracking_result.scalar_one_or_none()
            now = datetime.now(timezone.utc).replace(tzinfo=None)
            if install_tracking is not None and (
                install_tracking.referral_code != referral_link.referral_code
                or install_tracking.freelancer_id != referral_link.freelancer_id
                or (install_tracking.app_type or "").lower() != "vendor"
            ):
                raise HTTPException(
                    status_code=409,
                    detail="Install tracking does not match the Vendor referral",
                )
            if install_tracking is None:
                raise HTTPException(
                    status_code=409,
                    detail="No verified Vendor Install Referrer attribution exists",
                )
            elif install_tracking.activation_date is None:
                install_tracking.activation_date = now
                db.add(install_tracking)

    if request.email:
        user_query = await db.execute(select(User).where(User.id == user_id))
        user_obj = user_query.scalar_one_or_none()
        if user_obj and user_obj.email != request.email:
            existing_email_user = (await db.execute(
                select(User.id).where(User.email == request.email, User.id != user_id)
            )).scalar_one_or_none()
            if not existing_email_user:
                user_obj.email = request.email
                db.add(user_obj)
    
    # Delete existing categories if any
    await db.execute(delete(VendorSubCategory).where(VendorSubCategory.vendor_id == vendor_id))
    
    # Add Categories
    for cat in request.categories:
        for sub_cat_id in cat.sub_category_ids:
            new_sub_cat = VendorSubCategory(
                vendor_id=vendor_id,
                main_category_id=cat.main_category_id,
                sub_category_id=sub_cat_id
            )
            db.add(new_sub_cat)
            
    await db.commit()
    
    access_token = create_access_token(subject=str(user_id))
    
    return TokenResponse(
        access_token=access_token,
        is_new_user=False
    )

from pydantic import BaseModel

class FCMTokenRequest(BaseModel):
    fcm_token: str

@router.put("/users/fcm-token")
async def update_fcm_token(
    request: FCMTokenRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    token_payload: dict = Depends(get_current_token_payload)
):
    token_sub = str(token_payload.get("sub", ""))
    if not token_sub.isdigit():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )
        
    user_id = int(token_sub)
    
    user_query = await db.execute(select(User).where(User.id == user_id))
    user = user_query.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    had_fcm_token = bool(user.fcm_token)
    user.fcm_token = request.fcm_token
    db.add(user)
    await db.commit()

    # Welcome push only on first-ever FCM registration — not on routine token refresh/sync
    # (e.g. when app opens and calls onboarding-status alongside FCM upload).
    if not had_fcm_token and request.fcm_token:
        from app.services.notification_service import send_user_push_notification
        background_tasks.add_task(
            send_user_push_notification,
            user_id=user.id,
            title="Welcome to AM5 Royal",
            body="Welcome to AM5 royal! Only a few steps are left to complete your registration.",
        )

    return {"message": "FCM token updated successfully"}

from app.dependencies.auth import get_current_customer
from pydantic import BaseModel as PydanticBaseModel

class CustomerProfileResponse(PydanticBaseModel):
    id: int
    full_name: str
    phone: str
    email: str | None = None

class CustomerProfileUpdate(PydanticBaseModel):
    full_name: str | None = None
    email: str | None = None

@router.get("/customer/me", response_model=CustomerProfileResponse)
async def get_customer_profile(
    db: AsyncSession = Depends(get_db),
    current_customer: CustomerModel = Depends(get_current_customer),
):
    return CustomerProfileResponse(
        id=current_customer.id,
        full_name=current_customer.full_name or "Customer",
        phone=current_customer.phone,
        email=current_customer.email,
    )

@router.put("/customer/profile", response_model=CustomerProfileResponse)
async def update_customer_profile(
    request: CustomerProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current_customer: CustomerModel = Depends(get_current_customer),
):
    if request.full_name:
        current_customer.full_name = request.full_name.strip()
    if request.email:
        current_customer.email = request.email.strip()
    db.add(current_customer)
    await db.commit()
    await db.refresh(current_customer)
    return CustomerProfileResponse(
        id=current_customer.id,
        full_name=current_customer.full_name or "Customer",
        phone=current_customer.phone,
        email=current_customer.email,
    )

