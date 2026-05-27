"""
FamCARE Backend — Multi-Service Bulk Scheduler
FastAPI + SQLAlchemy Core + PostgreSQL

Swagger UI  : http://localhost:8000/docs
ReDoc        : http://localhost:8000/redoc
OpenAPI JSON : http://localhost:8000/openapi.json
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import (
    slots_router,
    services_router,
    cart_router,
    patients_router,
    caregivers_router,
)

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="FamCARE Booking API",
    description="""
## FamCARE — Multi-Service Bulk Scheduler

A home healthcare booking engine that lets patients book **multiple services
across multiple days in a single atomic checkout**.

### Key Guarantees
- **No partial bookings** — either every slot in the cart is confirmed or none are.
- **Full-duration conflict detection** — a 60-min slot at 10:00 blocks until 11:00,
  not just the start time.
- **Caregiver + Patient conflict detection** — both sides are checked before any
  insert is committed.
- **15-min aligned slots** — all slot boundaries are enforced at DB and API level.
- **Duration from DB** — service duration is never hardcoded in application code.

### Typical Flutter flow
1. `GET /services` — populate service picker
2. `GET /slots/available?service_id=&date=` — populate time slot picker
3. Build cart locally, repeat step 2 for each additional service
4. `POST /cart/checkout` — submit entire cart atomically

### Design decision — pessimistic locking
Checkout uses `SELECT FOR UPDATE` inside a single PostgreSQL transaction.
Two concurrent requests for the same caregiver slot will serialize —
the second one will see the first's lock and return a conflict error,
never a phantom double-booking.
""",
    version="1.0.0",
    contact={
        "name": "FamCARE Engineering",
        "email": "dev@famcare.in",
    },
    license_info={
        "name": "Private",
    },
    docs_url="/docs",       # Swagger UI
    redoc_url="/redoc",     # ReDoc
    openapi_url="/openapi.json",
)

# ---------------------------------------------------------------------------
# CORS — allow Flutter app (any local origin during development)
# ---------------------------------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],        # tighten this in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------

app.include_router(services_router)
app.include_router(slots_router)
app.include_router(cart_router)
app.include_router(patients_router)
app.include_router(caregivers_router)


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@app.get("/health", tags=["Health"], summary="Health check")
def health():
    """Returns 200 OK when the server is running."""
    return {"status": "ok", "service": "FamCARE Booking API"}
