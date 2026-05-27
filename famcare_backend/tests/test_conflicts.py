"""
test_conflicts.py
-----------------
Tests that overlap detection uses FULL DURATION — not just start time.

All overlap cases:
  Case 1: Exact same window                → BLOCKED
  Case 2: New slot starts inside existing  → BLOCKED
  Case 3: New slot ends inside existing    → BLOCKED
  Case 4: New slot contains existing       → BLOCKED
  Case 5: Adjacent (touching but not over) → ALLOWED
  Case 6: Completely separate              → ALLOWED

Also tests:
  - Patient self-conflict across services on the same day
  - Different caregivers, same slot — both allowed
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


def checkout_payload(patient_key: str, items: list[dict]) -> dict:
    return {"patient_id": PATIENT_IDS[patient_key], "items": items}


def item(service_key, caregiver_key, date, start_time):
    return {
        "service_id":   SERVICE_IDS[service_key],
        "caregiver_id": CAREGIVER_IDS[caregiver_key],
        "booking_date": date,
        "start_time":   start_time,
    }


# ===========================================================================
# Caregiver conflict cases
# ===========================================================================

class TestCaregiverConflict:
    """
    Priya is booked for Physiotherapy (60 min) 10:00–11:00 on 2025-06-02.
    Deepak is booked for Physiotherapy (60 min) 10:00–11:00 on 2025-06-04.
    """

    def test_exact_overlap_blocked(self, client: TestClient, db_conn: Connection):
        """New booking at exactly the same window → blocked."""
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [item("physio", "priya", "2025-06-02", "10:00")],
        ))
        assert resp.status_code == 409
        assert "already booked" in resp.json()["detail"]["failed_item"]["reason"].lower()

    def test_new_slot_starts_inside_existing_blocked(self, client: TestClient, db_conn: Connection):
        """
        Priya busy 10:00–11:00.
        New booking 10:30–11:30 → starts inside existing → blocked.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [item("physio", "priya", "2025-06-02", "10:30")],
        ))
        assert resp.status_code == 409

    def test_new_slot_ends_inside_existing_blocked(self, client: TestClient, db_conn: Connection):
        """
        Priya busy 10:00–11:00.
        New booking 09:30–10:30 → ends inside existing → blocked.
        (Use IV Therapy 45 min: 09:30 + 45 min = 10:15, still overlaps)
        Priya doesn't do IV, use Deepak on 2025-06-04 busy 10:00–11:00.
        New: IV therapy 09:15–10:00... use a service Deepak can do.
        Physio 09:30+60=10:30 overlaps 10:00 — blocked.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "kavita",
            [item("physio", "deepak", "2025-06-04", "09:30")],
        ))
        assert resp.status_code == 409

    def test_new_slot_contains_existing_blocked(self, client: TestClient, db_conn: Connection):
        """
        Rahul busy 15:00–15:30 (Wound Dressing 30 min) on 2025-06-02.
        New Post-Surgery Care (90 min) at 14:30 = 14:30–16:00 → contains existing → blocked.
        Rahul does Post-Surgery Care — check caregiver_services: yes, rahul does it.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "kavita",
            [item("post_surgery", "rahul", "2025-06-02", "14:30")],
        ))
        assert resp.status_code == 409

    def test_adjacent_slot_after_existing_allowed(self, client: TestClient, db_conn: Connection):
        """
        Priya busy 10:00–11:00.
        New Physio at 11:00–12:00 → touches but does NOT overlap → allowed.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [item("physio", "priya", "2025-06-02", "11:00")],
        ))
        assert resp.status_code == 200

    def test_adjacent_slot_before_existing_allowed(self, client: TestClient, db_conn: Connection):
        """
        Priya busy 10:00–11:00.
        New Physio at 09:00–10:00 → ends exactly at existing start → allowed.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [item("physio", "priya", "2025-06-02", "09:00")],
        ))
        assert resp.status_code == 200

    def test_completely_separate_slot_allowed(self, client: TestClient, db_conn: Connection):
        """
        Priya busy 10:00–11:00.
        New Physio at 13:00 — completely separate → allowed.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [item("physio", "priya", "2025-06-02", "13:00")],
        ))
        assert resp.status_code == 200

    def test_different_date_same_time_allowed(self, client: TestClient, db_conn: Connection):
        """
        Priya busy 10:00–11:00 on 2025-06-02.
        Same slot on 2025-06-03 (different date) → allowed.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [item("physio", "priya", "2025-06-03", "10:00")],
        ))
        assert resp.status_code == 200

    def test_different_caregivers_same_slot_both_allowed(
        self, client: TestClient, db_conn: Connection
    ):
        """
        Priya and Deepak are both Physiotherapy caregivers.
        Amit books Priya at 08:00, Neha books Deepak at 08:00 — no conflict.
        """
        insert_seed_data(db_conn)
        r1 = client.post("/cart/checkout", json=checkout_payload(
            "amit",
            [item("physio", "priya", "2025-06-10", "08:00")],
        ))
        assert r1.status_code == 200

        r2 = client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [item("physio", "deepak", "2025-06-10", "08:00")],
        ))
        assert r2.status_code == 200


# ===========================================================================
# Patient self-conflict cases
# ===========================================================================

class TestPatientConflict:
    """
    A patient cannot have two overlapping bookings on the same day,
    even with different caregivers and different services.
    """

    def test_patient_same_service_same_slot_blocked(
        self, client: TestClient, db_conn: Connection
    ):
        insert_seed_data(db_conn)
        # Amit already has Physiotherapy 10:00–11:00 on 2025-06-02 (seed data)
        # Attempt to book Blood Test at 10:00 — overlaps → blocked
        resp = client.post("/cart/checkout", json=checkout_payload(
            "amit",
            [item("blood", "anjali", "2025-06-02", "10:00")],
        ))
        assert resp.status_code == 409
        reason = resp.json()["detail"]["failed_item"]["reason"].lower()
        assert "overlapping" in reason

    def test_patient_different_services_overlap_blocked(
        self, client: TestClient, db_conn: Connection
    ):
        """
        Amit already booked 10:00–11:00 on 2025-06-02 (Physio).
        Try booking Wound Dressing (30 min) at 10:15 = 10:15–10:45 → overlaps → blocked.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "amit",
            [item("wound", "rahul", "2025-06-02", "10:15")],
        ))
        assert resp.status_code == 409

    def test_patient_non_overlapping_different_services_allowed(
        self, client: TestClient, db_conn: Connection
    ):
        """
        Amit booked 10:00–11:00 on 2025-06-02.
        New booking at 11:30 — same patient, same day, no overlap → allowed.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "amit",
            [item("wound", "rahul", "2025-06-02", "11:30")],
        ))
        # Rahul is free at 11:30 on 2025-06-02 (he was at 15:00)
        assert resp.status_code == 200

    def test_same_patient_different_days_allowed(
        self, client: TestClient, db_conn: Connection
    ):
        """
        Amit booked 10:00–11:00 on 2025-06-02.
        Booking same time on 2025-06-03 — different day → allowed.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "amit",
            [item("physio", "priya", "2025-06-03", "10:00")],
        ))
        assert resp.status_code == 200


# ===========================================================================
# Duration correctness
# ===========================================================================

class TestDurationFromDB:

    def test_end_time_computed_from_service_duration(
        self, client: TestClient, db_conn: Connection
    ):
        """
        Confirm the API never hardcodes duration.
        Blood Test is 15 min: start 08:00 → end must be 08:15.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "kavita",
            [item("blood", "sunita", "2025-06-10", "08:00")],
        ))
        assert resp.status_code == 200
        assert resp.json()["bookings"][0]["end_time"] == "08:15"

    def test_post_surgery_90min_end_time_correct(
        self, client: TestClient, db_conn: Connection
    ):
        """
        Post-Surgery Care is 90 min: start 08:00 → end must be 09:30.
        """
        insert_seed_data(db_conn)
        resp = client.post("/cart/checkout", json=checkout_payload(
            "neha",
            [item("post_surgery", "rahul", "2025-06-10", "08:00")],
        ))
        assert resp.status_code == 200
        assert resp.json()["bookings"][0]["end_time"] == "09:30"
