from sqlalchemy import Column, String, Integer, Boolean, ForeignKey, Text, Numeric, DateTime, BigInteger, Time, JSON
from sqlalchemy.orm import relationship
from app.db.base_class import Base
import datetime
from sqlalchemy import UniqueConstraint, CheckConstraint, Index, text

class Vendor(Base):
    __tablename__ = "vendors"
    __mapper_args__ = {"exclude_properties": ["updated_at"]}

    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(BigInteger, index=True)
    onboarded_by_employee_id = Column(BigInteger, ForeignKey("employees.id"), nullable=True)
    lead_source = Column(String(50), default="company")  # 'direct_telecaller', 'company', 'company_website', 'company_mobile', 'freelancer'
    freelancer_id = Column(BigInteger, ForeignKey("freelancers.id"), nullable=True)
    assigned_telecaller_id = Column(BigInteger, ForeignKey("employees.id"), nullable=True)
    registration_team_lead_id = Column(BigInteger, ForeignKey("employees.id"), nullable=True)
    registration_team_lead_assigned_at = Column(DateTime(timezone=True), nullable=True)
    registration_team_lead_remark = Column(Text, nullable=True)
    registration_team_lead_remark_updated_at = Column(DateTime(timezone=True), nullable=True)
    registration_team_lead_remark_updated_by = Column(BigInteger, ForeignKey("employees.id"), nullable=True)
    first_name = Column(String)
    last_name = Column(String)
    father_name = Column(String)
    email = Column(String, nullable=True)
    mobile = Column(String, nullable=True)
    alternative_number = Column(String, nullable=True)
    business_name = Column(String)
    aadhaar_number = Column(String)
    aadhaar_verified = Column(Boolean, default=False)
    address = Column(Text)
    street = Column(String, nullable=True)
    city = Column(String)
    district = Column(String, nullable=True)
    state = Column(String)
    pincode = Column(String)
    gst_number = Column(String, nullable=True)
    pan_number = Column(String, nullable=True)
    usc_number = Column(String, nullable=True)
    msme_number = Column(String, nullable=True)
    govt_auth_doc_number = Column(String, nullable=True)
    current_bill_number = Column(String, nullable=True)
    latitude = Column(Numeric(9, 6))
    longitude = Column(Numeric(9, 6))
    is_premium = Column(Boolean, default=False)
    avg_rating = Column(Numeric(3, 2), default=0.0)
    total_reviews = Column(Integer, default=0)
    service_radius_km = Column(Integer, default=10)
    profile_image = Column(Text)
    status = Column(String(32), default="active")
    telecaller_services_updated = Column(Boolean, default=False)

    background_banner = Column(Text, nullable=True)
    business_description = Column(Text, nullable=True)
    business_highlights = Column(JSON, nullable=True)
    about_business = Column(Text, nullable=True)
    additional_business_info = Column(Text, nullable=True)
    alternative_contact_number = Column(String, nullable=True)
    feedback = Column(Text, nullable=True)
    payment_info = Column(String(100), nullable=True)
    visiting_charges = Column(Numeric(10, 2), nullable=True)

    # vendor_categories = relationship("VendorSubCategory", back_populates="vendor")

    @property
    def photo_url(self):
        return self.profile_image

    @property
    def operating_city(self):
        return self.city


class VendorReferralAttribution(Base):
    """One immutable Freelancer referral attribution for a registered Vendor."""
    __tablename__ = "vendor_referral_attributions"
    __table_args__ = (
        UniqueConstraint("vendor_id", name="uq_vendor_referral_attribution_vendor"),
        CheckConstraint(
            "registration_status IS NULL OR registration_status = 'success'",
            name="ck_vendor_referral_attributions_registration_status",
        ),
        CheckConstraint(
            "registration_source IS NULL OR registration_source IN "
            "('install_referrer', 'home_service_referral', 'vendor_referral')",
            name="ck_vendor_referral_attributions_registration_source",
        ),
    )

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, autoincrement=True)
    vendor_id = Column(BigInteger, ForeignKey("vendors.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE", name="fk_vendor_referral_attributions_user_id"),
        nullable=True,
        index=True,
    )
    freelancer_id = Column(BigInteger, ForeignKey("freelancers.id"), nullable=False, index=True)
    referral_link_id = Column(BigInteger, ForeignKey("freelancer_referral_links.id"), nullable=False, index=True)
    referral_code = Column(String, nullable=False, index=True)
    service_id = Column(BigInteger, ForeignKey("sub_categories.id"), nullable=True, index=True)
    installation_tracking_id = Column(
        String(128),
        ForeignKey(
            "freelancer_installation_trackings.tracking_id",
            ondelete="SET NULL",
            name="fk_vendor_referral_attributions_installation_tracking_id",
        ),
        nullable=True,
        index=True,
    )
    registration_status = Column(String(16), nullable=True)
    registration_source = Column(String(32), nullable=True)
    attributed_at = Column(DateTime(timezone=True), nullable=False, default=datetime.datetime.utcnow)

    @property
    def registered_at(self):
        return self.attributed_at


class VendorLoginEvent(Base):
    """Successful Vendor authentication events; never stores credentials or JWTs."""
    __tablename__ = "vendor_login_events"
    __table_args__ = (
        UniqueConstraint("event_id", name="uq_vendor_login_events_event_id"),
        UniqueConstraint("session_event_id", name="uq_vendor_login_events_session_event_id"),
        CheckConstraint("login_result = 'success'", name="ck_vendor_login_events_success_only"),
        Index(
            "uq_vendor_login_events_first_login_per_vendor",
            "vendor_id",
            unique=True,
            postgresql_where=text("is_first_login"),
            sqlite_where=text("is_first_login"),
        ),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    event_id = Column(String(64), nullable=False)
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE", name="fk_vendor_login_events_user_id"),
        nullable=False,
        index=True,
    )
    vendor_id = Column(
        BigInteger,
        ForeignKey("vendors.id", ondelete="CASCADE", name="fk_vendor_login_events_vendor_id"),
        nullable=False,
        index=True,
    )
    referral_attribution_id = Column(
        BigInteger,
        ForeignKey(
            "vendor_referral_attributions.id",
            ondelete="SET NULL",
            name="fk_vendor_login_events_referral_attribution_id",
        ),
        nullable=True,
        index=True,
    )
    login_at = Column(DateTime(timezone=True), nullable=False)
    login_method = Column(String(20), nullable=False)
    session_event_id = Column(String(64), nullable=False)
    login_result = Column(String(16), nullable=False)
    is_first_login = Column(Boolean, nullable=False)
class VendorSubCategory(Base):
    __tablename__ = "vendor_sub_categories"
    __mapper_args__ = {"exclude_properties": ["updated_at"]}

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, index=True, autoincrement=True)
    vendor_id = Column(BigInteger, ForeignKey("vendors.id"), index=True)
    main_category_id = Column(BigInteger, ForeignKey("main_categories.id"))
    sub_category_id = Column(BigInteger, ForeignKey("sub_categories.id"))

    # vendor = relationship("Vendor", back_populates="vendor_categories")
    # main_category = relationship("ServiceCategory")
    # sub_category = relationship("ServiceSubcategory")

class VendorDocument(Base):
    __tablename__ = "vendor_documents"
    __mapper_args__ = {"exclude_properties": ["updated_at"]}

    id = Column(BigInteger, primary_key=True, index=True)
    vendor_id = Column(BigInteger, ForeignKey("vendors.id"), index=True)
    document_type = Column(String(100))
    document_url = Column(Text)
    verification_status = Column(String(50), default="pending")

class VendorAvailability(Base):
    __tablename__ = "vendor_availability"
    __mapper_args__ = {"exclude_properties": ["created_at", "updated_at"]}

    id = Column(BigInteger, primary_key=True, index=True)
    vendor_id = Column(BigInteger, ForeignKey("vendors.id"), index=True)
    day_of_week = Column(Integer)
    start_time = Column(Time)
    end_time = Column(Time)
    is_available = Column(Boolean, default=True)

class VendorService(Base):
    __tablename__ = "vendor_services"
    
    id = Column(BigInteger, primary_key=True, index=True)
    vendor_id = Column(BigInteger, ForeignKey("vendors.id"), index=True)
    main_category_id = Column(BigInteger, ForeignKey("main_categories.id"))
    sub_category_id = Column(BigInteger, ForeignKey("sub_categories.id"))
    service_id = Column(BigInteger, ForeignKey("services.id"), nullable=True)
    title = Column(String(255))
    description = Column(Text)
    price = Column(Numeric(10, 2))
    discounted_price = Column(Numeric(10, 2))
    negotiable = Column(Boolean, default=False)
    booking_type = Column(String(50))
    is_active = Column(Boolean, default=True)

class VendorServiceMedia(Base):
    __tablename__ = "vendor_service_media"
    __mapper_args__ = {"exclude_properties": ["updated_at"]}

    id = Column(BigInteger, primary_key=True, index=True)
    vendor_service_id = Column(BigInteger, ForeignKey("vendor_services.id"), index=True)
    media_type = Column(String(50))
    media_url = Column(Text)


class VendorAuditLog(Base):
    __tablename__ = "vendor_audit_logs"
    __mapper_args__ = {"exclude_properties": ["updated_at"]}

    id = Column(BigInteger, primary_key=True, index=True)
    vendor_id = Column(BigInteger, ForeignKey("vendors.id"), index=True, nullable=False)
    employee_id = Column(BigInteger, ForeignKey("employees.id"), nullable=True, index=True)
    employee_name = Column(String(255), nullable=True)
    employee_role = Column(String(50), nullable=True)
    action_type = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    details = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, index=True)
