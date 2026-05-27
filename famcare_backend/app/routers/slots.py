from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.engine import Connection

from app.database import get_db
from app.models.tables import services
from app.schemas.schemas import SlotAvailabilityResponse, ServiceOut
from app.services.slot_service import get_available_slots

router = APIRouter(prefix="/slots", tags=["Slots"])
services_router = APIRouter(prefix="/services", tags=["Services"])


# ---------------------------------------------------------------------------
# GET /services
# Lets the Flutter app populate the service picker dropdown.
# ---------------------------------------------------------------------------

@services_router.get(
    "",
    response_model=list[ServiceOut],
    summary="List all active services",
    description=(
        "Returns every active service with its name, duration (always a "
        "multiple of 15 min), and price. Use these IDs in the slot and "
        "checkout endpoints."
    ),
)
def list_services(conn: Connection = Depends(get_db)):
    rows = conn.execute(
        select(
            services.c.id,
            services.c.name,
            services.c.duration_minutes,
            services.c.price,
            services.c.description,
            services.c.is_active,
        ).where(services.c.is_active == True)
        .order_by(services.c.name)
    ).fetchall()

    return [
        ServiceOut(
            id=row.id,
            name=row.name,
            duration_minutes=row.duration_minutes,
            price=row.price,
            description=row.description,
            is_active=row.is_active,
        )
        for row in rows
    ]


# ---------------------------------------------------------------------------
# GET /slots/available
# ---------------------------------------------------------------------------

@router.get(
    "/available",
    response_model=SlotAvailabilityResponse,
    summary="Get available time slots for a service on a date",
    description=(
        "Returns all 15-min-aligned time windows between 08:00 and 20:00 "
        "where at least one qualified caregiver is free for the full service "
        "duration. Duration is always read from the service definition — "
        "never hardcoded."
    ),
)
def available_slots(
    service_id: UUID = Query(..., description="UUID of the service"),
    date:       date = Query(..., description="Date to check (YYYY-MM-DD)"),
    conn: Connection = Depends(get_db),
):
    try:
        result = get_available_slots(conn, service_id, date)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    return SlotAvailabilityResponse(**result)
