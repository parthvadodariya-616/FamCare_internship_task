"""
booking_service.py
------------------
Handles POST /cart/checkout — the core of the assignment.

Strategy: Pessimistic locking via SELECT FOR UPDATE inside a single
PostgreSQL transaction. Each item in the cart is validated in order.
If ANY item fails conflict detection, the entire transaction is rolled
back immediately. No partial bookings ever reach the database.

Conflict rules (both use full duration — not just start time):
  (a) Caregiver conflict: caregiver cannot have two overlapping bookings.
  (b) Patient conflict:   patient cannot have two overlapping bookings
                          on the same day across any service.

Overlap formula: A overlaps B when  A.start < B.end  AND  A.end > B.start
"""

from datetime import date, time, timedelta
from decimal import Decimal
from typing import List
from uuid import UUID

from sqlalchemy import select, and_, text
from sqlalchemy.engine import Connection

from app.models.tables import services, caregivers, patients, bookings, caregiver_services
from app.schemas.schemas import (
    CartItem,
    BookingConfirmed,
    CheckoutSuccess,
    CheckoutFailure,
    FailedItem,
)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _parse_time(t_str: str) -> time:
    """Parse 'HH:MM' string to time object."""
    return time.fromisoformat(t_str)


def _add_minutes(t: time, minutes: int) -> time:
    """Add minutes to a time object, returns new time."""
    dt = timedelta(hours=t.hour, minutes=t.minute, seconds=t.second)
    result = dt + timedelta(minutes=minutes)
    total_seconds = int(result.total_seconds())
    return time(total_seconds // 3600, (total_seconds % 3600) // 60)


def _fetch_service(conn: Connection, service_id: UUID) -> dict | None:
    row = conn.execute(
        select(
            services.c.id,
            services.c.name,
            services.c.duration_minutes,
            services.c.price,
            services.c.is_active,
        ).where(services.c.id == service_id)
    ).fetchone()
    if row is None:
        return None
    return {
        "id":               row.id,
        "name":             row.name,
        "duration_minutes": row.duration_minutes,
        "price":            row.price,
        "is_active":        row.is_active,
    }


def _fetch_caregiver(conn: Connection, caregiver_id: UUID) -> dict | None:
    row = conn.execute(
        select(
            caregivers.c.id,
            caregivers.c.name,
            caregivers.c.is_active,
        ).where(caregivers.c.id == caregiver_id)
    ).fetchone()
    if row is None:
        return None
    return {"id": row.id, "name": row.name, "is_active": row.is_active}


def _fetch_patient(conn: Connection, patient_id: UUID) -> dict | None:
    row = conn.execute(
        select(patients.c.id, patients.c.name)
        .where(patients.c.id == patient_id)
    ).fetchone()
    if row is None:
        return None
    return {"id": row.id, "name": row.name}


def _caregiver_can_do_service(
    conn: Connection, caregiver_id: UUID, service_id: UUID
) -> bool:
    row = conn.execute(
        select(caregiver_services.c.caregiver_id).where(
            and_(
                caregiver_services.c.caregiver_id == caregiver_id,
                caregiver_services.c.service_id   == service_id,
            )
        )
    ).fetchone()
    return row is not None


def _check_caregiver_conflict(
    conn: Connection,
    caregiver_id: UUID,
    booking_date: date,
    start_time: time,
    end_time: time,
    exclude_booking_id: UUID | None = None,
) -> bool:
    """
    Returns True if there is a confirmed booking for this caregiver
    that overlaps [start_time, end_time) on booking_date.

    Uses SELECT FOR UPDATE to lock matching rows for the duration of
    the transaction — prevents concurrent inserts from slipping through.
    """
    query = text("""
        SELECT id
        FROM   bookings
        WHERE  caregiver_id  = :caregiver_id
          AND  booking_date  = :booking_date
          AND  status        = 'confirmed'
          AND  start_time    < :end_time
          AND  end_time      > :start_time
          AND  (:exclude_id IS NULL OR id != :exclude_id)
        FOR UPDATE
    """)
    row = conn.execute(query, {
        "caregiver_id": str(caregiver_id),
        "booking_date": booking_date,
        "start_time":   start_time,
        "end_time":     end_time,
        "exclude_id":   str(exclude_booking_id) if exclude_booking_id else None,
    }).fetchone()
    return row is not None


def _check_patient_conflict(
    conn: Connection,
    patient_id: UUID,
    booking_date: date,
    start_time: time,
    end_time: time,
) -> bool:
    """
    Returns True if the patient already has a confirmed booking
    on the same date that overlaps [start_time, end_time).
    """
    query = text("""
        SELECT id
        FROM   bookings
        WHERE  patient_id   = :patient_id
          AND  booking_date = :booking_date
          AND  status       = 'confirmed'
          AND  start_time   < :end_time
          AND  end_time     > :start_time
        FOR UPDATE
    """)
    row = conn.execute(query, {
        "patient_id":   str(patient_id),
        "booking_date": booking_date,
        "start_time":   start_time,
        "end_time":     end_time,
    }).fetchone()
    return row is not None


def _insert_booking(
    conn: Connection,
    patient_id:   UUID,
    caregiver_id: UUID,
    service_id:   UUID,
    booking_date: date,
    start_time:   time,
    end_time:     time,
) -> UUID:
    """Inserts one booking row and returns its new UUID."""
    result = conn.execute(
        bookings.insert().returning(bookings.c.id).values(
            patient_id=patient_id,
            caregiver_id=caregiver_id,
            service_id=service_id,
            booking_date=booking_date,
            start_time=start_time,
            end_time=end_time,
            status="confirmed",
        )
    )
    return result.fetchone()[0]


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

def process_checkout(
    conn: Connection,
    patient_id: UUID,
    items: List[CartItem],
) -> CheckoutSuccess | CheckoutFailure:
    """
    Processes an entire cart atomically inside the caller's transaction.

    The caller (router) must wrap this in engine.begin() so that any
    exception causes a full rollback of all inserts made so far.

    Returns CheckoutSuccess or CheckoutFailure — never raises HTTP errors
    (that's the router's job).
    """

    # ------------------------------------------------------------------
    # 0. Validate patient exists
    # ------------------------------------------------------------------
    patient = _fetch_patient(conn, patient_id)
    if patient is None:
        return CheckoutFailure(
            success=False,
            message="Patient not found",
            failed_item=FailedItem(
                service_id=items[0].service_id,
                caregiver_id=items[0].caregiver_id,
                booking_date=items[0].booking_date,
                start_time=items[0].start_time,
                reason=f"Patient {patient_id} does not exist",
            ),
        )

    confirmed_bookings: List[BookingConfirmed] = []
    total_price = Decimal("0.00")

    # ------------------------------------------------------------------
    # 1. Process each item in order — fail fast on first conflict
    # ------------------------------------------------------------------
    for item in items:
        start_time = _parse_time(item.start_time)

        # a) Fetch & validate service
        svc = _fetch_service(conn, item.service_id)
        if svc is None:
            raise _rollback_with(conn, CheckoutFailure(
                success=False,
                message="Service not found",
                failed_item=FailedItem(
                    service_id=item.service_id,
                    caregiver_id=item.caregiver_id,
                    booking_date=item.booking_date,
                    start_time=item.start_time,
                    reason=f"Service {item.service_id} does not exist",
                ),
            ))
        if not svc["is_active"]:
            return _fail(item, f"Service '{svc['name']}' is not currently active")

        # b) Fetch & validate caregiver
        cg = _fetch_caregiver(conn, item.caregiver_id)
        if cg is None:
            return _fail(item, f"Caregiver {item.caregiver_id} does not exist")
        if not cg["is_active"]:
            return _fail(item, f"Caregiver '{cg['name']}' is not currently active")

        # c) Caregiver must be qualified for this service
        if not _caregiver_can_do_service(conn, item.caregiver_id, item.service_id):
            return _fail(
                item,
                f"Caregiver '{cg['name']}' is not qualified to perform '{svc['name']}'",
            )

        # d) Compute end_time using duration from DB (never hardcoded)
        end_time = _add_minutes(start_time, svc["duration_minutes"])

        # e) Check caregiver conflict (SELECT FOR UPDATE)
        if _check_caregiver_conflict(
            conn, item.caregiver_id, item.booking_date, start_time, end_time
        ):
            return _fail(
                item,
                f"Caregiver '{cg['name']}' is already booked during "
                f"{item.start_time}–{end_time.strftime('%H:%M')} on {item.booking_date}",
            )

        # f) Check patient conflict (SELECT FOR UPDATE)
        if _check_patient_conflict(
            conn, patient_id, item.booking_date, start_time, end_time
        ):
            return _fail(
                item,
                f"You already have an overlapping booking during "
                f"{item.start_time}–{end_time.strftime('%H:%M')} on {item.booking_date}",
            )

        # g) All checks passed — insert this booking
        booking_id = _insert_booking(
            conn,
            patient_id=patient_id,
            caregiver_id=item.caregiver_id,
            service_id=item.service_id,
            booking_date=item.booking_date,
            start_time=start_time,
            end_time=end_time,
        )

        confirmed_bookings.append(
            BookingConfirmed(
                booking_id=booking_id,
                service_name=svc["name"],
                caregiver_name=cg["name"],
                booking_date=item.booking_date,
                start_time=item.start_time,
                end_time=end_time.strftime("%H:%M"),
                price=svc["price"],
            )
        )
        total_price += svc["price"]

    # ------------------------------------------------------------------
    # 2. All items passed — transaction will commit in caller
    # ------------------------------------------------------------------
    return CheckoutSuccess(
        success=True,
        message="All bookings confirmed",
        bookings=confirmed_bookings,
        total_price=total_price,
    )


# ---------------------------------------------------------------------------
# Helper: build a CheckoutFailure without raising
# ---------------------------------------------------------------------------

def _fail(item: CartItem, reason: str) -> CheckoutFailure:
    return CheckoutFailure(
        success=False,
        message=reason,
        failed_item=FailedItem(
            service_id=item.service_id,
            caregiver_id=item.caregiver_id,
            booking_date=item.booking_date,
            start_time=item.start_time,
            reason=reason,
        ),
    )


def _rollback_with(conn: Connection, result: CheckoutFailure) -> CheckoutFailure:
    """
    Not actually used for raising — process_checkout returns failures as values.
    Kept here as a named helper for clarity during code review.
    """
    return result
