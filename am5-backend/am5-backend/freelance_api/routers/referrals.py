from datetime import datetime, timedelta, timezone
import hashlib
import secrets
from typing import Optional, List
from fastapi import APIRouter, Depends, Query, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse, RedirectResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc, func, case
from sqlalchemy.exc import IntegrityError
from urllib.parse import quote, urlencode

from app.db.session import get_db
from app.models.freelancer import Freelancer
from app.models.vendor import Vendor, VendorReferralAttribution, VendorLoginEvent
from freelance_api.dependencies import get_current_freelancer
from freelance_api.models import (
    FreelancerReferralLink,
    FreelancerReferralClickEvent,
    FreelancerReferralActionEvent,
    FreelancerReferralReward,
    FreelancerInstallationTracking,
)
from freelance_api.schemas import (
    ApiResponse,
    PaginatedData,
    GenerateReferralLinkRequest,
    ReferralLinkItemResponse,
    ReferralValidationResponse,
    ReferralRewardsSummaryResponse,
    ReferralLevelProgressResponse,
    ReferralPointHistoryItem,
    ReferralRulesResponse,
    ReferralRuleItem,
    VendorReferralDashboardResponse,
    VendorInstallTrackingRequest,
    VendorInstallTrackingResponse,
    ReferralActionEventRequest,
)
from freelance_api.service import (
    ActiveServiceReferralConflict,
    ActiveVendorReferralConflict,
    FreelanceService,
    home_service_referral_url,
)
from freelance_api.service import HOME_SERVICE_VENDOR_SLUG_BY_SUBCATEGORY_ID, home_service_vendor_slug
from freelance_api.service import is_valid_home_service_destination

router = APIRouter(tags=["Referrals & Refer & Earn"])

_VISITOR_COOKIE = "__Host-am5_referral_visitor"
_REFERRAL_COOKIE_MAX_AGE = 60 * 60 * 24 * 180


def _referral_response_url(link: FreelancerReferralLink) -> str:
    if link.referral_type == "service":
        return (
            home_service_referral_url(
                link.target_sub_service_id or 0,
                link.target_sub_service_name,
                link.referral_code,
            )
            or link.url
        )
    return link.url


@router.get("/referrals/vendor/click/{code}", include_in_schema=False)
async def track_vendor_referral_click(
    code: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Commit a valid Vendor referral click, then redirect to Google Play."""
    clean_code = code.strip()
    result = await db.execute(
        select(FreelancerReferralLink).where(
            FreelancerReferralLink.referral_code == clean_code,
            FreelancerReferralLink.referral_type == "vendor",
        )
    )
    referral = result.scalar_one_or_none()
    now_utc = datetime.now(timezone.utc)
    expiry = referral.expires_at if referral is not None else None
    if expiry is not None and expiry.tzinfo is not None:
        expiry = expiry.astimezone(timezone.utc).replace(tzinfo=None)
    if (
        referral is not None
        and referral.status == "active"
        and expiry is not None
        and expiry <= now_utc.replace(tzinfo=None)
    ):
        referral.status = "expired"
        await db.commit()
    if (
        referral is None
        or referral.status != "active"
        or expiry is None
        or expiry <= now_utc.replace(tzinfo=None)
    ):
        raise HTTPException(status_code=404, detail="Vendor referral is invalid or expired")

    freelancer_result = await db.execute(
        select(Freelancer).where(Freelancer.id == referral.freelancer_id)
    )
    freelancer = freelancer_result.scalar_one_or_none()
    if freelancer is None:
        raise HTTPException(status_code=404, detail="Vendor referral is unavailable")
    referral_id = referral.id
    freelancer_id = referral.freelancer_id
    referral_code = referral.referral_code
    referrer_name = freelancer.full_name or "AM5 ROYAL"

    visitor_token = request.cookies.get(_VISITOR_COOKIE) or secrets.token_urlsafe(32)
    visitor_id = hashlib.sha256(visitor_token.encode("utf-8")).hexdigest()
    # Every request represents a separate recipient click. Keep the visitor
    # identifier privacy-safe, but never reuse a click ID across requests.
    event_id = secrets.token_hex(32)

    db.add(FreelancerReferralClickEvent(
        event_id=event_id,
        referral_id=referral_id,
        freelancer_id=freelancer_id,
        visitor_id=visitor_id,
        destination_type="PLAY_STORE",
        destination_url="https://play.google.com/store/apps/details?id=com.am5royal.am5royal",
        event_token_hash=hashlib.sha256(event_id.encode("utf-8")).hexdigest(),
        clicked_at=now_utc,
        redirect_status="redirected",
    ))
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        existing_result = await db.execute(
            select(FreelancerReferralClickEvent).where(
                FreelancerReferralClickEvent.event_id == event_id
            )
        )
        existing = existing_result.scalar_one_or_none()
        if (
            existing is None
            or existing.referral_id != referral_id
            or existing.freelancer_id != freelancer_id
            or existing.visitor_id != visitor_id
        ):
            raise HTTPException(
                status_code=503,
                detail="Referral tracking is temporarily unavailable",
            )
    except Exception:
        await db.rollback()
        raise HTTPException(
            status_code=503,
            detail="Referral tracking is temporarily unavailable",
        )

    install_referrer = urlencode({
        "referral_type": "vendor",
        "referral_code": referral_code,
        "referrer_name": referrer_name,
        "click_id": event_id,
    })
    play_store_url = "https://play.google.com/store/apps/details?" + urlencode({
        "id": "com.am5royal.am5royal",
        "referrer": install_referrer,
    })
    response = RedirectResponse(url=play_store_url, status_code=302)
    response.set_cookie(
        _VISITOR_COOKIE,
        visitor_token,
        max_age=_REFERRAL_COOKIE_MAX_AGE,
        httponly=True,
        secure=True,
        samesite="lax",
        path="/",
    )
    return response


@router.get("/referrals/service/click/{code}", include_in_schema=False)
async def track_service_referral_click(
    code: str,
    request: Request,
    redirect: bool = Query(default=True, include_in_schema=False),
    verify_click: bool = Query(default=False, include_in_schema=False),
    click_id: Optional[str] = Query(default=None, min_length=64, max_length=64, include_in_schema=False),
    db: AsyncSession = Depends(get_db),
):
    """Commit a valid Home Services referral click before its allowlisted redirect."""
    clean_code = code.strip()
    result = await db.execute(
        select(FreelancerReferralLink).where(
            FreelancerReferralLink.referral_code == clean_code,
            FreelancerReferralLink.referral_type == "service",
        )
    )
    referral = result.scalar_one_or_none()
    now_utc = datetime.now(timezone.utc)
    expiry = referral.expires_at if referral is not None else None
    if expiry is not None and expiry.tzinfo is not None:
        expiry = expiry.astimezone(timezone.utc).replace(tzinfo=None)
    is_expired = expiry is not None and expiry <= now_utc.replace(tzinfo=None)
    if referral is not None and referral.status == "active" and is_expired:
        referral.status = "expired"
        await db.commit()
    if (
        referral is None
        or referral.status != "active"
        or expiry is None
        or is_expired
    ):
        raise HTTPException(status_code=404, detail="Service referral is invalid or expired")

    freelancer_result = await db.execute(
        select(Freelancer).where(Freelancer.id == referral.freelancer_id)
    )
    if freelancer_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Service referral is unavailable")
    referral_id = referral.id
    freelancer_id = referral.freelancer_id
    service_id = referral.target_sub_service_id
    if referral.target_service_category_id != 37:
        raise HTTPException(status_code=404, detail="Service referral destination is unavailable")
    slug = home_service_vendor_slug(service_id, referral.target_sub_service_name)
    if slug is None:
        raise HTTPException(status_code=404, detail="Service referral destination is unavailable")

    # Both host and path are derived from the fixed permanent-destination allowlist.
    destination_base = f"https://vendor.am5royal.com/map/homeservices/{slug}"
    if not is_valid_home_service_destination(
        service_id, destination_base, referral.target_sub_service_name
    ):
        raise HTTPException(status_code=404, detail="Service referral destination is unavailable")
    visitor_token = request.cookies.get(_VISITOR_COOKIE) or secrets.token_urlsafe(32)
    visitor_id = hashlib.sha256(visitor_token.encode("utf-8")).hexdigest()
    event_id = secrets.token_hex(32)
    destination_url = (
        destination_base
        + "?ref=" + quote(clean_code, safe="")
        + "&click_id=" + event_id
    )

    if verify_click:
        if click_id is None:
            raise HTTPException(status_code=422, detail="A stored click ID is required")
        stored_click_result = await db.execute(
            select(FreelancerReferralClickEvent).where(
                FreelancerReferralClickEvent.event_id == click_id,
                FreelancerReferralClickEvent.referral_id == referral_id,
                FreelancerReferralClickEvent.freelancer_id == freelancer_id,
                FreelancerReferralClickEvent.service_id == service_id,
                FreelancerReferralClickEvent.destination_type == "SERVICE",
                FreelancerReferralClickEvent.redirect_status == "redirected",
            )
        )
        stored_click = stored_click_result.scalar_one_or_none()
        if (
            stored_click is None
            or stored_click.destination_url
            != destination_base + "?ref=" + quote(clean_code, safe="")
            + "&click_id=" + click_id
        ):
            raise HTTPException(status_code=404, detail="Stored service click was not found")
        return JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Service referral click verified",
                "data": {"destination_url": stored_click.destination_url, "click_id": click_id},
            },
        )

    db.add(FreelancerReferralClickEvent(
        event_id=event_id,
        referral_id=referral_id,
        freelancer_id=freelancer_id,
        visitor_id=visitor_id,
        destination_type="SERVICE",
        service_id=service_id,
        destination_url=destination_url,
        event_token_hash=hashlib.sha256(event_id.encode("utf-8")).hexdigest(),
        clicked_at=now_utc,
        redirect_status="redirected" if redirect else "recorded",
    ))
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        existing_result = await db.execute(
            select(FreelancerReferralClickEvent).where(
                FreelancerReferralClickEvent.event_id == event_id
            )
        )
        existing = existing_result.scalar_one_or_none()
        if (
            existing is None
            or existing.referral_id != referral_id
            or existing.freelancer_id != freelancer_id
            or existing.visitor_id != visitor_id
        ):
            raise HTTPException(status_code=503, detail="Referral tracking is temporarily unavailable")
    except Exception:
        await db.rollback()
        raise HTTPException(status_code=503, detail="Referral tracking is temporarily unavailable")

    if redirect:
        response = RedirectResponse(url=destination_url, status_code=302)
    else:
        response = JSONResponse(
            status_code=200,
            content={
                "success": True,
                "message": "Service referral click recorded",
                "data": {"destination_url": destination_url, "click_id": event_id},
            },
        )
    response.set_cookie(_VISITOR_COOKIE, visitor_token, max_age=_REFERRAL_COOKIE_MAX_AGE,
                        httponly=True, secure=True, samesite="lax", path="/")
    return response


@router.get(
    "/referrals/vendor/dashboard",
    response_model=ApiResponse[VendorReferralDashboardResponse],
)
async def get_vendor_referral_dashboard(
    current_freelancer: Freelancer = Depends(get_current_freelancer),
    db: AsyncSession = Depends(get_db),
):
    """Return vendor referral counts supported by stored records only."""
    link_result = await db.execute(
        select(FreelancerReferralLink.referral_code).where(
            and_(
                FreelancerReferralLink.freelancer_id == current_freelancer.id,
                FreelancerReferralLink.referral_type == "vendor",
            )
        )
    )
    referral_codes = list(link_result.scalars().all())

    vendor_count_result = await db.execute(
        select(func.count(func.distinct(VendorReferralAttribution.vendor_id))).where(
            VendorReferralAttribution.freelancer_id == current_freelancer.id
        )
    )
    active_vendor_count_result = await db.execute(
        select(func.count(func.distinct(Vendor.id)))
        .join(VendorReferralAttribution, VendorReferralAttribution.vendor_id == Vendor.id)
        .where(
            and_(
                VendorReferralAttribution.freelancer_id == current_freelancer.id,
                func.lower(func.coalesce(Vendor.status, "")) == "active",
            )
        )
    )

    install_count = 0
    pending_registration_count = 0
    if referral_codes:
        install_count_result = await db.execute(
            select(
                func.count(
                    func.distinct(FreelancerInstallationTracking.tracking_id)
                )
            ).where(
                and_(
                    FreelancerInstallationTracking.freelancer_id
                    == current_freelancer.id,
                    func.lower(FreelancerInstallationTracking.app_type).like(
                        "%vendor%"
                    ),
                    FreelancerInstallationTracking.referral_code.in_(referral_codes),
                )
            )
        )
        install_count = int(install_count_result.scalar() or 0)
        pending_result = await db.execute(
            select(
                func.count(func.distinct(FreelancerInstallationTracking.tracking_id))
            ).where(
                and_(
                    FreelancerInstallationTracking.freelancer_id
                    == current_freelancer.id,
                    func.lower(func.coalesce(FreelancerInstallationTracking.app_type, ""))
                    == "vendor",
                    FreelancerInstallationTracking.referral_code.in_(referral_codes),
                    FreelancerInstallationTracking.activation_date.is_(None),
                )
            )
        )
        pending_registration_count = int(pending_result.scalar() or 0)

    all_referral_ids = select(FreelancerReferralLink.id).where(
        FreelancerReferralLink.freelancer_id == current_freelancer.id,
    )
    vendor_referral_ids = select(FreelancerReferralLink.id).where(
        FreelancerReferralLink.freelancer_id == current_freelancer.id,
        FreelancerReferralLink.referral_type == "vendor",
    )
    service_referral_ids = select(FreelancerReferralLink.id).where(
        FreelancerReferralLink.freelancer_id == current_freelancer.id,
        FreelancerReferralLink.referral_type == "service",
    )
    click_total_result = await db.execute(
        select(func.count(FreelancerReferralClickEvent.id)).where(
            FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
            FreelancerReferralClickEvent.referral_id.in_(all_referral_ids),
        )
    )
    unique_visitor_result = await db.execute(
        select(func.count(func.distinct(FreelancerReferralClickEvent.visitor_id))).where(
            FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
            FreelancerReferralClickEvent.referral_id.in_(all_referral_ids),
        )
    )
    click_total = int(click_total_result.scalar() or 0)
    unique_visitors = int(unique_visitor_result.scalar() or 0)
    play_store_click_count = int((await db.scalar(
        select(func.count(FreelancerReferralClickEvent.id)).where(
            FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
            FreelancerReferralClickEvent.referral_id.in_(vendor_referral_ids),
            FreelancerReferralClickEvent.destination_type == "PLAY_STORE",
        )
    )) or 0)
    unique_play_store_visitors = int((await db.scalar(
        select(func.count(func.distinct(FreelancerReferralClickEvent.visitor_id))).where(
            FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
            FreelancerReferralClickEvent.referral_id.in_(vendor_referral_ids),
            FreelancerReferralClickEvent.destination_type == "PLAY_STORE",
        )
    )) or 0)
    service_click_count = int((await db.scalar(
        select(func.count(FreelancerReferralClickEvent.id)).where(
            FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
            FreelancerReferralClickEvent.referral_id.in_(service_referral_ids),
            FreelancerReferralClickEvent.destination_type == "SERVICE",
        )
    )) or 0)
    unique_service_visitors = int((await db.scalar(
        select(func.count(func.distinct(FreelancerReferralClickEvent.visitor_id))).where(
            FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
            FreelancerReferralClickEvent.referral_id.in_(service_referral_ids),
            FreelancerReferralClickEvent.destination_type == "SERVICE",
        )
    )) or 0)
    referral_attribution_ids = select(VendorReferralAttribution.id).where(
        VendorReferralAttribution.freelancer_id == current_freelancer.id
    )
    successful_login_events = int((await db.scalar(
        select(func.count(VendorLoginEvent.id)).where(
            VendorLoginEvent.referral_attribution_id.in_(referral_attribution_ids),
            VendorLoginEvent.login_result == "success",
        )
    )) or 0)
    first_successful_logins = int((await db.scalar(
        select(func.count(VendorLoginEvent.id)).where(
            VendorLoginEvent.referral_attribution_id.in_(referral_attribution_ids),
            VendorLoginEvent.login_result == "success",
            VendorLoginEvent.is_first_login.is_(True),
        )
    )) or 0)
    registered_install_count = int((await db.scalar(
        select(func.count(func.distinct(VendorReferralAttribution.installation_tracking_id))).where(
            VendorReferralAttribution.freelancer_id == current_freelancer.id,
            VendorReferralAttribution.registration_status == "success",
            VendorReferralAttribution.installation_tracking_id.is_not(None),
        )
    )) or 0)
    post_registration_login_count = int((await db.scalar(
        select(func.count(func.distinct(VendorReferralAttribution.id)))
        .join(
            VendorLoginEvent,
            VendorLoginEvent.referral_attribution_id == VendorReferralAttribution.id,
        )
        .where(
            VendorReferralAttribution.freelancer_id == current_freelancer.id,
            VendorLoginEvent.login_result == "success",
            VendorLoginEvent.login_at >= VendorReferralAttribution.attributed_at,
        )
    )) or 0)
    registration_count = int(vendor_count_result.scalar() or 0)

    return ApiResponse(
        success=True,
        message="Vendor referral dashboard retrieved successfully",
        data=VendorReferralDashboardResponse(
            freelancer_name=current_freelancer.full_name,
            total_invitations=len(referral_codes),
            total_referral_link_clicks=click_total,
            unique_link_opens=unique_visitors,
            play_store_clicks=play_store_click_count,
            app_installs=install_count,
            vendor_registrations=registration_count,
            active_vendors=int(active_vendor_count_result.scalar() or 0),
            service_referral_clicks=service_click_count,
            unique_play_store_visitors=unique_play_store_visitors,
            unique_service_visitors=unique_service_visitors,
            successful_vendor_login_events=successful_login_events,
            first_successful_vendor_logins=first_successful_logins,
            click_to_install_rate_percent=(
                round(100 * install_count / play_store_click_count, 2)
                if play_store_click_count else None
            ),
            install_to_registration_rate_percent=(
                round(100 * registered_install_count / install_count, 2)
                if install_count else None
            ),
            registration_to_first_login_rate_percent=(
                round(100 * post_registration_login_count / registration_count, 2)
                if registration_count else None
            ),
            pending_registrations=pending_registration_count,
            as_of_date=datetime.now(timezone.utc).isoformat(),
        ),
    )


@router.post(
    "/referrals/vendor/install",
    response_model=ApiResponse[VendorInstallTrackingResponse],
)
async def track_vendor_referral_install(
    request: VendorInstallTrackingRequest,
    db: AsyncSession = Depends(get_db),
):
    """Record Install Referrer attribution only for a stored Vendor click."""
    code = request.referral_code.strip()
    result = await db.execute(
        select(FreelancerReferralLink).where(
            FreelancerReferralLink.referral_code == code,
            FreelancerReferralLink.referral_type == "vendor",
        )
    )
    referral = result.scalar_one_or_none()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if referral is None or referral.status != "active" or referral.expires_at <= now:
        raise HTTPException(status_code=404, detail="Vendor referral is invalid or expired")

    click_result = await db.execute(
        select(FreelancerReferralClickEvent).where(
            FreelancerReferralClickEvent.event_id == request.click_id,
            FreelancerReferralClickEvent.referral_id == referral.id,
            FreelancerReferralClickEvent.freelancer_id == referral.freelancer_id,
            FreelancerReferralClickEvent.destination_type == "PLAY_STORE",
            FreelancerReferralClickEvent.redirect_status == "redirected",
        )
    )
    click_event = click_result.scalar_one_or_none()
    if click_event is None:
        raise HTTPException(
            status_code=404,
            detail="Install Referrer click does not match a recorded Vendor Play Store click",
        )
    click_at = click_event.clicked_at
    if click_at.tzinfo is not None:
        click_at = click_at.astimezone(timezone.utc).replace(tzinfo=None)
    if (
        click_at > now
        or click_at < referral.created_at
        or click_at > referral.expires_at
        or click_event.destination_url
        != "https://play.google.com/store/apps/details?id=com.am5royal.am5royal"
    ):
        raise HTTPException(status_code=409, detail="Vendor click is outside the attribution window")
    if request.referrer_click_timestamp_seconds is not None:
        reported_click_at = datetime.fromtimestamp(
            request.referrer_click_timestamp_seconds, tz=timezone.utc
        ).replace(tzinfo=None)
        if abs((reported_click_at - click_at).total_seconds()) > 24 * 60 * 60:
            raise HTTPException(status_code=409, detail="Install Referrer click timestamp does not match the stored click")
    install_at = now
    if request.install_begin_timestamp_seconds is not None:
        install_at = datetime.fromtimestamp(
            request.install_begin_timestamp_seconds, tz=timezone.utc
        ).replace(tzinfo=None)
        if (
            install_at < click_at - timedelta(minutes=5)
            or install_at > datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(minutes=5)
        ):
            raise HTTPException(
                status_code=422,
                detail="Install Referrer install timestamp is outside the valid range",
            )

    existing_result = await db.execute(
        select(FreelancerInstallationTracking).where(
            FreelancerInstallationTracking.tracking_id == request.click_id
        )
    )
    existing = existing_result.scalar_one_or_none()
    if existing is not None:
        if (
            existing.referral_code != code
            or existing.freelancer_id != referral.freelancer_id
            or (existing.app_type or "").lower() != "vendor"
        ):
            raise HTTPException(status_code=409, detail="Install Referrer click is already attributed")
        return ApiResponse(
            success=True,
            message="Vendor install was already recorded",
            data=VendorInstallTrackingResponse(
                accepted=True, duplicate=True, tracking_id=request.click_id
            ),
        )

    db.add(FreelancerInstallationTracking(
        freelancer_id=referral.freelancer_id,
        tracking_id=request.click_id,
        referral_code=code,
        app_type="vendor",
        install_date=install_at,
    ))
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        duplicate_result = await db.execute(
            select(FreelancerInstallationTracking).where(
                FreelancerInstallationTracking.tracking_id == request.click_id
            )
        )
        duplicate = duplicate_result.scalar_one_or_none()
        if (
            duplicate is None
            or duplicate.referral_code != code
            or duplicate.freelancer_id != referral.freelancer_id
            or (duplicate.app_type or "").lower() != "vendor"
        ):
            raise HTTPException(status_code=409, detail="Install Referrer click is already attributed")
        return ApiResponse(
            success=True,
            message="Vendor install was already recorded",
            data=VendorInstallTrackingResponse(
                accepted=True, duplicate=True, tracking_id=request.click_id
            ),
        )

    return ApiResponse(
        success=True,
        message="Vendor install attributed successfully",
        data=VendorInstallTrackingResponse(
            accepted=True, duplicate=False, tracking_id=request.click_id
        ),
    )

@router.post("/referrals/links", response_model=ApiResponse[ReferralLinkItemResponse], status_code=status.HTTP_201_CREATED)
async def generate_referral_link(
    req: GenerateReferralLinkRequest,
    response: Response,
    current_freelancer: Freelancer = Depends(get_current_freelancer),
    db: AsyncSession = Depends(get_db),
):
    """Generate a shareable referral link for Customer, Vendor, or a Sub-service (7 or 15 days validity)."""
    try:
        link, reused_existing = await FreelanceService.generate_referral_link(
            db=db,
            freelancer=current_freelancer,
            referral_type=req.referral_type,
            validity_days=req.validity_days,
            target_sub_service_id=req.target_sub_service_id,
            target_service_url=req.target_service_url,
        )
        response.status_code = (
            status.HTTP_200_OK if reused_existing else status.HTTP_201_CREATED
        )
        return ApiResponse(
            success=True,
            message=(
                "Existing active referral link returned"
                if reused_existing
                else "Referral link generated successfully"
            ),
            data=ReferralLinkItemResponse(
                referral_id=f"ref_{link.id}",
                referral_code=link.referral_code,
                referral_type=link.referral_type,
                target_service_category_id=link.target_service_category_id,
                target_service_id=link.target_sub_service_id,
                target_service_name=link.target_sub_service_name,
                url=_referral_response_url(link),
                created_at=link.created_at.isoformat() + "Z",
                expires_at=link.expires_at.isoformat() + "Z",
                status=link.status,
                validity_days=link.validity_days,
                reused_existing=reused_existing,
                clicks_count=link.clicks_count,
                conversions_count=link.conversions_count
            )
        )
    except ActiveServiceReferralConflict as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )
    except ActiveVendorReferralConflict as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to generate link: {str(e)}")


@router.get("/referrals/validate/{code}", response_model=ApiResponse[ReferralValidationResponse])
async def validate_referral_link(code: str, db: AsyncSession = Depends(get_db)):
    """Check whether a referral link or code is valid when opened or used."""
    result = await FreelanceService.validate_referral_code(db, code)
    if not result.get("valid"):
        return ApiResponse(
            success=False,
            message=f"Referral code is {result.get('status', 'invalid')}",
            data=ReferralValidationResponse(
                valid=False,
                status=result.get("status", "invalid"),
                referral_type=result.get("referral_type"),
                expires_at=result.get("expires_at"),
            )
        )

    return ApiResponse(
        success=True,
        message="Referral link is active and valid",
        data=ReferralValidationResponse(
            valid=True,
            status=result["status"],
            referral_id=result.get("referral_id"),
            referral_type=result["referral_type"],
            target_service=result.get("target_service"),
            expires_at=result.get("expires_at"),
            referrer_name=result.get("referrer_name")
        )
    )


@router.get("/referrals/links", response_model=ApiResponse[PaginatedData[ReferralLinkItemResponse]])
async def list_referral_links(
    type_filter: Optional[str] = Query(None, alias="type", description="customer, vendor, service"),
    status_filter: Optional[str] = Query(None, alias="status", description="active, expired, revoked"),
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    current_freelancer: Freelancer = Depends(get_current_freelancer),
    db: AsyncSession = Depends(get_db)
):
    """List the authenticated freelancer's previously generated links."""
    conditions = [FreelancerReferralLink.freelancer_id == current_freelancer.id]

    if type_filter and type_filter.lower() != "all":
        conditions.append(FreelancerReferralLink.referral_type == type_filter.lower().strip())

    if status_filter and status_filter.lower() != "all":
        conditions.append(FreelancerReferralLink.status == status_filter.lower().strip())

    count_stmt = select(func.count(FreelancerReferralLink.id)).where(and_(*conditions))
    total_res = await db.execute(count_stmt)
    total = total_res.scalar() or 0

    stmt = (
        select(FreelancerReferralLink)
        .where(and_(*conditions))
        .order_by(desc(FreelancerReferralLink.created_at))
        .offset((page - 1) * limit)
        .limit(limit)
    )
    res = await db.execute(stmt)
    links = res.scalars().all()

    click_counts = {}
    conversion_counts = {}
    link_ids = [link.id for link in links]
    if link_ids:
        click_count_result = await db.execute(
            select(
                FreelancerReferralClickEvent.referral_id,
                func.count(FreelancerReferralClickEvent.id),
            )
            .where(
                FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
                FreelancerReferralClickEvent.referral_id.in_(link_ids),
            )
            .group_by(FreelancerReferralClickEvent.referral_id)
        )
        click_counts = {
            referral_id: int(count)
            for referral_id, count in click_count_result.all()
        }
        conversion_result = await db.execute(
            select(
                VendorReferralAttribution.referral_link_id,
                func.count(func.distinct(VendorReferralAttribution.vendor_id)),
            )
            .where(
                VendorReferralAttribution.freelancer_id == current_freelancer.id,
                VendorReferralAttribution.referral_link_id.in_(link_ids),
            )
            .group_by(VendorReferralAttribution.referral_link_id)
        )
        conversion_counts = {
            referral_id: int(count)
            for referral_id, count in conversion_result.all()
        }

    items = [
        ReferralLinkItemResponse(
            referral_id=f"ref_{l.id}",
            referral_code=l.referral_code,
            referral_type=l.referral_type,
            target_service_category_id=l.target_service_category_id,
            target_service_id=l.target_sub_service_id,
            target_service_name=l.target_sub_service_name,
            url=_referral_response_url(l),
            created_at=l.created_at.isoformat() + "Z",
            expires_at=l.expires_at.isoformat() + "Z",
            status=l.status,
            validity_days=l.validity_days,
            clicks_count=click_counts.get(l.id, 0),
            conversions_count=conversion_counts.get(l.id, 0),
        )
        for l in links
    ]

    return ApiResponse(
        success=True,
        message="Referral links retrieved successfully",
        data=PaginatedData(
            items=items,
            page=page,
            limit=limit,
            total=total,
            hasMore=(page * limit) < total
        )
    )


@router.get("/referrals/links/{referral_id}/events")
async def get_referral_event_history(
    referral_id: int,
    current_freelancer: Freelancer = Depends(get_current_freelancer),
    db: AsyncSession = Depends(get_db),
):
    """Return a privacy-safe event timeline for one owned referral link."""
    link = (await db.execute(
        select(FreelancerReferralLink).where(
            FreelancerReferralLink.id == referral_id,
            FreelancerReferralLink.freelancer_id == current_freelancer.id,
        )
    )).scalar_one_or_none()
    if link is None:
        raise HTTPException(status_code=404, detail="Referral link not found")

    events = [{
        "event_type": "link_created",
        "occurred_at": link.created_at.isoformat() + "Z",
    }]
    click_rows = (await db.execute(
        select(
            FreelancerReferralClickEvent.clicked_at,
            FreelancerReferralClickEvent.destination_type,
            FreelancerReferralClickEvent.redirect_status,
        ).where(FreelancerReferralClickEvent.referral_id == link.id)
    )).all()
    for row in click_rows:
        events.append({
            "event_type": "link_opened",
            "occurred_at": row.clicked_at.isoformat(),
            "destination_type": row.destination_type,
            "redirect_status": row.redirect_status,
        })

    action_rows = (await db.execute(
        select(
            FreelancerReferralActionEvent.event_type,
            FreelancerReferralActionEvent.platform,
            FreelancerReferralActionEvent.occurred_at,
        ).where(FreelancerReferralActionEvent.referral_id == link.id)
    )).all()
    for row in action_rows:
        events.append({
            "event_type": row.event_type,
            "occurred_at": row.occurred_at.isoformat(),
            "platform": row.platform,
        })

    attribution_rows = (await db.execute(
        select(
            VendorReferralAttribution.id,
            VendorReferralAttribution.attributed_at,
        ).where(VendorReferralAttribution.referral_link_id == link.id)
    )).all()
    attribution_ids = [row.id for row in attribution_rows]
    for row in attribution_rows:
        events.append({
            "event_type": "registration_success",
            "occurred_at": row.attributed_at.isoformat(),
        })
    if attribution_ids:
        login_rows = (await db.execute(
            select(
                VendorLoginEvent.login_at,
                VendorLoginEvent.is_first_login,
            ).where(
                VendorLoginEvent.referral_attribution_id.in_(attribution_ids),
                VendorLoginEvent.login_result == "success",
            )
        )).all()
        for row in login_rows:
            events.append({
                "event_type": "first_login" if row.is_first_login else "subsequent_login",
                "occurred_at": row.login_at.isoformat(),
            })

    events.sort(key=lambda item: item["occurred_at"])
    return ApiResponse(
        success=True,
        message="Referral event history loaded",
        data={"referral_id": f"ref_{link.id}", "events": events},
    )


@router.post("/referrals/links/{referral_id}/events")
async def record_referral_action_event(
    referral_id: int,
    request: ReferralActionEventRequest,
    current_freelancer: Freelancer = Depends(get_current_freelancer),
    db: AsyncSession = Depends(get_db),
):
    """Record an authenticated copy or share-sheet action for an owned link."""
    link = (await db.execute(
        select(FreelancerReferralLink).where(
            FreelancerReferralLink.id == referral_id,
            FreelancerReferralLink.freelancer_id == current_freelancer.id,
        )
    )).scalar_one_or_none()
    if link is None:
        raise HTTPException(status_code=404, detail="Referral link not found")

    existing = (await db.execute(
        select(FreelancerReferralActionEvent).where(
            FreelancerReferralActionEvent.event_id == request.event_id,
        )
    )).scalar_one_or_none()
    if existing is not None:
        if (
            existing.referral_id != link.id
            or existing.freelancer_id != current_freelancer.id
            or existing.event_type != request.event_type
        ):
            raise HTTPException(status_code=409, detail="Event ID was already used")
        return ApiResponse(
            success=True,
            message="Referral action already recorded",
            data={"accepted": True, "duplicate": True},
        )

    db.add(FreelancerReferralActionEvent(
        event_id=request.event_id,
        referral_id=link.id,
        freelancer_id=current_freelancer.id,
        event_type=request.event_type,
        platform=request.platform,
    ))
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        existing = (await db.execute(
            select(FreelancerReferralActionEvent).where(
                FreelancerReferralActionEvent.event_id == request.event_id,
            )
        )).scalar_one_or_none()
        if existing is None or existing.referral_id != link.id or existing.event_type != request.event_type:
            raise HTTPException(status_code=409, detail="Event ID was already used") from None
        return ApiResponse(
            success=True,
            message="Referral action already recorded",
            data={"accepted": True, "duplicate": True},
        )

    return ApiResponse(
        success=True,
        message="Referral action recorded",
        data={"accepted": True, "duplicate": False},
    )


@router.get("/referrals/services/dashboard")
async def get_service_referral_dashboard(
    current_freelancer: Freelancer = Depends(get_current_freelancer),
    db: AsyncSession = Depends(get_db),
):
    """Return database-backed Home Services performance for this Freelancer."""
    from app.models.catalog import ServiceSubcategory

    service_rows = (await db.execute(
        select(ServiceSubcategory.id, ServiceSubcategory.name)
        .where(
            ServiceSubcategory.main_category_id == 37,
            ServiceSubcategory.is_active.is_(True),
        )
        .order_by(ServiceSubcategory.sort_order, ServiceSubcategory.id)
    )).all()
    service_ids = [int(row.id) for row in service_rows]
    by_service = {
        service_id: {
            "service_id": service_id,
            "service_name": name,
            "total_links": 0,
            "active_links": 0,
            "expired_links": 0,
            "revoked_links": 0,
            "seven_day_links": 0,
            "fifteen_day_links": 0,
            "clicks": 0,
            "unique_visitors": 0,
            "registrations": 0,
            "first_logins": 0,
            "subsequent_logins": 0,
            "copy_actions": 0,
            "share_actions": 0,
        }
        for service_id, name in service_rows
    }
    if not service_ids:
        return ApiResponse(success=True, message="Service referral report loaded", data={
            "summary": {}, "services": [], "daily": [], "monthly": [],
            "as_of": datetime.now(timezone.utc).isoformat(),
        })

    now = datetime.now(timezone.utc)
    now_naive = now.replace(tzinfo=None)
    links = (await db.execute(
        select(
            FreelancerReferralLink.target_sub_service_id,
            FreelancerReferralLink.validity_days,
            FreelancerReferralLink.status,
            FreelancerReferralLink.expires_at,
        ).where(
            FreelancerReferralLink.freelancer_id == current_freelancer.id,
            FreelancerReferralLink.referral_type == "service",
            FreelancerReferralLink.target_sub_service_id.in_(service_ids),
        )
    )).all()
    for link in links:
        item = by_service.get(int(link.target_sub_service_id))
        if item is None:
            continue
        item["total_links"] += 1
        if link.validity_days == 7:
            item["seven_day_links"] += 1
        elif link.validity_days == 15:
            item["fifteen_day_links"] += 1
        expiry = link.expires_at
        if expiry is not None and expiry.tzinfo is not None:
            expiry = expiry.astimezone(timezone.utc).replace(tzinfo=None)
        status_value = (link.status or "").lower()
        if status_value == "revoked":
            item["revoked_links"] += 1
        elif status_value == "expired" or expiry is None or expiry <= now_naive:
            item["expired_links"] += 1
        elif status_value == "active":
            item["active_links"] += 1

    clicks = (await db.execute(
        select(
            FreelancerReferralClickEvent.service_id,
            func.count(FreelancerReferralClickEvent.id),
            func.count(func.distinct(FreelancerReferralClickEvent.visitor_id)),
        ).where(
            FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
            FreelancerReferralClickEvent.destination_type == "SERVICE",
            FreelancerReferralClickEvent.service_id.in_(service_ids),
        ).group_by(FreelancerReferralClickEvent.service_id)
    )).all()
    for service_id, count, unique_visitors in clicks:
        item = by_service.get(int(service_id))
        if item is not None:
            item["clicks"] = int(count)
            item["unique_visitors"] = int(unique_visitors)

    registrations = (await db.execute(
        select(
            VendorReferralAttribution.service_id,
            func.count(func.distinct(VendorReferralAttribution.vendor_id)),
        ).where(
            VendorReferralAttribution.freelancer_id == current_freelancer.id,
            VendorReferralAttribution.service_id.in_(service_ids),
        ).group_by(VendorReferralAttribution.service_id)
    )).all()
    for service_id, count in registrations:
        item = by_service.get(int(service_id))
        if item is not None:
            item["registrations"] = int(count)

    actions = (await db.execute(
        select(
            FreelancerReferralLink.target_sub_service_id,
            FreelancerReferralActionEvent.event_type,
            func.count(FreelancerReferralActionEvent.id),
        ).join(
            FreelancerReferralActionEvent,
            FreelancerReferralActionEvent.referral_id == FreelancerReferralLink.id,
        ).where(
            FreelancerReferralLink.freelancer_id == current_freelancer.id,
            FreelancerReferralLink.referral_type == "service",
            FreelancerReferralLink.target_sub_service_id.in_(service_ids),
        ).group_by(
            FreelancerReferralLink.target_sub_service_id,
            FreelancerReferralActionEvent.event_type,
        )
    )).all()
    for service_id, event_type, count in actions:
        item = by_service.get(int(service_id))
        if item is None:
            continue
        item["copy_actions" if event_type == "copy" else "share_actions"] = int(count)

    logins = (await db.execute(
        select(
            VendorReferralAttribution.service_id,
            func.sum(case((VendorLoginEvent.is_first_login.is_(True), 1), else_=0)),
            func.sum(case((VendorLoginEvent.is_first_login.is_(False), 1), else_=0)),
        ).join(
            VendorLoginEvent,
            VendorLoginEvent.referral_attribution_id == VendorReferralAttribution.id,
        ).where(
            VendorReferralAttribution.freelancer_id == current_freelancer.id,
            VendorReferralAttribution.service_id.in_(service_ids),
            VendorLoginEvent.login_result == "success",
        ).group_by(VendorReferralAttribution.service_id)
    )).all()
    for service_id, first_count, subsequent_count in logins:
        item = by_service.get(int(service_id))
        if item is not None:
            item["first_logins"] = int(first_count or 0)
            item["subsequent_logins"] = int(subsequent_count or 0)

    daily_counts = {}

    def add_daily_rows(rows, event_name):
        for event_date, count in rows:
            day = str(event_date)[:10]
            record = daily_counts.setdefault(day, {
                "date": day, "links_created": 0, "clicks": 0,
                "registrations": 0, "first_logins": 0,
                "subsequent_logins": 0,
            })
            record[event_name] += int(count or 0)

    add_daily_rows((await db.execute(
        select(func.date(FreelancerReferralLink.created_at), func.count())
        .where(
            FreelancerReferralLink.freelancer_id == current_freelancer.id,
            FreelancerReferralLink.referral_type == "service",
            FreelancerReferralLink.target_sub_service_id.in_(service_ids),
        )
        .group_by(func.date(FreelancerReferralLink.created_at))
    )).all(), "links_created")
    add_daily_rows((await db.execute(
        select(func.date(FreelancerReferralClickEvent.clicked_at), func.count())
        .where(
            FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
            FreelancerReferralClickEvent.destination_type == "SERVICE",
            FreelancerReferralClickEvent.service_id.in_(service_ids),
        )
        .group_by(func.date(FreelancerReferralClickEvent.clicked_at))
    )).all(), "clicks")
    add_daily_rows((await db.execute(
        select(func.date(VendorReferralAttribution.attributed_at), func.count())
        .where(
            VendorReferralAttribution.freelancer_id == current_freelancer.id,
            VendorReferralAttribution.service_id.in_(service_ids),
        )
        .group_by(func.date(VendorReferralAttribution.attributed_at))
    )).all(), "registrations")
    add_daily_rows((await db.execute(
        select(func.date(VendorLoginEvent.login_at), func.count())
        .join(
            VendorReferralAttribution,
            VendorLoginEvent.referral_attribution_id == VendorReferralAttribution.id,
        )
        .where(
            VendorReferralAttribution.freelancer_id == current_freelancer.id,
            VendorReferralAttribution.service_id.in_(service_ids),
            VendorLoginEvent.login_result == "success",
            VendorLoginEvent.is_first_login.is_(True),
        )
        .group_by(func.date(VendorLoginEvent.login_at))
    )).all(), "first_logins")
    add_daily_rows((await db.execute(
        select(func.date(VendorLoginEvent.login_at), func.count())
        .join(
            VendorReferralAttribution,
            VendorLoginEvent.referral_attribution_id == VendorReferralAttribution.id,
        )
        .where(
            VendorReferralAttribution.freelancer_id == current_freelancer.id,
            VendorReferralAttribution.service_id.in_(service_ids),
            VendorLoginEvent.login_result == "success",
            VendorLoginEvent.is_first_login.is_(False),
        )
        .group_by(func.date(VendorLoginEvent.login_at))
    )).all(), "subsequent_logins")

    monthly_counts = {}
    for day, daily in daily_counts.items():
        month = day[:7]
        record = monthly_counts.setdefault(month, {
            "month": month, "links_created": 0, "clicks": 0,
            "registrations": 0, "first_logins": 0,
            "subsequent_logins": 0,
        })
        for key in (
            "links_created", "clicks", "registrations",
            "first_logins", "subsequent_logins",
        ):
            record[key] += daily[key]

    services = list(by_service.values())
    totals = {
        key: sum(item[key] for item in services)
        for key in (
            "total_links", "active_links", "expired_links", "revoked_links",
            "seven_day_links", "fifteen_day_links", "clicks", "registrations",
            "first_logins", "subsequent_logins", "copy_actions", "share_actions",
        )
    }
    totals["unique_visitors"] = int((await db.scalar(
        select(func.count(func.distinct(FreelancerReferralClickEvent.visitor_id))).where(
            FreelancerReferralClickEvent.freelancer_id == current_freelancer.id,
            FreelancerReferralClickEvent.destination_type == "SERVICE",
            FreelancerReferralClickEvent.service_id.in_(service_ids),
        )
    )) or 0)
    return ApiResponse(
        success=True,
        message="Service referral report loaded",
        data={
            "summary": totals,
            "services": services,
            "daily": [daily_counts[key] for key in sorted(daily_counts)],
            "monthly": [monthly_counts[key] for key in sorted(monthly_counts)],
            "as_of": now.isoformat(),
        },
    )


@router.get("/referrals/rewards/summary", response_model=ApiResponse[ReferralRewardsSummaryResponse])
async def get_referral_rewards_summary(
    current_freelancer: Freelancer = Depends(get_current_freelancer),
    db: AsyncSession = Depends(get_db)
):
    """Show total referral points and point balance summary."""
    total_pts = current_freelancer.total_points or 0
    # Pending points from uncompleted activations or bookings
    stmt_pending = select(func.coalesce(func.sum(FreelancerReferralReward.points), 0)).where(
        and_(
            FreelancerReferralReward.freelancer_id == current_freelancer.id,
            FreelancerReferralReward.status == "pending"
        )
    )
    res_pen = await db.execute(stmt_pending)
    pending_pts = int(res_pen.scalar() or 0)

    # 1 point = ₹1
    currency_equiv = float(total_pts * 1.0)

    return ApiResponse(
        success=True,
        message="Referral rewards summary retrieved successfully",
        data=ReferralRewardsSummaryResponse(
            total_points=total_pts,
            available_points=total_pts,
            pending_points=pending_pts,
            redeemed_points=0,
            currency_equivalent=currency_equiv
        )
    )


@router.get("/referrals/level-progress", response_model=ApiResponse[ReferralLevelProgressResponse])
async def get_level_progress(current_freelancer: Freelancer = Depends(get_current_freelancer)):
    """Show current level, next level and progress to next level."""
    prog = await FreelanceService.get_level_progress(current_freelancer)
    return ApiResponse(
        success=True,
        message="Level and progress retrieved successfully",
        data=ReferralLevelProgressResponse(**prog)
    )


@router.get("/referrals/points/history", response_model=ApiResponse[PaginatedData[ReferralPointHistoryItem]])
async def get_points_history(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    status_filter: Optional[str] = Query(None, alias="status"),
    current_freelancer: Freelancer = Depends(get_current_freelancer),
    db: AsyncSession = Depends(get_db)
):
    """Show when and why referral points were earned or adjusted."""
    conditions = [FreelancerReferralReward.freelancer_id == current_freelancer.id]
    if status_filter and status_filter.lower() != "all":
        conditions.append(FreelancerReferralReward.status == status_filter.lower().strip())

    count_stmt = select(func.count(FreelancerReferralReward.id)).where(and_(*conditions))
    total_res = await db.execute(count_stmt)
    total = total_res.scalar() or 0

    stmt = (
        select(FreelancerReferralReward)
        .where(and_(*conditions))
        .order_by(desc(FreelancerReferralReward.created_at))
        .offset((page - 1) * limit)
        .limit(limit)
    )
    res = await db.execute(stmt)
    rewards = res.scalars().all()

    items = [
        ReferralPointHistoryItem(
            transaction_id=f"TXN_{r.id}",
            event_description=r.description,
            points=r.points,
            amount=float(r.amount) if r.amount else None,
            status=r.status,
            created_at=r.created_at.isoformat() + "Z",
            reference_id=r.reference_id
        )
        for r in rewards
    ]

    return ApiResponse(
        success=True,
        message="Points history retrieved successfully",
        data=PaginatedData(
            items=items,
            page=page,
            limit=limit,
            total=total,
            hasMore=(page * limit) < total
        )
    )


@router.get("/referrals/rules", response_model=ApiResponse[ReferralRulesResponse])
async def get_referral_rules():
    """Fetch admin-configured referral program rules, point values and guidelines."""
    rules = [
        ReferralRuleItem(
            tier="Bronze (0-250 Points)",
            criteria="New partners & starter level",
            points_per_referral=50,
            cash_value=50.0,
            description="Earn 50 points per customer signup who books their first service."
        ),
        ReferralRuleItem(
            tier="Silver (251-1000 Points)",
            criteria="5+ active customer or vendor conversions",
            points_per_referral=75,
            cash_value=75.0,
            description="Earn 75 points per referral + 5% recurring booking commission."
        ),
        ReferralRuleItem(
            tier="Gold (1001-3000 Points)",
            criteria="15+ active customer or vendor conversions",
            points_per_referral=100,
            cash_value=100.0,
            description="Earn 100 points per referral + 7.5% recurring commission + ₹1000 milestone bonus."
        ),
        ReferralRuleItem(
            tier="Platinum (3001+ Points)",
            criteria="30+ conversions with 30-day retention",
            points_per_referral=150,
            cash_value=150.0,
            description="Top VIP tier: 150 points per referral + 10% commission + executive support."
        ),
    ]
    guidelines = [
        "Referral links expire in 7 or 15 days as selected during creation.",
        "Expired links do not qualify for referral credit.",
        "Points are credited once the referred customer completes their first verified order.",
        "Vendor referrals require completed KYC and active profile status.",
        "Self-referral or fraudulent device manipulation results in immediate account disqualification."
    ]

    return ApiResponse(
        success=True,
        message="Referral rules retrieved successfully",
        data=ReferralRulesResponse(
            rules=rules,
            guidelines=guidelines,
            retention_period_days=30
        )
    )

