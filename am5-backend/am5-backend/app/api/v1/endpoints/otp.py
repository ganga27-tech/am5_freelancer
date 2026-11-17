from fastapi import APIRouter, Query, HTTPException, Request, status
from app.core.rate_limit import limiter
from app.core.phone_numbers import normalize_indian_mobile
from app.services.otp_service import OTPStoreUnavailable, otp_service

router = APIRouter()

@router.get("/generateotp")
@limiter.limit("5/minute")
async def generate_otp(
    contactNumber: str = Query(..., description="Phone number to send OTP to"),
    requestedBy: str = Query("customer", description="Who is requesting the OTP"),
    request: Request = None,
):
    """
    Generate an OTP for login/registration (Matches PDF Page 4).
    """
    if not contactNumber:
        raise HTTPException(status_code=400, detail="Contact number is required")
    
    mobile = normalize_indian_mobile(contactNumber)
    if mobile is None:
        raise HTTPException(status_code=422, detail="Enter a valid Indian mobile number")
    try:
        otp = await otp_service.generate_otp(mobile)
        sent = await otp_service.send_otp_sms(mobile, otp)
        if not sent:
            await otp_service.delete_otp(mobile)
            raise HTTPException(status_code=503, detail="OTP delivery is temporarily unavailable")
    except OTPStoreUnavailable:
        raise HTTPException(status_code=503, detail="OTP service is temporarily unavailable") from None

    return {"message": "OTP accepted by the delivery provider"}

@router.post("/verify")
@limiter.limit("10/minute")
async def verify_otp(
    phone: str,
    otp: str,
    request: Request = None,
):
    """
    Verify the OTP provided by the user.
    """
    mobile = normalize_indian_mobile(phone)
    if mobile is None:
        raise HTTPException(status_code=422, detail="Enter a valid Indian mobile number")
    is_valid = await otp_service.verify_otp(mobile, otp)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP"
        )
    return {"message": "OTP verified successfully"}
