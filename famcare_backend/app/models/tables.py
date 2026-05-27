from sqlalchemy import (
    MetaData,
    Table,
    Column,
    String,
    Integer,
    Numeric,
    Boolean,
    Date,
    Time,
    Text,
    ForeignKey,
    CheckConstraint,
    UniqueConstraint,
    PrimaryKeyConstraint,
    TIMESTAMP,
)
from sqlalchemy.dialects.postgresql import UUID
import sqlalchemy as sa

metadata = MetaData()

# ---------------------------------------------------------------------------
# services
# ---------------------------------------------------------------------------
services = Table(
    "services",
    metadata,
    Column("id",               UUID(as_uuid=True), primary_key=True,
           server_default=sa.text("uuid_generate_v4()")),
    Column("name",             String(100),  nullable=False),
    Column("duration_minutes", Integer,      nullable=False),
    Column("price",            Numeric(10, 2), nullable=False),
    Column("description",      Text,         nullable=False, server_default="''"),
    Column("is_active",        Boolean,      nullable=False, server_default=sa.text("TRUE")),
    Column("created_at",       TIMESTAMP(timezone=True), nullable=False,
           server_default=sa.text("NOW()")),
    UniqueConstraint("name", name="uq_service_name"),
    CheckConstraint(
        "duration_minutes > 0 AND duration_minutes % 15 = 0",
        name="chk_service_duration",
    ),
    CheckConstraint("price >= 0", name="chk_service_price"),
)

# ---------------------------------------------------------------------------
# caregivers
# ---------------------------------------------------------------------------
caregivers = Table(
    "caregivers",
    metadata,
    Column("id",        UUID(as_uuid=True), primary_key=True,
           server_default=sa.text("uuid_generate_v4()")),
    Column("name",      String(100), nullable=False),
    Column("phone",     String(20),  nullable=False),
    Column("email",     String(150), nullable=False),
    Column("is_active", Boolean,     nullable=False, server_default=sa.text("TRUE")),
    Column("created_at", TIMESTAMP(timezone=True), nullable=False,
           server_default=sa.text("NOW()")),
    UniqueConstraint("email", name="uq_caregiver_email"),
    UniqueConstraint("phone", name="uq_caregiver_phone"),
)

# ---------------------------------------------------------------------------
# caregiver_services  (many-to-many join)
# ---------------------------------------------------------------------------
caregiver_services = Table(
    "caregiver_services",
    metadata,
    Column("caregiver_id", UUID(as_uuid=True),
           ForeignKey("caregivers.id", ondelete="CASCADE"), nullable=False),
    Column("service_id",   UUID(as_uuid=True),
           ForeignKey("services.id",   ondelete="CASCADE"), nullable=False),
    Column("created_at",   TIMESTAMP(timezone=True), nullable=False,
           server_default=sa.text("NOW()")),
    PrimaryKeyConstraint("caregiver_id", "service_id", name="pk_caregiver_services"),
)

# ---------------------------------------------------------------------------
# patients
# ---------------------------------------------------------------------------
patients = Table(
    "patients",
    metadata,
    Column("id",        UUID(as_uuid=True), primary_key=True,
           server_default=sa.text("uuid_generate_v4()")),
    Column("name",      String(100), nullable=False),
    Column("phone",     String(20),  nullable=False),
    Column("email",     String(150), nullable=False),
    Column("created_at", TIMESTAMP(timezone=True), nullable=False,
           server_default=sa.text("NOW()")),
    UniqueConstraint("email", name="uq_patient_email"),
    UniqueConstraint("phone", name="uq_patient_phone"),
)

# ---------------------------------------------------------------------------
# bookings
# ---------------------------------------------------------------------------
bookings = Table(
    "bookings",
    metadata,
    Column("id",           UUID(as_uuid=True), primary_key=True,
           server_default=sa.text("uuid_generate_v4()")),
    Column("patient_id",   UUID(as_uuid=True),
           ForeignKey("patients.id",   ondelete="RESTRICT"), nullable=False),
    Column("caregiver_id", UUID(as_uuid=True),
           ForeignKey("caregivers.id", ondelete="RESTRICT"), nullable=False),
    Column("service_id",   UUID(as_uuid=True),
           ForeignKey("services.id",   ondelete="RESTRICT"), nullable=False),
    Column("booking_date", Date,        nullable=False),
    Column("start_time",   Time,        nullable=False),
    Column("end_time",     Time,        nullable=False),
    Column("status",       String(20),  nullable=False, server_default="'confirmed'"),
    Column("created_at",   TIMESTAMP(timezone=True), nullable=False,
           server_default=sa.text("NOW()")),
    CheckConstraint("end_time > start_time",     name="chk_booking_time_order"),
    CheckConstraint("status IN ('confirmed', 'cancelled')", name="chk_booking_status"),
    CheckConstraint(
        "EXTRACT(MINUTE FROM start_time)::INTEGER % 15 = 0 "
        "AND EXTRACT(SECOND FROM start_time) = 0",
        name="chk_start_time_aligned",
    ),
)
