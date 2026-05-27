"""
slot_service.py
---------------
Handles GET /slots/available logic.

Steps:
  1. Validate service exists and is active.
  2. Fetch all caregivers who can perform this service.
  3. Generate all theoretically possible 15-min-aligned slot windows
     for the day (08:00 – 20:00), respecting service duration.
  4. For each window, exclude caregivers who have a confirmed booking
     that overlaps the window (using full duration, not just start time).
  5. Return windows where at least one caregiver is still free.
"""

from datetime import date, datetime, time, timedelta
from typing import List, Dict
from uuid import UUID

from sqlalchemy import select, and_
from sqlalchemy.engine import Connection

from app.models.tables import services, caregivers, caregiver_services, bookings


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
DAY_START = time(8, 0)    # slots begin at 08:00
DAY_END   = time(20, 0)   # last slot must END by 20:00


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _time_to_minutes(t: time) -> int:
    return t.hour * 60 + t.minute


def _minutes_to_time(minutes: int) -> time:
    return time(minutes // 60, minutes % 60)


def _generate_slot_windows(duration_minutes: int) -> List[tuple[time, time]]:
    """
    Returns all (start, end) pairs where:
    - start is 15-min aligned
    - start >= DAY_START
    - end <= DAY_END
    """
    slots = []
    start_min = _time_to_minutes(DAY_START)
    end_boundary = _time_to_minutes(DAY_END)

    current = start_min
    while current + duration_minutes <= end_boundary:
        slot_start = _minutes_to_time(current)
        slot_end   = _minutes_to_time(current + duration_minutes)
        slots.append((slot_start, slot_end))
        current += 15   # advance by one 15-min grid step

    return slots


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def get_available_slots(
    conn: Connection,
    service_id: UUID,
    booking_date: date,
) -> dict:
    """
    Returns a dict with service metadata and all available slots.
    Raises ValueError if service not found / inactive.
    """

    # ------------------------------------------------------------------
    # 1. Fetch service
    # ------------------------------------------------------------------
    svc_row = conn.execute(
        select(
            services.c.id,
            services.c.name,
            services.c.duration_minutes,
            services.c.is_active,
        ).where(services.c.id == service_id)
    ).fetchone()

    if svc_row is None:
        raise ValueError(f"Service {service_id} not found")
    if not svc_row.is_active:
        raise ValueError(f"Service '{svc_row.name}' is not currently active")

    duration = svc_row.duration_minutes

    # ------------------------------------------------------------------
    # 2. Fetch all caregivers who can perform this service (active only)
    # ------------------------------------------------------------------
    cg_rows = conn.execute(
        select(
            caregivers.c.id,
            caregivers.c.name,
            caregivers.c.email,
            caregivers.c.phone,
        )
        .join(
            caregiver_services,
            caregiver_services.c.caregiver_id == caregivers.c.id,
        )
        .where(
            and_(
                caregiver_services.c.service_id == service_id,
                caregivers.c.is_active == True,
            )
        )
    ).fetchall()

    if not cg_rows:
        return {
            "service_id":       service_id,
            "service_name":     svc_row.name,
            "duration_minutes": duration,
            "date":             booking_date,
            "slots":            [],
        }

    all_caregiver_ids = {row.id for row in cg_rows}
    caregiver_map: Dict[UUID, dict] = {
        row.id: {"id": row.id, "name": row.name,
                 "email": row.email, "phone": row.phone}
        for row in cg_rows
    }

    # ------------------------------------------------------------------
    # 3. Fetch all confirmed bookings on this date for these caregivers
    # ------------------------------------------------------------------
    booked_rows = conn.execute(
        select(
            bookings.c.caregiver_id,
            bookings.c.start_time,
            bookings.c.end_time,
        ).where(
            and_(
                bookings.c.caregiver_id.in_(all_caregiver_ids),
                bookings.c.booking_date == booking_date,
                bookings.c.status == "confirmed",
            )
        )
    ).fetchall()

    # Build a lookup: caregiver_id -> list of (start, end) busy windows
    busy: Dict[UUID, List[tuple[time, time]]] = {cid: [] for cid in all_caregiver_ids}
    for row in booked_rows:
        busy[row.caregiver_id].append((row.start_time, row.end_time))

    # ------------------------------------------------------------------
    # 4. Generate windows and find free caregivers for each
    # ------------------------------------------------------------------
    windows = _generate_slot_windows(duration)
    result_slots = []

    for (slot_start, slot_end) in windows:
        free_caregivers = []
        for cid in all_caregiver_ids:
            # Overlap condition: existing.start < slot.end AND existing.end > slot.start
            occupied = any(
                busy_start < slot_end and busy_end > slot_start
                for (busy_start, busy_end) in busy[cid]
            )
            if not occupied:
                free_caregivers.append(caregiver_map[cid])

        if free_caregivers:
            result_slots.append({
                "start_time":           slot_start.strftime("%H:%M"),
                "end_time":             slot_end.strftime("%H:%M"),
                "available_caregivers": free_caregivers,
            })

    return {
        "service_id":       service_id,
        "service_name":     svc_row.name,
        "duration_minutes": duration,
        "date":             booking_date,
        "slots":            result_slots,
    }
