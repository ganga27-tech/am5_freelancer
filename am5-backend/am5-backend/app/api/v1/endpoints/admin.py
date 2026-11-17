from fastapi import APIRouter, Depends, HTTPException, status, Form, File, UploadFile, BackgroundTasks, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
import datetime
from typing import List, Optional

from app.db.session import get_db
from app.models.vendor import Vendor, VendorDocument, VendorReferralAttribution, VendorLoginEvent
from app.models.employee import Employee, WithdrawalRequest
from app.models.subscriptions import VendorSubscription, SubscriptionPlan
from app.models.catalog import Service, ServiceSubcategory
from app.models.freelancer import Freelancer
from freelance_api.models import FreelancerReferralLink, FreelancerReferralClickEvent, FreelancerInstallationTracking
from app.schemas.admin import (
    DashboardStatsResponse,
    VendorAdminListResponse,
    VendorStatusUpdateRequest,
    EmployeeStatusUpdateRequest,
    TopEmployee,
    CompanyLeadResponse,
    LeadAssignResult,
    CompanyLeadsPaginatedResponse
)
from app.schemas.employee import EmployeeResponse, EmployeeUpdateRequest
from app.schemas.vendor import VendorProfileResponse, VendorProfileUpdate
from app.schemas.catalog import ServiceResponse
from app.dependencies.auth import get_current_admin
from app.services.upload_service import upload_service

router = APIRouter()

@router.get("/stats", response_model=DashboardStatsResponse)
async def get_dashboard_stats(
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    # Total vendors
    total_vendors_query = select(func.count(Vendor.id))
    total_vendors_result = await db.execute(total_vendors_query)
    total_vendors = total_vendors_result.scalar() or 0
    
    # Pending vendors
    pending_vendors_query = select(func.count(Vendor.id)).where(Vendor.status == "pending")
    pending_vendors_result = await db.execute(pending_vendors_query)
    pending_vendors = pending_vendors_result.scalar() or 0
    
    # Total employees
    total_employees_query = select(func.count(Employee.id))
    total_employees_result = await db.execute(total_employees_query)
    total_employees = total_employees_result.scalar() or 0
    
    # Total referral points
    total_points_query = select(func.sum(Employee.referral_points))
    total_points_result = await db.execute(total_points_query)
    total_points = total_points_result.scalar() or 0
    
    # Top 5 employees
    top_employees_query = select(Employee).order_by(Employee.referral_points.desc()).limit(5)
    top_employees_result = await db.execute(top_employees_query)
    top_employees = top_employees_result.scalars().all()

    # Total Sales (Sum of plan prices of active subscriptions)
    total_sales_query = select(func.sum(SubscriptionPlan.price)).join(
        VendorSubscription, VendorSubscription.subscription_plan_id == SubscriptionPlan.id
    ).where(VendorSubscription.status == "active")
    total_sales_result = await db.execute(total_sales_query)
    total_sales = float(total_sales_result.scalar() or 0.0)
    
    # Calculate monthly vendor signups for the last 6 months
    now = datetime.datetime.now()
    monthly_growth = []
    for i in range(5, -1, -1):
        # Subtract months using a rough approximation (approx 30.4 days per month)
        target_date = now - datetime.timedelta(days=int(i * 30.4))
        start_of_month = datetime.datetime(target_date.year, target_date.month, 1)
        if target_date.month == 12:
            end_of_month = datetime.datetime(target_date.year + 1, 1, 1)
        else:
            end_of_month = datetime.datetime(target_date.year, target_date.month + 1, 1)
            
        month_query = select(func.count(Vendor.id)).where(
            Vendor.created_at >= start_of_month,
            Vendor.created_at < end_of_month
        )
        month_res = await db.execute(month_query)
        month_count = month_res.scalar() or 0
        month_name = target_date.strftime("%b")
        monthly_growth.append({"month": month_name, "count": month_count})

    return DashboardStatsResponse(
        total_vendors=total_vendors,
        pending_vendors=pending_vendors,
        total_employees=total_employees,
        total_referral_points_distributed=total_points,
        total_sales=total_sales,
        monthly_growth=monthly_growth,
        top_employees=[
            TopEmployee(
                id=emp.id,
                first_name=emp.first_name,
                last_name=emp.last_name,
                email=emp.email,
                role=emp.role,
                referral_points=emp.referral_points
            ) for emp in top_employees
        ]
    )

from sqlalchemy import select, func, or_
@router.get("/vendors", response_model=List[VendorAdminListResponse])
async def list_vendors(
    status_filter: str = None,
    search_query: str = None,
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    from app.models.user_location import User
    query = select(Vendor, Employee.first_name, Employee.last_name, User.mobile, User.email).outerjoin(
        Employee, Vendor.onboarded_by_employee_id == Employee.id
    ).outerjoin(
        User, Vendor.user_id == User.id
    )
    if status_filter:
        query = query.where(Vendor.status == status_filter)
        
    if search_query:
        query = query.where(
            or_(
                Vendor.business_name.ilike(f"%{search_query}%"),
                Vendor.first_name.ilike(f"%{search_query}%"),
                Vendor.last_name.ilike(f"%{search_query}%"),
                User.mobile.ilike(f"%{search_query}%")
            )
        )
    
    query = query.offset(skip).limit(limit)
    result = await db.execute(query)
    rows = result.all()
    
    vendors = [r[0] for r in rows]
    vendor_ids = [v.id for v in vendors]
    docs_uploaded = set()
    has_payment = set()

    if vendor_ids:
        docs_query = select(VendorDocument.vendor_id).where(VendorDocument.vendor_id.in_(vendor_ids))
        docs_res = await db.execute(docs_query)
        docs_uploaded = set(docs_res.scalars().all())

        subs_query = select(VendorSubscription.vendor_id).where(
            VendorSubscription.vendor_id.in_(vendor_ids),
            VendorSubscription.status == "active"
        )
        subs_res = await db.execute(subs_query)
        has_payment = set(subs_res.scalars().all())

    response = []
    for row in rows:
        v = row[0]
        emp_first = row[1]
        emp_last = row[2]
        user_mobile = row[3]
        
        # User email or Vendor email fallback
        raw_user_email = row[4]
        raw_vendor_email = v.email

        if raw_vendor_email and not raw_vendor_email.startswith("vendor_"):
            user_email = raw_vendor_email
        elif raw_user_email and not raw_user_email.startswith("vendor_"):
            user_email = raw_user_email
        else:
            user_email = raw_vendor_email or raw_user_email

        emp_name = None
        if emp_first or emp_last:
            emp_name = f"{emp_first or ''} {emp_last or ''}".strip()

        v_dict = {
            "id": v.id,
            "business_name": v.business_name,
            "first_name": v.first_name,
            "last_name": v.last_name,
            "city": v.city,
            "status": v.status,
            "onboarded_by_employee_id": v.onboarded_by_employee_id,
            "onboarded_by_employee_name": emp_name,
            "created_at": v.created_at,
            "documents_uploaded": v.id in docs_uploaded,
            "has_payment": v.id in has_payment,
            "aadhaar_number": v.aadhaar_number,
            "pan_number": v.pan_number,
            "gst_number": v.gst_number,
            "phone_number": user_mobile,
            "email": user_email
        }
        response.append(VendorAdminListResponse(**v_dict))

    return response

@router.get("/vendors/{vendor_id}", response_model=VendorProfileResponse)
async def get_vendor_details(
    vendor_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    query = select(Vendor).where(Vendor.id == vendor_id)
    result = await db.execute(query)
    vendor = result.scalar_one_or_none()
    
    if not vendor:
        raise HTTPException(status_code=404, detail="Vendor not found")
        
    return vendor

@router.put("/vendors/{vendor_id}/status")
async def update_vendor_status(
    vendor_id: int,
    status_update: VendorStatusUpdateRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_admin=Depends(get_current_admin),
):
    vendor = await db.get(Vendor, vendor_id)
    if not vendor:
        raise HTTPException(status_code=404, detail="Vendor not found")
    
    old_status = (vendor.status or "").strip().lower()
    new_status = status_update.status.strip().lower()
    vendor.status = new_status
    db.add(vendor)
    await db.commit()
    
    if new_status == "active" and old_status != "active":
        from app.models.user_location import User
        user_query = await db.execute(select(User).where(User.id == vendor.user_id))
        user = user_query.scalar_one_or_none()
        if user:
            from app.services.notification_service import send_user_push_notification
            title = "Verification Completed"
            body = (
                "Your verification is completed. Thank you for choosing AM5Royal."
            )
            background_tasks.add_task(
                send_user_push_notification,
                user_id=user.id,
                title=title,
                body=body,
            )
                    
    return {"message": "Vendor status updated successfully", "status": vendor.status}

@router.put("/vendors/{vendor_id}")
async def update_vendor(
    vendor_id: int,
    vendor_update: VendorProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    query = select(Vendor).where(Vendor.id == vendor_id)
    result = await db.execute(query)
    vendor = result.scalar_one_or_none()

    if not vendor:
        raise HTTPException(status_code=404, detail="Vendor not found")

    update_data = vendor_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(vendor, key, value)
    
    await db.commit()
    await db.refresh(vendor)
    return vendor

@router.delete("/vendors/{vendor_id}")
async def delete_vendor(
    vendor_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    from sqlalchemy import text
    query = select(Vendor).where(Vendor.id == vendor_id)
    result = await db.execute(query)
    vendor = result.scalar_one_or_none()

    if not vendor:
        raise HTTPException(status_code=404, detail="Vendor not found")

    # Delete child records
    await db.execute(text("DELETE FROM vendor_service_media WHERE vendor_service_id IN (SELECT id FROM vendor_services WHERE vendor_id = :v_id)"), {"v_id": vendor_id})
    await db.execute(text("DELETE FROM vendor_services WHERE vendor_id = :v_id"), {"v_id": vendor_id})
    await db.execute(text("DELETE FROM vendor_availability WHERE vendor_id = :v_id"), {"v_id": vendor_id})
    await db.execute(text("DELETE FROM vendor_documents WHERE vendor_id = :v_id"), {"v_id": vendor_id})
    await db.execute(text("DELETE FROM vendor_sub_categories WHERE vendor_id = :v_id"), {"v_id": vendor_id})
    await db.execute(text("DELETE FROM vendor_subscriptions WHERE vendor_id = :v_id"), {"v_id": vendor_id})
    await db.execute(text("DELETE FROM wallet_transactions WHERE wallet_id IN (SELECT id FROM vendor_wallets WHERE vendor_id = :v_id)"), {"v_id": vendor_id})
    await db.execute(text("DELETE FROM vendor_wallets WHERE vendor_id = :v_id"), {"v_id": vendor_id})

    await db.delete(vendor)
    await db.commit()
    return {"message": "Vendor deleted successfully", "vendor_id": vendor.id}

@router.get("/employees", response_model=List[EmployeeResponse])
async def list_employees(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    from sqlalchemy import text
    from datetime import date
    
    query = select(Employee).offset(skip).limit(limit)
    result = await db.execute(query)
    employees = result.scalars().all()
    
    res = await db.execute(text("SELECT employee_id, points FROM employee_daily_points WHERE date = :today"), {"today": date.today()})
    daily_points_map = {row[0]: row[1] for row in res.fetchall()}
    
    response = []
    for emp in employees:
        response.append({
            "id": emp.id,
            "first_name": emp.first_name,
            "last_name": emp.last_name,
            "email": emp.email,
            "phone_number": emp.phone_number,
            "role": emp.role,
            "status": emp.status,
            "referral_points": daily_points_map.get(emp.id, 0)
        })
    return response

@router.put("/employees/{employee_id}", response_model=EmployeeResponse)
async def update_employee_details(
    employee_id: int,
    employee_update: EmployeeUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    query = select(Employee).where(Employee.id == employee_id)
    result = await db.execute(query)
    employee = result.scalar_one_or_none()
    
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
        
    update_data = employee_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(employee, key, value)
        
    await db.commit()
    await db.refresh(employee)
    
    return employee

@router.put("/employees/{employee_id}/status")
async def update_employee_status(
    employee_id: int,
    status_update: EmployeeStatusUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    query = select(Employee).where(Employee.id == employee_id)
    result = await db.execute(query)
    employee = result.scalar_one_or_none()
    
    if not employee:
        raise HTTPException(status_code=404, detail="Employee not found")
        
    employee.status = status_update.status
    await db.commit()
    
    return {"message": f"Employee status updated to {employee.status}", "employee_id": employee.id}

@router.post("/services", response_model=ServiceResponse, status_code=status.HTTP_201_CREATED)
async def add_service(
    name: str = Form(...),
    main_category_id: int = Form(...),
    sub_category_id: int = Form(...),
    image: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    """
    Add a new service with an image upload to Cloudflare R2.
    Only accessible by Admins.
    """
    if not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are allowed")
        
    contents = await image.read()
    image_url = await upload_service.upload_file(contents, image.filename, image.content_type)
    
    if not image_url:
        raise HTTPException(status_code=500, detail="Failed to upload image")
        
    new_service = Service(
        name=name,
        main_category_id=main_category_id,
        sub_category_id=sub_category_id,
        image_url=image_url,
        is_active=True
    )
    
    db.add(new_service)
    await db.commit()
    await db.refresh(new_service)
    
    return new_service

@router.get("/withdrawals")
async def list_withdrawals(
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    result = await db.execute(
        select(
            WithdrawalRequest,
            Employee.first_name,
            Employee.last_name
        )
        .join(Employee, WithdrawalRequest.employee_id == Employee.id)
        .order_by(WithdrawalRequest.created_at.desc())
    )
    rows = result.all()
    
    withdrawals = []
    for row in rows:
        withdrawal_req, first_name, last_name = row
        withdrawals.append({
            "id": withdrawal_req.id,
            "employee_id": withdrawal_req.employee_id,
            "employee_name": f"{first_name} {last_name or ''}".strip(),
            "amount": withdrawal_req.amount,
            "status": withdrawal_req.status,
            "created_at": withdrawal_req.created_at.isoformat(),
            "bank_name": withdrawal_req.bank_name,
            "bank_account_number": withdrawal_req.bank_account_number,
            "bank_account_name": withdrawal_req.bank_account_name,
            "bank_ifsc_code": withdrawal_req.bank_ifsc_code,
        })
    return withdrawals

@router.post("/withdrawals/{withdrawal_id}/approve")
async def approve_withdrawal(
    withdrawal_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    result = await db.execute(
        select(WithdrawalRequest).where(WithdrawalRequest.id == withdrawal_id)
    )
    withdrawal = result.scalar_one_or_none()
    if not withdrawal:
        raise HTTPException(status_code=404, detail="Withdrawal request not found")
        
    withdrawal.status = "approved"
    await db.commit()
    return {"message": "Withdrawal approved and marked as sent", "status": "approved"}

@router.get("/company-leads", response_model=CompanyLeadsPaginatedResponse)
async def get_company_leads(
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin),
    start_date: Optional[datetime.date] = None,
    end_date: Optional[datetime.date] = None,
    lead_source: Optional[str] = None,
    skip: int = 0,
    limit: int = 10
):
    from sqlalchemy import or_
    conditions = [
        Vendor.onboarded_by_employee_id.is_(None),
        Vendor.assigned_telecaller_id.is_(None),
        ~Vendor.id.in_(
            select(VendorSubscription.vendor_id).where(VendorSubscription.status == 'active')
        ),
        or_(
            Vendor.lead_source.in_(['company', 'company_website', 'company_mobile']),
            Vendor.lead_source.is_(None),
            Vendor.lead_source == '',
        ),
    ]

    if lead_source == 'company_website':
        conditions.append(
            or_(
                Vendor.lead_source.in_(['company_website', 'company']),
                Vendor.lead_source.is_(None),
                Vendor.lead_source == '',
            )
        )
    elif lead_source == 'company_mobile':
        conditions.append(Vendor.lead_source == 'company_mobile')

    if start_date:
        start_dt = datetime.datetime.combine(start_date, datetime.time.min)
        conditions.append(Vendor.created_at >= start_dt)
    if end_date:
        end_dt = datetime.datetime.combine(end_date, datetime.time.max)
        conditions.append(Vendor.created_at <= end_dt)

    # Get total count
    count_query = select(func.count(Vendor.id)).where(*conditions)
    count_result = await db.execute(count_query)
    total = count_result.scalar() or 0

    # Get paginated data
    from app.models.user_location import User
    query = select(Vendor, User.mobile.label('phone_number')).outerjoin(
        User, Vendor.user_id == User.id
    ).where(*conditions).order_by(Vendor.created_at.desc()).offset(skip).limit(limit)
    
    result = await db.execute(query)
    rows = result.all()

    leads = []
    for vendor, phone in rows:
        leads.append({
            "id": vendor.id,
            "business_name": vendor.business_name,
            "first_name": vendor.first_name,
            "last_name": vendor.last_name,
            "city": vendor.city,
            "created_at": vendor.created_at,
            "phone_number": phone,
            "feedback": vendor.feedback,
            "payment_info": vendor.payment_info,
            "lead_source": vendor.lead_source,
        })

    return {"leads": leads, "total": total}


async def _get_source_leads(
    db: AsyncSession,
    *,
    source: str,
    search: Optional[str] = None,
    status: Optional[str] = None,
    start_date: Optional[datetime.date] = None,
    end_date: Optional[datetime.date] = None,
    skip: int = 0,
    limit: int = 20,
):
    """List all company website/mobile leads for admin (not only unassigned)."""
    from sqlalchemy import or_, and_
    from sqlalchemy.orm import aliased
    from app.models.user_location import User

    Telecaller = aliased(Employee)

    if source == "company_website":
        source_filter = or_(
            Vendor.lead_source.in_(["company_website", "company"]),
            Vendor.lead_source.is_(None),
            Vendor.lead_source == "",
        )
    else:
        source_filter = Vendor.lead_source == "company_mobile"

    conditions = [source_filter]

    if status:
        conditions.append(Vendor.status == status)

    if search:
        like = f"%{search.strip()}%"
        conditions.append(
            or_(
                Vendor.business_name.ilike(like),
                Vendor.first_name.ilike(like),
                Vendor.last_name.ilike(like),
                Vendor.city.ilike(like),
                User.mobile.ilike(like),
            )
        )

    if start_date:
        start_dt = datetime.datetime.combine(start_date, datetime.time.min)
        conditions.append(Vendor.created_at >= start_dt)
    if end_date:
        end_dt = datetime.datetime.combine(end_date, datetime.time.max)
        conditions.append(Vendor.created_at <= end_dt)

    count_query = (
        select(func.count(Vendor.id))
        .select_from(Vendor)
        .outerjoin(User, Vendor.user_id == User.id)
        .where(and_(*conditions))
    )
    total = (await db.execute(count_query)).scalar() or 0

    query = (
        select(
            Vendor,
            User.mobile.label("phone_number"),
            Telecaller.first_name.label("tc_first"),
            Telecaller.last_name.label("tc_last"),
        )
        .outerjoin(User, Vendor.user_id == User.id)
        .outerjoin(Telecaller, Vendor.assigned_telecaller_id == Telecaller.id)
        .where(and_(*conditions))
        .order_by(Vendor.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    rows = (await db.execute(query)).all()

    leads = []
    for vendor, phone, tc_first, tc_last in rows:
        assigned_name = None
        if tc_first or tc_last:
            assigned_name = f"{tc_first or ''} {tc_last or ''}".strip()
        leads.append(
            {
                "id": vendor.id,
                "business_name": vendor.business_name,
                "first_name": vendor.first_name,
                "last_name": vendor.last_name,
                "city": vendor.city,
                "created_at": vendor.created_at,
                "phone_number": phone,
                "feedback": vendor.feedback,
                "payment_info": vendor.payment_info,
                "lead_source": vendor.lead_source,
                "status": vendor.status,
                "assigned_telecaller_name": assigned_name,
            }
        )

    return {"leads": leads, "total": total}


@router.get("/website-leads", response_model=CompanyLeadsPaginatedResponse)
async def get_website_leads(
    db: AsyncSession = Depends(get_db),
    current_admin=Depends(get_current_admin),
    search: Optional[str] = None,
    status: Optional[str] = None,
    start_date: Optional[datetime.date] = None,
    end_date: Optional[datetime.date] = None,
    skip: int = 0,
    limit: int = 20,
):
    return await _get_source_leads(
        db,
        source="company_website",
        search=search,
        status=status,
        start_date=start_date,
        end_date=end_date,
        skip=skip,
        limit=limit,
    )


@router.get("/mobile-leads", response_model=CompanyLeadsPaginatedResponse)
async def get_mobile_leads(
    db: AsyncSession = Depends(get_db),
    current_admin=Depends(get_current_admin),
    search: Optional[str] = None,
    status: Optional[str] = None,
    start_date: Optional[datetime.date] = None,
    end_date: Optional[datetime.date] = None,
    skip: int = 0,
    limit: int = 20,
):
    return await _get_source_leads(
        db,
        source="company_mobile",
        search=search,
        status=status,
        start_date=start_date,
        end_date=end_date,
        skip=skip,
        limit=limit,
    )


@router.post("/company-leads/assign", response_model=LeadAssignResult)
async def assign_company_leads(
    db: AsyncSession = Depends(get_db),
    current_admin = Depends(get_current_admin)
):
    from sqlalchemy import or_

    # 1. Fetch active telecallers
    telecallers_res = await db.execute(
        select(Employee).where(Employee.role == 'telecaller', Employee.status == 'active')
    )
    telecallers = telecallers_res.scalars().all()
    if not telecallers:
        return {"assigned_count": 0, "telecallers_count": 0}
        
    # 2. Fetch unassigned company leads only
    leads_query = select(Vendor).where(
        Vendor.onboarded_by_employee_id.is_(None),
        Vendor.assigned_telecaller_id.is_(None),
        or_(
            Vendor.lead_source.in_(['company', 'company_website', 'company_mobile']),
            Vendor.lead_source.is_(None),
            Vendor.lead_source == '',
        ),
        ~Vendor.id.in_(
            select(VendorSubscription.vendor_id).where(VendorSubscription.status == 'active')
        )
    ).order_by(Vendor.created_at.asc())
    leads_res = await db.execute(leads_query)
    leads = leads_res.scalars().all()
    
    assigned_count = 0
    lead_idx = 0
    num_leads = len(leads)
    
    # 3. Assign up to 3 NEW leads per telecaller (does not count already-assigned)
    for tc in telecallers:
        for _ in range(3):
            if lead_idx >= num_leads:
                break
            lead = leads[lead_idx]
            lead.assigned_telecaller_id = tc.id
            # Preserve website/mobile source; only set generic company when source is missing/legacy
            if not lead.lead_source or lead.lead_source in ('direct_telecaller', 'freelancer'):
                lead.lead_source = 'company'
            elif lead.lead_source not in ('company_website', 'company_mobile', 'company'):
                lead.lead_source = 'company'
            db.add(lead)
            lead_idx += 1
            assigned_count += 1
            
    await db.commit()
    return {"assigned_count": assigned_count, "telecallers_count": len(telecallers)}




@router.get("/referrals/report")
async def get_admin_referral_report(
    start_date: Optional[datetime.date] = Query(None),
    end_date: Optional[datetime.date] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_admin=Depends(get_current_admin),
):
    """Return referral reporting from persisted records for authenticated admins."""
    if start_date and end_date and start_date > end_date:
        raise HTTPException(status_code=422, detail="start_date must be on or before end_date")

    start_at = datetime.datetime.combine(start_date, datetime.time.min) if start_date else None
    end_at = datetime.datetime.combine(end_date + datetime.timedelta(days=1), datetime.time.min) if end_date else None

    def within(column):
        filters = []
        column_start, column_end = start_at, end_at
        if getattr(getattr(column, "type", None), "timezone", False):
            if column_start is not None:
                column_start = column_start.replace(tzinfo=datetime.timezone.utc)
            if column_end is not None:
                column_end = column_end.replace(tzinfo=datetime.timezone.utc)
        if column_start is not None:
            filters.append(column >= column_start)
        if column_end is not None:
            filters.append(column < column_end)
        return filters

    link_filters = within(FreelancerReferralLink.created_at)
    click_filters = within(FreelancerReferralClickEvent.clicked_at)
    attribution_filters = within(VendorReferralAttribution.attributed_at)
    login_filters = within(VendorLoginEvent.login_at)
    install_filters = within(FreelancerInstallationTracking.install_date)

    async def count(stmt):
        return int((await db.execute(stmt)).scalar() or 0)

    now_utc_naive = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
    total_links = await count(select(func.count(FreelancerReferralLink.id)).where(*link_filters))
    active_links = await count(select(func.count(FreelancerReferralLink.id)).where(*link_filters, FreelancerReferralLink.status == "active", FreelancerReferralLink.expires_at > now_utc_naive))
    expired_links = await count(select(func.count(FreelancerReferralLink.id)).where(*link_filters, (FreelancerReferralLink.status != "active") | (FreelancerReferralLink.expires_at <= now_utc_naive)))
    total_clicks = await count(select(func.count(FreelancerReferralClickEvent.id)).where(*click_filters))
    unique_visitors = await count(select(func.count(func.distinct(FreelancerReferralClickEvent.visitor_id))).where(*click_filters))
    service_clicks = await count(select(func.count(FreelancerReferralClickEvent.id)).where(*click_filters, FreelancerReferralClickEvent.destination_type == "SERVICE"))
    vendor_clicks = await count(select(func.count(FreelancerReferralClickEvent.id)).where(*click_filters, FreelancerReferralClickEvent.destination_type == "PLAY_STORE"))
    registrations = await count(select(func.count(VendorReferralAttribution.id)).where(*attribution_filters))
    first_logins = await count(select(func.count(VendorLoginEvent.id)).join(VendorReferralAttribution, VendorLoginEvent.referral_attribution_id == VendorReferralAttribution.id).where(*login_filters, VendorLoginEvent.is_first_login.is_(True)))
    subsequent_logins = await count(select(func.count(VendorLoginEvent.id)).join(VendorReferralAttribution, VendorLoginEvent.referral_attribution_id == VendorReferralAttribution.id).where(*login_filters, VendorLoginEvent.is_first_login.is_(False)))

    vendor_codes = select(FreelancerReferralLink.referral_code).where(FreelancerReferralLink.referral_type == "vendor")
    validated_install_referrers = await count(select(func.count(func.distinct(FreelancerInstallationTracking.tracking_id))).where(*install_filters, func.lower(FreelancerInstallationTracking.app_type).like("%vendor%"), FreelancerInstallationTracking.referral_code.in_(vendor_codes)))

    freelancer_rows = (await db.execute(
        select(FreelancerReferralLink.freelancer_id, Freelancer.first_name, Freelancer.last_name, func.count(FreelancerReferralLink.id))
        .outerjoin(Freelancer, Freelancer.id == FreelancerReferralLink.freelancer_id)
        .where(*link_filters).group_by(FreelancerReferralLink.freelancer_id, Freelancer.first_name, Freelancer.last_name)
        .order_by(func.count(FreelancerReferralLink.id).desc())
    )).all()
    freelancer_reports = []
    for freelancer_id, first_name, last_name, referral_count in freelancer_rows:
        clicks = await count(select(func.count(FreelancerReferralClickEvent.id)).where(*click_filters, FreelancerReferralClickEvent.freelancer_id == freelancer_id))
        signups = await count(select(func.count(VendorReferralAttribution.id)).where(*attribution_filters, VendorReferralAttribution.freelancer_id == freelancer_id))
        freelancer_reports.append({"freelancer_id": freelancer_id, "freelancer_name": " ".join(p for p in (first_name, last_name) if p), "referrals": int(referral_count), "clicks": clicks, "registrations": signups})

    service_rows = (await db.execute(
        select(ServiceSubcategory.id, ServiceSubcategory.name)
        .where(ServiceSubcategory.main_category_id == 37)
        .order_by(ServiceSubcategory.sort_order, ServiceSubcategory.id)
    )).all()
    service_reports = []
    for service_id, service_name in service_rows:
        link_count = await count(select(func.count(FreelancerReferralLink.id)).where(*link_filters, FreelancerReferralLink.referral_type == "service", FreelancerReferralLink.target_sub_service_id == service_id))
        clicks = await count(select(func.count(FreelancerReferralClickEvent.id)).where(*click_filters, FreelancerReferralClickEvent.service_id == service_id, FreelancerReferralClickEvent.destination_type == "SERVICE"))
        signups = await count(select(func.count(VendorReferralAttribution.id)).where(*attribution_filters, VendorReferralAttribution.service_id == service_id))
        service_reports.append({"service_id": service_id, "service_name": service_name, "referrals": int(link_count), "clicks": clicks, "registrations": signups})

    vendor_rows = (await db.execute(
        select(VendorReferralAttribution.vendor_id, Vendor.business_name, VendorReferralAttribution.freelancer_id, VendorReferralAttribution.referral_link_id, VendorReferralAttribution.service_id, VendorReferralAttribution.attributed_at)
        .outerjoin(Vendor, Vendor.id == VendorReferralAttribution.vendor_id)
        .where(*attribution_filters).order_by(VendorReferralAttribution.attributed_at.desc()).limit(1000)
    )).all()
    vendor_reports = []
    for vendor_id, business_name, freelancer_id, referral_link_id, service_id, attributed_at in vendor_rows:
        login_count = await count(select(func.count(VendorLoginEvent.id)).join(VendorReferralAttribution, VendorLoginEvent.referral_attribution_id == VendorReferralAttribution.id).where(*login_filters, VendorLoginEvent.vendor_id == vendor_id))
        vendor_reports.append({"vendor_id": vendor_id, "vendor_name": business_name, "freelancer_id": freelancer_id, "referral_link_id": referral_link_id, "service_id": service_id, "registered_at": attributed_at, "successful_logins": login_count})

    async def daily_counts(column, filters):
        rows = (await db.execute(select(func.date(column), func.count()).where(*filters).group_by(func.date(column)))).all()
        return {str(day): int(value) for day, value in rows}

    daily = {}
    for key, column, filters in (("referrals_created", FreelancerReferralLink.created_at, link_filters), ("clicks", FreelancerReferralClickEvent.clicked_at, click_filters), ("registrations", VendorReferralAttribution.attributed_at, attribution_filters), ("successful_logins", VendorLoginEvent.login_at, login_filters)):
        for day, value in (await daily_counts(column, filters)).items():
            daily.setdefault(day, {"date": day, "referrals_created": 0, "clicks": 0, "registrations": 0, "successful_logins": 0})[key] = value
    monthly = {}
    for row in daily.values():
        month = row["date"][:7]
        aggregate = monthly.setdefault(month, {"month": month, "referrals_created": 0, "clicks": 0, "registrations": 0, "successful_logins": 0})
        for key in ("referrals_created", "clicks", "registrations", "successful_logins"):
            aggregate[key] += row[key]

    return {"success": True, "data": {
        "summary": {"total_referrals": total_links, "active_links": active_links, "expired_links": expired_links, "clicks": total_clicks, "unique_visitors": unique_visitors, "service_clicks": service_clicks, "vendor_app_clicks": vendor_clicks, "validated_install_referrers": validated_install_referrers, "registrations": registrations, "first_logins": first_logins, "subsequent_logins": subsequent_logins, "conversion_rate": round(registrations / total_clicks, 4) if total_clicks else 0.0},
        "freelancers": freelancer_reports, "vendors": vendor_reports, "services": service_reports,
        "daily": sorted(daily.values(), key=lambda x: x["date"]), "monthly": sorted(monthly.values(), key=lambda x: x["month"]),
    }}
