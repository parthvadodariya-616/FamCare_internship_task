"""
test_checkout.py
----------------
Tests for POST /cart/checkout — atomic behaviour.

Every test starts with a clean DB (conftest rolls back after each).
Seed data is inserted only where needed via insert_seed_data().
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.engine import Connection

from tests.conftest import (
    SERVICE_IDS,
    CAREGIVER_IDS,
    PATIENT_IDS,
    insert_seed_data,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def checkout_payload(
    patient_key: str,
    items: list[dict],
) -> dict:
    return {
        "patient_id": PATIENT_IDS[patient_key],
        "items": items,
    }


def single_item(
    service_key: str,
    caregiver_key: str,
    date: str,
    start_time: str,
) -> dict:
    return {
        "service_id":   SERVICE_IDS[service_key],
        "caregiver_id": CAREGIVER_IDS[caregiver_key],
        "booking_date": date,
        "start_time":   start_time,
    }


# ===========================================================================
# 1. Successful checkout
# ===========================================================================

class TestSuccessfulCheckout:

    def test_single_item_checkout_returns_200(self, client: TestClient, db_conn: Connection):
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "amit",
            [single_item("physio", "deepak", "2025-06-03", "09:00")],
        ))
        assert resp.status_code == 200
        body = resp.json()
        assert body["success"] is True
        assert len(body["bookings"]) == 1
        assert body["bookings"][0]["service_name"] == "Physiotherapy"
        assert body["bookings"][0]["end_time"] == "10:00"   # 09:00 + 60 min

    def test_multi_item_checkout_all_confirmed(self, client: TestClient, db_conn: Connection):
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "kavita",
            [
                single_item("blood",  "sunita", "2025-06-03", "08:00"),
                single_item("wound",  "sunita", "2025-06-03", "09:00"),
                single_item("elderly","anjali", "2025-06-05", "10:00"),
            ],
        ))
        assert resp.status_code == 200
        body = resp.json()
        assert body["success"] is True
        assert len(body["bookings"]) == 3
        # Total = 200 + 350 + 400 = 950
        assert float(body["total_price"]) == pytest.approx(950.0)

    def test_checkout_creates_rows_in_db(self, client: TestClient, db_conn: Connection):
        insert_seed_data(db_conn)
        client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [single_item("blood", "anjali", "2025-06-10", "08:00")],
        ))
        count = db_conn.execute(
            text("SELECT COUNT(*) FROM bookings WHERE patient_id = :pid AND booking_date = '2025-06-10'"),
            {"pid": PATIENT_IDS["neha"]},
        ).scalar()
        assert count == 1

    def test_adjacent_slots_both_confirmed(self, client: TestClient, db_conn: Connection):
        """
        Sunita does Blood Test (15 min) at 08:00–08:15, then again at 08:15.
        Adjacent slots must NOT trigger an overlap error.
        """
        insert_seed_data(db_conn)
        # First patient books 08:00–08:15
        r1 = client.post("/cart/checkout", json=checkout_payload(
            "amit",
            [single_item("blood", "sunita", "2025-06-10", "08:00")],
        ))
        assert r1.status_code == 200

        # Second patient books 08:15–08:30 — must succeed
        r2 = client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [single_item("blood", "sunita", "2025-06-10", "08:15")],
        ))
        assert r2.status_code == 200


# ===========================================================================
# 2. Full rollback on failure
# ===========================================================================

class TestAtomicRollback:

    def test_one_bad_item_rolls_back_entire_cart(self, client: TestClient, db_conn: Connection):
        """
        Cart: 2 valid items + 1 conflicting item.
        Expected: 409, zero bookings inserted.
        """
        insert_seed_data(db_conn)

        resp = client.post("/cart/checkout", json=checkout_payload(
            "kavita",
            [
                # Valid: deepak free on 2025-06-03
                single_item("physio", "deepak", "2025-06-03", "08:00"),
                # Valid: sunita free on 2025-06-03
                single_item("blood",  "sunita", "2025-06-03", "08:00"),
                # CONFLICT: priya is already booked 10:00–11:00 on 2025-06-02
                single_item("physio", "priya",  "2025-06-02", "10:00"),
            ],
        ))

        assert resp.status_code == 409
        body = resp.json()["detail"]
        assert body["success"] is False
        assert "already booked" in body["message"].lower()

        # Confirm zero rows were inserted for kavita on 2025-06-03
        count = db_conn.execute(
            text("""
                SELECT COUNT(*) FROM bookings
                WHERE patient_id   = :pid
                  AND booking_date = '2025-06-03'
                  AND status       = 'confirmed'
            """),
            {"pid": PATIENT_IDS["kavita"]},
        ).scalar()
        assert count == 0

    def test_failed_item_info_returned(self, client: TestClient, db_conn: Connection):
        """Response must identify exactly which item failed and why."""
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "amit",
            [single_item("wound", "rahul", "2025-06-02", "15:00")],  # rahul busy 15:00–15:30
        ))
        assert resp.status_code == 409
        detail = resp.json()["detail"]
        fi = detail["failed_item"]
        assert fi["start_time"] == "15:00"
        assert fi["booking_date"] == "2025-06-02"
        assert "reason" in fi
        assert len(fi["reason"]) > 0


# ===========================================================================
# 3. Validation errors
# ===========================================================================

class TestValidation:

    def test_empty_cart_rejected(self, client: TestClient, db_conn: Connection):
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json={
            "patient_id": PATIENT_IDS["amit"],
            "items": [],
        })
        assert resp.status_code == 422

    def test_bad_start_time_rejected(self, client: TestClient, db_conn: Connection):
        insert_seed_data(db_conn)
        item = single_item("physio", "deepak", "2025-06-03", "10:07")  # not 15-min aligned
        resp = client.post("/cart/checkout", json=checkout_payload("amit", [item]))
        assert resp.status_code == 422

    def test_nonexistent_patient_rejected(self, client: TestClient, db_conn: Connection):
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json={
            "patient_id": "00000000-0000-0000-0000-000000000099",
            "items": [single_item("physio", "deepak", "2025-06-03", "08:00")],
        })
        assert resp.status_code == 409
        assert "not found" in resp.json()["detail"]["message"].lower()

    def test_caregiver_not_qualified_rejected(self, client: TestClient, db_conn: Connection):
        """Priya cannot do Wound Dressing — she is not in caregiver_services for it."""
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "amit",
            [single_item("wound", "priya", "2025-06-03", "08:00")],
        ))
        assert resp.status_code == 409
        detail = resp.json()["detail"]
        assert "not qualified" in detail["failed_item"]["reason"].lower()
