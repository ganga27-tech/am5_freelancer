from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.models.freelancer import Freelancer
from freelance_api.dependencies import get_current_freelancer
from freelance_api.schemas import (
    ApiResponse,
    LoginRequest,
    RegisterRequest,
    ForgotPasswordRequest,
    VerifyOtpRequest,
    ResetPasswordRequest,
    ChangePasswordRequest,
    AuthTokenResponse,
    RegistrationResponse,
    ChallengeResponse,
    OtpVerificationResponse,
)
from freelance_api.service import FreelanceService
from app.core.rate_limit import limiter
from app.services.otp_service import (
    OTPDeliveryUnavailable,
    OTPRecoveryRateLimited,
    OTPStoreUnavailable,
)
from app.core.config import settings
import logging

router = APIRouter(tags=["Freelancer Authentication"])
logger = logging.getLogger(__name__)

@router.post("/login", response_model=ApiResponse[AuthTokenResponse])
@limiter.limit("10/minute")
async def login(req: LoginRequest, request: Request, db: AsyncSession = Depends(get_db)):
    """Allow login using registered mobile number OR email and password."""
    try:
        freelancer, token = await FreelanceService.login(db, req.identifier, req.password)
        return ApiResponse(
            success=True,
            message="Login successful",
            data=AuthTokenResponse(
                access_token=token,
                token_type="bearer",
                expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                user={
                    "user_id": freelancer.id,
                    "full_name": freelancer.full_name,
                    "mobile": freelancer.phone_number,
                    "email": freelancer.email,
                    "profile_status": freelancer.profile_status or "active"
                }
            )
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))
    except (RuntimeError, OTPStoreUnavailable):
        raise HTTPException(status_code=503, detail="Authentication is temporarily unavailable") from None
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="An error occurred during login") from None


@router.post("/register", response_model=ApiResponse[RegistrationResponse], status_code=status.HTTP_201_CREATED)
@limiter.limit("5/hour")
async def register(req: RegisterRequest, request: Request, db: AsyncSession = Depends(get_db)):
    """Register a new freelancer account."""
    try:
        freelancer = await FreelanceService.register(
            db=db,
            full_name=req.full_name,
            mobile_number=req.mobile_number,
            email=req.email,
            password=req.password
        )
        return ApiResponse(
            success=True,
            message="Account registered successfully",
            data=RegistrationResponse(
                user_id=freelancer.id,
                registration_status="completed",
                verification_required=False,
                next_step="login"
            )
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as exc:
        logger.error("Freelancer registration failed (%s)", type(exc).__name__)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed. Please try again.",
        ) from None


@router.post(
    "/forgot-password",
    response_model=ApiResponse[ChallengeResponse],
    status_code=status.HTTP_202_ACCEPTED,
)
@limiter.limit("5/minute")
async def forgot_password(
    req: ForgotPasswordRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Return a generic response and deliver only to a stored account contact."""
    try:
        client_ip = request.client.host if request.client else "unknown"
        challenge_id, expiry = await FreelanceService.request_password_reset(
            db,
            req.identifier,
            req.preferred_channel,
            client_ip,
        )
        return ApiResponse(
            success=True,
            message="If an eligible account matches, a code will be sent to the selected contact.",
            data=ChallengeResponse(
                challenge_id=challenge_id,
                expiry_seconds=expiry,
                message="If eligible, use the code sent to the selected contact.",
            ),
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from None
    except OTPRecoveryRateLimited:
        raise HTTPException(
            status_code=429,
            detail="Please wait before requesting another code.",
        ) from None
    except (OTPDeliveryUnavailable, OTPStoreUnavailable):
        raise HTTPException(
            status_code=503,
            detail="Password recovery is temporarily unavailable.",
        ) from None
    except Exception:
        raise HTTPException(
            status_code=503,
            detail="Password recovery is temporarily unavailable.",
        ) from None


@router.post("/verify-otp", response_model=ApiResponse[OtpVerificationResponse])
@limiter.limit("10/minute")
async def verify_otp(req: VerifyOtpRequest, request: Request):
    """Verify registration or password-recovery OTP."""
    try:
        reset_token = await FreelanceService.verify_otp(req.challenge_id, req.otp, req.purpose)
        return ApiResponse(
            success=True,
            message="OTP verified successfully",
            data=OtpVerificationResponse(
                verified=True,
                reset_token=reset_token,
                message="Verification successful. You may now reset your password."
            )
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except OTPStoreUnavailable:
        raise HTTPException(status_code=503, detail="OTP verification is temporarily unavailable") from None


@router.post("/reset-password", response_model=ApiResponse[dict])
@limiter.limit("5/minute")
async def reset_password(req: ResetPasswordRequest, request: Request, db: AsyncSession = Depends(get_db)):
    """Set a new password after successful recovery verification."""
    try:
        await FreelanceService.reset_password(db, req.reset_token, req.new_password)
        return ApiResponse(
            success=True,
            message="Password reset successfully. You can now log in with your new password.",
            data={"status": "success"}
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except OTPStoreUnavailable:
        raise HTTPException(status_code=503, detail="Password reset is temporarily unavailable") from None


@router.post("/change-password", response_model=ApiResponse[dict])
@limiter.limit("5/minute")
async def change_password(
    req: ChangePasswordRequest,
    request: Request,
    current_freelancer: Freelancer = Depends(get_current_freelancer),
    db: AsyncSession = Depends(get_db)
):
    """Change password while logged in."""
    try:
        await FreelanceService.change_password(db, current_freelancer, req.current_password, req.new_password)
        return ApiResponse(
            success=True,
            message="Password updated successfully",
            data={"status": "success"}
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except OTPStoreUnavailable:
        raise HTTPException(status_code=503, detail="Password change is temporarily unavailable") from None

