# FamCARE — Multi-Service Home Healthcare Scheduler

FamCARE is a full-stack demo for booking home healthcare services. The Flutter app lets a patient select services and time slots, add multiple items to a cart, and perform an atomic checkout. The FastAPI backend enforces full-duration conflict checks for both caregivers and patients, and PostgreSQL stores the scheduling data.

## Repository structure

```
FamCare_internship_task/
├── fam_care/           # Flutter mobile app
├── famcare_backend/    # FastAPI backend + PostgreSQL schema
└── assets/             # Shared assets (not used directly by the app)
```

## Key features

- Multi-service cart with atomic checkout (all-or-nothing bookings)
- 15-minute aligned slot windows (08:00–20:00)
- Full-duration conflict detection for both caregivers and patients
- FastAPI + SQLAlchemy Core backend
- Riverpod + Dio Flutter frontend

---

# Backend (FastAPI + PostgreSQL)

## Backend setup (local)

### 1) Create and activate a virtual environment

```bash
cd famcare_backend
python -m venv .venv
```

Windows PowerShell:
```powershell
.\.venv\Scripts\Activate
```

macOS / Linux:
```bash
source .venv/bin/activate
```

### 2) Install Python dependencies

```bash
pip install -r requirements.txt
```

### 3) Set up PostgreSQL (local)

Install PostgreSQL 14+ and ensure the `psql` CLI is available.

Create a database and apply the schema + seed file stored in `database/famcare_database.sql`:

```bash
psql -U postgres -c "CREATE DATABASE famcare;"
psql -U postgres -d famcare -f database/famcare_database.sql
```

Notes:
- The SQL file enables the `uuid-ossp` extension.
- It wipes and recreates all tables, then inserts seed data (services, caregivers, patients, bookings).

### 4) Configure environment variables

Create a `.env` file inside `famcare_backend/`:

```
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/famcare
```

Update the username/password/host/port if your local Postgres settings differ.

### 5) Run the backend

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Open API docs:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Backend API endpoints

| Method | Endpoint | Purpose |
| ------ | -------- | ------- |
| GET | `/health` | Health check |
| GET | `/services` | List all active services |
| GET | `/slots/available?service_id=&date=` | Available slots for a service on a date |
| GET | `/patients` | List all patients |
| GET | `/caregivers` | List all active caregivers |
| POST | `/cart/checkout` | Atomic multi-slot checkout |

## Backend code guide

- `app/main.py` — FastAPI app configuration, CORS, route registration
- `app/config.py` — `.env` loading and `DATABASE_URL`
- `app/database.py` — SQLAlchemy engine + connection helpers
- `app/models/tables.py` — SQLAlchemy Core table definitions
- `app/schemas/schemas.py` — Pydantic request/response models
- `app/routers/slots.py` — `/services` and `/slots/available` endpoints
- `app/routers/cart.py` — `/cart/checkout`, `/patients`, `/caregivers`
- `app/services/slot_service.py` — slot generation + availability logic
- `app/services/booking_service.py` — atomic checkout and conflict detection
- `database/famcare_database.sql` — full schema + seed data
- `tests/` — pytest suite for conflict and checkout behavior

## Backend tests

Tests expect a seed SQL file named `famcare_seed.sql` at the backend root (see `tests/conftest.py`). The repo currently contains `database/famcare_database.sql`, so copy it before running tests:

Windows:
```powershell
copy database\famcare_database.sql famcare_seed.sql
```

macOS / Linux:
```bash
cp database/famcare_database.sql famcare_seed.sql
```

Run tests:
```bash
pytest -v
```

---

# Frontend (Flutter)

## Frontend setup (local)

### 1) Install Flutter

- Install Flutter SDK (3.3+)
- Run `flutter doctor` and fix any missing dependencies

### 2) Add Tabler Icons font

Download `tabler-icons.ttf` from:
https://github.com/tabler/tabler-icons/releases

Place it here:

```
fam_care/assets/fonts/tabler-icons.ttf
```

### 3) Set backend URL

Edit `fam_care/lib/config/app_config.dart` and set `baseUrl` for your device:

```dart
// Android emulator
static const String baseUrl = 'http://10.0.2.2:8000';

// Physical device (use your laptop's LAN IP)
static const String baseUrl = 'http://192.168.1.X:8000';

// iOS simulator
static const String baseUrl = 'http://localhost:8000';
```

### 4) Install dependencies and run

```bash
cd fam_care
flutter pub get
flutter run
```

## Frontend code guide

### Core

- `lib/main.dart` — app entry point
- `lib/config/app_config.dart` — backend URL and app constants
- `lib/config/theme.dart` — UI theme and colors
- `lib/services/api_service.dart` — all HTTP calls to the backend

### State management (Riverpod)

- `lib/providers/services_provider.dart` — fetch services
- `lib/providers/slots_provider.dart` — fetch available slots by service/date
- `lib/providers/patients_provider.dart` — fetch patients
- `lib/providers/cart_notifier.dart` — local cart + conflict pre-checks

### Models

- `lib/models/service_model.dart` — service data
- `lib/models/caregiver_model.dart` — caregiver data
- `lib/models/slot_model.dart` — slot availability response
- `lib/models/booking_model.dart` — cart items + checkout responses + patient model

### Screens

- `lib/screens/patient_select_screen.dart` — patient picker (loads from API)
- `lib/screens/main_shell.dart` — bottom nav shell (Home, Services, Cart, Profile)
- `lib/screens/home_screen.dart` — dashboard and quick actions
- `lib/screens/services_screen.dart` — list of services
- `lib/screens/slot_picker_screen.dart` — date strip + slot grid + caregiver list
- `lib/screens/cart_screen.dart` — cart review + checkout
- `lib/screens/checkout_result_screen.dart` — success or conflict message
- `lib/screens/profile_screen.dart` — patient profile

### Reusable widgets

- `lib/widgets/fc_badge.dart` — colored status badge
- `lib/widgets/fc_card.dart` — reusable tappable card
- `lib/widgets/fc_error_banner.dart` — inline error with retry
- `lib/widgets/fc_loading.dart` — loading states and shimmer
- `lib/widgets/fc_icons.dart` — Tabler icon codepoints

## App flow

```
Patient Select → Main Shell
                    ├── Home
                    ├── Services → Slot Picker → (add to cart)
                    ├── Cart → Checkout Result
                    └── Profile
```

---

# Database details

The PostgreSQL schema and seed data live in `famcare_backend/database/famcare_database.sql`.

Tables:
- `services` — name, duration, price, active flag
- `caregivers` — basic caregiver profiles
- `caregiver_services` — many-to-many mapping (caregiver qualification)
- `patients` — patient profiles
- `bookings` — confirmed bookings with explicit `start_time` and `end_time`

Rules enforced at the DB level:
- `duration_minutes` must be a multiple of 15
- `start_time` must be aligned to a 15-minute boundary
- `end_time` must be greater than `start_time`
- Bookings are indexed for fast conflict detection

---

# App previews (replace these PNGs)

Place your screenshots here and keep the exact filenames. You can replace the PNGs later without changing this README.

```
assets/
├── _patient_select.png
├── _home.png
├── _services.png
├── _slot_picker.png
├── _cart.png
├── _checkout_result.png
├── _profile.png
└── thumbnail.png
```


1. Patient Select screen

    <img src="assets/_patient_select.png" alt="Patient Select" width="260" />

2. Home screen

    <img src="assets/_home.png" alt="Home" width="260" />

3. Services screen

    <img src="assets/_services.png" alt="Services" width="260" />

4. Slot Picker screen

    <img src="assets/_slot_picker.png" alt="Slot Picker" width="260" />

5. Cart screen

    <img src="assets/_cart.png" alt="Cart" width="260" />

6. Checkout Result screen

    <img src="assets/_checkout_result.png" alt="Checkout Result" width="260" />

7. Profile screen

    <img src="assets/_profile.png" alt="Profile" width="260" />

---

## Design

- Figma community file: [Figma design](https://www.figma.com/community/file/1641456613578851901)
- Thumbnail (included in repo): ![Figma Thumbnail](assets/thumbnail.png)


