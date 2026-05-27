from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.engine import Connection

from app.database import get_db
from app.models.tables import patients, caregivers
from app.schemas.schemas import (
    CheckoutRequest,
    CheckoutSuccess,
    CheckoutFailure,
    PatientOut,
    CaregiverOut,
)
from app.services.booking_service import process_checkout

router = APIRouter(prefix="/cart", tags=["Cart & Checkout"])
patients_router = APIRouter(prefix="/patients", tags=["Patients"])
caregivers_router = APIRouter(prefix="/caregivers", tags=["Caregivers"])


# ---------------------------------------------------------------------------
# GET /patients  — Flutter needs a patient_id to pass to checkout
# ---------------------------------------------------------------------------

@patients_router.get(
    "",
    response_model=list[PatientOut],
    summary="List all patients",
    description="Returns all patients. Use the patient id in POST /cart/checkout.",
)
def list_patients(conn: Connection = Depends(get_db)):
    rows = conn.execute(
        select(
            patients.c.id,
            patients.c.name,
            patients.c.email,
            patients.c.phone,
        ).order_by(patients.c.name)
    ).fetchall()
    return [PatientOut(id=r.id, name=r.name, email=r.email, phone=r.phone) for r in rows]


# ---------------------------------------------------------------------------
# GET /caregivers  — lets Flutter show caregiver names
# ---------------------------------------------------------------------------

@caregivers_router.get(
    "",
    response_model=list[CaregiverOut],
    summary="List all active caregivers",
    description="Returns all active caregivers.",
)
def list_caregivers(conn: Connection = Depends(get_db)):
    rows = conn.execute(
        select(
            caregivers.c.id,
            caregivers.c.name,
            caregivers.c.email,
            caregivers.c.phone,
        )
        .where(caregivers.c.is_active == True)
        .order_by(caregivers.c.name)
    ).fetchall()
    return [CaregiverOut(id=r.id, name=r.name, email=r.email, phone=r.phone) for r in rows]


# ---------------------------------------------------------------------------
# POST /cart/checkout
# ---------------------------------------------------------------------------

@router.post(
    "/checkout",
    summary="Atomic multi-slot checkout",
    description=(
        "Accepts a list of {service_id, caregiver_id, booking_date, start_time} "
        "items for a single patient. "
        "**All slots are booked atomically inside one PostgreSQL transaction.** "
        "If any single slot fails (caregiver conflict, patient overlap, invalid "
        "service/caregiver), the **entire cart is rolled back** — zero bookings "
        "are created. "
        "On failure, the response identifies exactly which item failed and why, "
        "so the Flutter UI can show the user a clear error."
    ),
    responses={
        200: {"description": "All bookings confirmed (success=true)"},
        409: {"description": "Conflict detected — full rollback (success=false)"},
        422: {"description": "Validation error (bad UUID, bad time format, empty cart)"},
    },
)
def checkout(
    body: CheckoutRequest,
    conn: Connection = Depends(get_db),
):
    result = process_checkout(conn, body.patient_id, body.items)

    if isinstance(result, CheckoutFailure):
        # 409 Conflict — Flutter checks this status code to show failure UI
        raise HTTPException(status_code=409, detail=result.model_dump())

    return result
