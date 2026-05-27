from __future__ import annotations

from datetime import date, time
from decimal import Decimal
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


# ===========================================================================
# Shared / utility
# ===========================================================================

class TimeStr(BaseModel):
    """HH:MM string helper — we serialise time as string for JSON clarity."""
    pass


# ===========================================================================
# Service schemas
# ===========================================================================

class ServiceOut(BaseModel):
    id:               UUID
    name:             str
    duration_minutes: int
    price:            Decimal
    description:      str
    is_active:        bool

    model_config = {"from_attributes": True}


# ===========================================================================
# Caregiver schemas
# ===========================================================================

class CaregiverOut(BaseModel):
    id:    UUID
    name:  str
    email: str
    phone: str

    model_config = {"from_attributes": True}


# ===========================================================================
# Patient schemas
# ===========================================================================

class PatientOut(BaseModel):
    id:    UUID
    name:  str
    email: str
    phone: str

    model_config = {"from_attributes": True}


# ===========================================================================
# Slot availability schemas
# ===========================================================================

class AvailableSlot(BaseModel):
    """Single available time slot returned by GET /slots/available."""
    start_time:          str = Field(..., examples=["10:00"],
                                     description="Slot start time in HH:MM format")
    end_time:            str = Field(..., examples=["11:00"],
                                     description="Slot end time in HH:MM format")
    available_caregivers: List[CaregiverOut] = Field(
        ..., description="Caregivers who are free for this entire window"
    )


class SlotAvailabilityResponse(BaseModel):
    service_id:       UUID
    service_name:     str
    duration_minutes: int
    date:             date
    slots:            List[AvailableSlot]


# ===========================================================================
# Checkout schemas
# ===========================================================================

class CartItem(BaseModel):
    """One item the patient wants to book."""
    service_id:   UUID = Field(..., description="UUID of the service")
    caregiver_id: UUID = Field(..., description="UUID of the chosen caregiver")
    booking_date: date = Field(..., description="Date for this booking (YYYY-MM-DD)")
    start_time:   str  = Field(..., examples=["10:00"],
                               description="Start time in HH:MM (15-min aligned)")

    @field_validator("start_time")
    @classmethod
    def validate_start_time(cls, v: str) -> str:
        try:
            t = time.fromisoformat(v)
        except ValueError:
            raise ValueError("start_time must be in HH:MM format")
        if t.minute % 15 != 0 or t.second != 0:
            raise ValueError("start_time must align to a 15-minute boundary (e.g. 09:00, 09:15)")
        return v


class CheckoutRequest(BaseModel):
    patient_id: UUID            = Field(..., description="UUID of the patient")
    items:      List[CartItem]  = Field(..., min_length=1,
                                        description="At least one cart item required")


class BookingConfirmed(BaseModel):
    """Single confirmed booking returned after successful checkout."""
    booking_id:   UUID
    service_name: str
    caregiver_name: str
    booking_date: date
    start_time:   str
    end_time:     str
    price:        Decimal


class CheckoutSuccess(BaseModel):
    success:   bool = True
    message:   str  = "All bookings confirmed"
    bookings:  List[BookingConfirmed]
    total_price: Decimal


class CheckoutFailure(BaseModel):
    """Returned when any single item in the cart fails conflict detection."""
    success: bool = False
    message: str
    failed_item: FailedItem


class FailedItem(BaseModel):
    service_id:   UUID
    caregiver_id: UUID
    booking_date: date
    start_time:   str
    reason:       str


# Re-export so CheckoutFailure can reference FailedItem before it's defined
CheckoutFailure.model_rebuild()
