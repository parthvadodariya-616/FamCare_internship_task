-- =============================================================================
-- FamCARE — Complete Database Schema + Seed
-- PostgreSQL 14+
-- Pure SQL: no Python, no ORM, no extensions beyond uuid-ossp
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. SETUP
-- -----------------------------------------------------------------------------

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Wipe everything cleanly if re-running (order matters due to FK constraints)
DROP TABLE IF EXISTS bookings          CASCADE;
DROP TABLE IF EXISTS caregiver_services CASCADE;
DROP TABLE IF EXISTS patients          CASCADE;
DROP TABLE IF EXISTS caregivers        CASCADE;
DROP TABLE IF EXISTS services          CASCADE;

-- =============================================================================
-- 1. TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 services
--     Each service has a fixed duration (always a multiple of 15 min).
--     Duration NEVER lives in application code — only here.
-- -----------------------------------------------------------------------------
CREATE TABLE services (
    id               UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(100)  NOT NULL,
    duration_minutes INTEGER       NOT NULL CHECK (duration_minutes > 0 AND duration_minutes % 15 = 0),
    price            NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    description      TEXT          NOT NULL DEFAULT '',
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_service_name UNIQUE (name)
);

-- -----------------------------------------------------------------------------
-- 1.2 caregivers
-- -----------------------------------------------------------------------------
CREATE TABLE caregivers (
    id         UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    name       VARCHAR(100) NOT NULL,
    phone      VARCHAR(20)  NOT NULL,
    email      VARCHAR(150) NOT NULL,
    is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_caregiver_email UNIQUE (email),
    CONSTRAINT uq_caregiver_phone UNIQUE (phone)
);

-- -----------------------------------------------------------------------------
-- 1.3 caregiver_services
--     Many-to-many: which caregiver can deliver which service.
-- -----------------------------------------------------------------------------
CREATE TABLE caregiver_services (
    caregiver_id UUID NOT NULL REFERENCES caregivers(id) ON DELETE CASCADE,
    service_id   UUID NOT NULL REFERENCES services(id)   ON DELETE CASCADE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_caregiver_services PRIMARY KEY (caregiver_id, service_id)
);

-- -----------------------------------------------------------------------------
-- 1.4 patients
-- -----------------------------------------------------------------------------
CREATE TABLE patients (
    id         UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    name       VARCHAR(100) NOT NULL,
    phone      VARCHAR(20)  NOT NULL,
    email      VARCHAR(150) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_patient_email UNIQUE (email),
    CONSTRAINT uq_patient_phone UNIQUE (phone)
);

-- -----------------------------------------------------------------------------
-- 1.5 bookings
--     Core table. end_time is stored explicitly so overlap detection
--     is a pure range comparison — no join, no calculation at query time.
--
--     Overlap rule: two ranges [A_start, A_end) and [B_start, B_end) overlap
--     when A_start < B_end AND A_end > B_start.
-- -----------------------------------------------------------------------------
CREATE TABLE bookings (
    id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id   UUID        NOT NULL REFERENCES patients(id)   ON DELETE RESTRICT,
    caregiver_id UUID        NOT NULL REFERENCES caregivers(id) ON DELETE RESTRICT,
    service_id   UUID        NOT NULL REFERENCES services(id)   ON DELETE RESTRICT,
    booking_date DATE        NOT NULL,
    start_time   TIME        NOT NULL,
    end_time     TIME        NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'confirmed'
                             CHECK (status IN ('confirmed', 'cancelled')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- end_time must always be after start_time
    CONSTRAINT chk_booking_time_order CHECK (end_time > start_time),

    -- start_time must align to 15-minute grid
    CONSTRAINT chk_start_time_aligned CHECK (
        EXTRACT(MINUTE FROM start_time)::INTEGER % 15 = 0
        AND EXTRACT(SECOND FROM start_time) = 0
    )
);

-- =============================================================================
-- 2. INDEXES
--    Built for the two query patterns that matter:
--    (a) GET /slots/available  — filter by service + date, find free caregivers
--    (b) POST /cart/checkout   — detect caregiver + patient overlaps fast
-- =============================================================================

-- Caregiver conflict detection (checkout + slot availability)
CREATE INDEX idx_bookings_caregiver_date
    ON bookings (caregiver_id, booking_date)
    WHERE status = 'confirmed';

-- Patient conflict detection (checkout)
CREATE INDEX idx_bookings_patient_date
    ON bookings (patient_id, booking_date)
    WHERE status = 'confirmed';

-- Slot availability: all confirmed bookings on a date
CREATE INDEX idx_bookings_date_status
    ON bookings (booking_date, status);

-- caregiver_services lookup by service (find who can do a given service)
CREATE INDEX idx_caregiver_services_service
    ON caregiver_services (service_id);

-- =============================================================================
-- 3. SEED DATA
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3.1 Services (6 services, all durations multiples of 15)
-- -----------------------------------------------------------------------------
INSERT INTO services (id, name, duration_minutes, price, description) VALUES

    ('a1000000-0000-0000-0000-000000000001',
     'Physiotherapy',        60,  850.00,
     'Full physiotherapy session including assessment and exercise therapy'),

    ('a1000000-0000-0000-0000-000000000002',
     'Wound Dressing',       30,  350.00,
     'Professional wound cleaning, dressing and monitoring'),

    ('a1000000-0000-0000-0000-000000000003',
     'Blood Test',           15,  200.00,
     'Blood sample collection for lab analysis'),

    ('a1000000-0000-0000-0000-000000000004',
     'IV Therapy',           45,  650.00,
     'Intravenous fluid or medication administration'),

    ('a1000000-0000-0000-0000-000000000005',
     'Post-Surgery Care',    90, 1200.00,
     'Comprehensive post-operative monitoring and wound management'),

    ('a1000000-0000-0000-0000-000000000006',
     'Elderly Care Visit',   30,  400.00,
     'General wellness check and assistance for elderly patients');

-- -----------------------------------------------------------------------------
-- 3.2 Caregivers (5 caregivers)
-- -----------------------------------------------------------------------------
INSERT INTO caregivers (id, name, phone, email) VALUES

    ('b1000000-0000-0000-0000-000000000001',
     'Priya Sharma',   '+91-9876543201', 'priya.sharma@famcare.in'),

    ('b1000000-0000-0000-0000-000000000002',
     'Rahul Mehta',    '+91-9876543202', 'rahul.mehta@famcare.in'),

    ('b1000000-0000-0000-0000-000000000003',
     'Anjali Patel',   '+91-9876543203', 'anjali.patel@famcare.in'),

    ('b1000000-0000-0000-0000-000000000004',
     'Deepak Nair',    '+91-9876543204', 'deepak.nair@famcare.in'),

    ('b1000000-0000-0000-0000-000000000005',
     'Sunita Rao',     '+91-9876543205', 'sunita.rao@famcare.in');

-- -----------------------------------------------------------------------------
-- 3.3 Caregiver → Service assignments
--     Each caregiver handles 2–3 services. No caregiver is left unassigned.
--     No service is left without at least 2 caregivers (for availability).
-- -----------------------------------------------------------------------------
INSERT INTO caregiver_services (caregiver_id, service_id) VALUES

    -- Priya: Physiotherapy, Post-Surgery Care
    ('b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001'),
    ('b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000005'),

    -- Rahul: Wound Dressing, IV Therapy, Post-Surgery Care
    ('b1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000002'),
    ('b1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000004'),
    ('b1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000005'),

    -- Anjali: Blood Test, Wound Dressing, Elderly Care Visit
    ('b1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000003'),
    ('b1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000002'),
    ('b1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000006'),

    -- Deepak: Physiotherapy, IV Therapy
    ('b1000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000001'),
    ('b1000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000004'),

    -- Sunita: Blood Test, Elderly Care Visit, Wound Dressing
    ('b1000000-0000-0000-0000-000000000005', 'a1000000-0000-0000-0000-000000000003'),
    ('b1000000-0000-0000-0000-000000000005', 'a1000000-0000-0000-0000-000000000006'),
    ('b1000000-0000-0000-0000-000000000005', 'a1000000-0000-0000-0000-000000000002');

-- -----------------------------------------------------------------------------
-- 3.4 Patients (4 patients)
-- -----------------------------------------------------------------------------
INSERT INTO patients (id, name, phone, email) VALUES

    ('c1000000-0000-0000-0000-000000000001',
     'Amit Verma',     '+91-9988776601', 'amit.verma@gmail.com'),

    ('c1000000-0000-0000-0000-000000000002',
     'Neha Joshi',     '+91-9988776602', 'neha.joshi@gmail.com'),

    ('c1000000-0000-0000-0000-000000000003',
     'Ramesh Gupta',   '+91-9988776603', 'ramesh.gupta@gmail.com'),

    ('c1000000-0000-0000-0000-000000000004',
     'Kavita Singh',   '+91-9988776604', 'kavita.singh@gmail.com');

-- -----------------------------------------------------------------------------
-- 3.5 Existing Bookings (seed bookings — no conflicts among themselves)
--
--     Date used: 2025-06-02 (Monday) and 2025-06-04 (Wednesday)
--     These bookings are used by tests to verify conflict detection.
--
--     Caregiver availability on 2025-06-02:
--       Priya     → BUSY  10:00–11:00 (Physiotherapy, 60 min)
--       Rahul     → BUSY  15:00–15:30 (Wound Dressing, 30 min)
--       Anjali    → BUSY  09:00–09:15 (Blood Test, 15 min)
--       Deepak    → FREE  all day
--       Sunita    → FREE  all day
--
--     Caregiver availability on 2025-06-04:
--       Priya     → BUSY  14:00–15:30 (Post-Surgery Care, 90 min)
--       Rahul     → BUSY  11:00–11:45 (IV Therapy, 45 min)
--       Anjali    → FREE  all day
--       Deepak    → BUSY  10:00–11:00 (Physiotherapy, 60 min)
--       Sunita    → FREE  all day
--
--     Patient bookings on 2025-06-02:
--       Amit      → 10:00–11:00 (with Priya, Physiotherapy)
--       Neha      → 15:00–15:30 (with Rahul, Wound Dressing)
--       Ramesh    → 09:00–09:15 (with Anjali, Blood Test)
--
--     Patient bookings on 2025-06-04:
--       Kavita    → 14:00–15:30 (with Priya, Post-Surgery Care)
--       Amit      → 11:00–11:45 (with Rahul, IV Therapy)
--       Ramesh    → 10:00–11:00 (with Deepak, Physiotherapy)
-- -----------------------------------------------------------------------------

INSERT INTO bookings (
    id, patient_id, caregiver_id, service_id,
    booking_date, start_time, end_time, status
) VALUES

    -- 2025-06-02: Amit + Priya + Physiotherapy (10:00 → 11:00)
    (
        'd1000000-0000-0000-0000-000000000001',
        'c1000000-0000-0000-0000-000000000001',
        'b1000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000001',
        '2025-06-02', '10:00', '11:00', 'confirmed'
    ),

    -- 2025-06-02: Neha + Rahul + Wound Dressing (15:00 → 15:30)
    (
        'd1000000-0000-0000-0000-000000000002',
        'c1000000-0000-0000-0000-000000000002',
        'b1000000-0000-0000-0000-000000000002',
        'a1000000-0000-0000-0000-000000000002',
        '2025-06-02', '15:00', '15:30', 'confirmed'
    ),

    -- 2025-06-02: Ramesh + Anjali + Blood Test (09:00 → 09:15)
    (
        'd1000000-0000-0000-0000-000000000003',
        'c1000000-0000-0000-0000-000000000003',
        'b1000000-0000-0000-0000-000000000003',
        'a1000000-0000-0000-0000-000000000003',
        '2025-06-02', '09:00', '09:15', 'confirmed'
    ),

    -- 2025-06-04: Kavita + Priya + Post-Surgery Care (14:00 → 15:30)
    (
        'd1000000-0000-0000-0000-000000000004',
        'c1000000-0000-0000-0000-000000000004',
        'b1000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000005',
        '2025-06-04', '14:00', '15:30', 'confirmed'
    ),

    -- 2025-06-04: Amit + Rahul + IV Therapy (11:00 → 11:45)
    (
        'd1000000-0000-0000-0000-000000000005',
        'c1000000-0000-0000-0000-000000000001',
        'b1000000-0000-0000-0000-000000000002',
        'a1000000-0000-0000-0000-000000000004',
        '2025-06-04', '11:00', '11:45', 'confirmed'
    ),

    -- 2025-06-04: Ramesh + Deepak + Physiotherapy (10:00 → 11:00)
    (
        'd1000000-0000-0000-0000-000000000006',
        'c1000000-0000-0000-0000-000000000003',
        'b1000000-0000-0000-0000-000000000004',
        'a1000000-0000-0000-0000-000000000001',
        '2025-06-04', '10:00', '11:00', 'confirmed'
    );

-- =============================================================================
-- 4. VERIFICATION QUERIES
--    Run these after applying the seed to confirm everything is consistent.
-- =============================================================================

-- Count checks
SELECT 'services'          AS tbl, COUNT(*) AS rows FROM services
UNION ALL
SELECT 'caregivers'        AS tbl, COUNT(*) AS rows FROM caregivers
UNION ALL
SELECT 'caregiver_services'AS tbl, COUNT(*) AS rows FROM caregiver_services
UNION ALL
SELECT 'patients'          AS tbl, COUNT(*) AS rows FROM patients
UNION ALL
SELECT 'bookings'          AS tbl, COUNT(*) AS rows FROM bookings;

-- Every service has at least 2 caregivers
SELECT
    s.name          AS service,
    COUNT(cs.caregiver_id) AS caregiver_count
FROM services s
JOIN caregiver_services cs ON cs.service_id = s.id
GROUP BY s.name
ORDER BY s.name;

-- Every caregiver's bookings use only services they are assigned to
SELECT
    b.id            AS booking_id,
    c.name          AS caregiver,
    s.name          AS service,
    CASE WHEN cs.caregiver_id IS NULL THEN 'INVALID' ELSE 'OK' END AS assignment_check
FROM bookings b
JOIN caregivers c ON c.id = b.caregiver_id
JOIN services   s ON s.id = b.service_id
LEFT JOIN caregiver_services cs
    ON cs.caregiver_id = b.caregiver_id
    AND cs.service_id  = b.service_id
ORDER BY b.booking_date, b.start_time;

-- end_time = start_time + duration for all seed bookings
SELECT
    b.id            AS booking_id,
    s.name          AS service,
    b.start_time,
    b.end_time,
    (b.start_time + (s.duration_minutes || ' minutes')::INTERVAL)::TIME AS expected_end,
    CASE
        WHEN b.end_time = (b.start_time + (s.duration_minutes || ' minutes')::INTERVAL)::TIME
        THEN 'OK'
        ELSE 'MISMATCH'
    END AS time_check
FROM bookings b
JOIN services s ON s.id = b.service_id
ORDER BY b.booking_date, b.start_time;

-- No caregiver has overlapping confirmed bookings
SELECT
    a.caregiver_id,
    c.name          AS caregiver,
    a.booking_date,
    a.start_time    AS a_start, a.end_time AS a_end,
    b.start_time    AS b_start, b.end_time AS b_end,
    'OVERLAP DETECTED' AS problem
FROM bookings a
JOIN bookings b
    ON  a.caregiver_id  = b.caregiver_id
    AND a.booking_date  = b.booking_date
    AND a.id            < b.id
    AND a.start_time    < b.end_time
    AND a.end_time      > b.start_time
    AND a.status        = 'confirmed'
    AND b.status        = 'confirmed'
JOIN caregivers c ON c.id = a.caregiver_id;
-- Zero rows expected. Any row here means seed data is broken.

-- No patient has overlapping confirmed bookings on the same day
SELECT
    a.patient_id,
    p.name          AS patient,
    a.booking_date,
    a.start_time    AS a_start, a.end_time AS a_end,
    b.start_time    AS b_start, b.end_time AS b_end,
    'OVERLAP DETECTED' AS problem
FROM bookings a
JOIN bookings b
    ON  a.patient_id   = b.patient_id
    AND a.booking_date = b.booking_date
    AND a.id           < b.id
    AND a.start_time   < b.end_time
    AND a.end_time     > b.start_time
    AND a.status       = 'confirmed'
    AND b.status       = 'confirmed'
JOIN patients p ON p.id = a.patient_id;
-- Zero rows expected.