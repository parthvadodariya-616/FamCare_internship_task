"""
conftest.py
-----------
Creates a separate test database (famcare_test), applies the full schema
from the seed SQL file's DDL section only (no seed data), then provides
each test with an isolated connection that is rolled back after the test.

Requirements:
  - PostgreSQL running locally
  - A superuser (postgres) that can CREATE DATABASE
  - The famcare_seed.sql file at the project root

Run tests:
  cd backend/
  pytest tests/ -v
"""

import os
import re
import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Connection
from fastapi.testclient import TestClient

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

BASE_DB_URL  = "postgresql://postgres:postgres@localhost:5432/postgres"
TEST_DB_NAME = "famcare_test"
TEST_DB_URL  = f"postgresql://postgres:postgres@localhost:5432/{TEST_DB_NAME}"

# Path to seed SQL (go up one level from tests/)
SEED_SQL_PATH = os.path.join(os.path.dirname(__file__), "..", "famcare_seed.sql")


# ---------------------------------------------------------------------------
# Extract only DDL from seed SQL (CREATE TABLE, CREATE INDEX, CREATE EXTENSION)
# We do NOT insert seed data into the test DB — each test builds its own state.
# ---------------------------------------------------------------------------

def _extract_ddl(sql_path: str) -> str:
    with open(sql_path, "r") as f:
        raw = f.read()

    # Keep everything up to (not including) the first INSERT INTO
    ddl_only = re.split(r"(?i)\bINSERT\b", raw, maxsplit=1)[0]
    return ddl_only.strip()


# ---------------------------------------------------------------------------
# Session-scoped: create test DB once for the entire test run
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session", autouse=True)
def create_test_database():
    """Create famcare_test database if it doesn't exist, apply DDL."""
    admin_engine = create_engine(
        BASE_DB_URL,
        isolation_level="AUTOCOMMIT",
    )
    with admin_engine.connect() as conn:
        exists = conn.execute(
            text("SELECT 1 FROM pg_database WHERE datname = :name"),
            {"name": TEST_DB_NAME},
        ).fetchone()
        if not exists:
            conn.execute(text(f'CREATE DATABASE "{TEST_DB_NAME}"'))
    admin_engine.dispose()

    # Apply DDL to the test DB
    test_engine = create_engine(TEST_DB_URL)
    ddl = _extract_ddl(SEED_SQL_PATH)
    with test_engine.begin() as conn:
        conn.execute(text(ddl))
    test_engine.dispose()

    yield

    # Teardown: drop test DB after all tests finish
    admin_engine = create_engine(BASE_DB_URL, isolation_level="AUTOCOMMIT")
    with admin_engine.connect() as conn:
        # Terminate other connections first
        conn.execute(text(f"""
            SELECT pg_terminate_backend(pid)
            FROM   pg_stat_activity
            WHERE  datname = '{TEST_DB_NAME}' AND pid <> pg_backend_pid()
        """))
        conn.execute(text(f'DROP DATABASE IF EXISTS "{TEST_DB_NAME}"'))
    admin_engine.dispose()


# ---------------------------------------------------------------------------
# Function-scoped: each test gets a fresh connection that rolls back at the end
# ---------------------------------------------------------------------------

@pytest.fixture()
def db_conn():
    """
    Yields a connection inside a SAVEPOINT so every test is fully isolated.
    The outer transaction is never committed — rolled back after each test.
    """
    engine = create_engine(TEST_DB_URL)
    connection = engine.connect()
    transaction = connection.begin()

    yield connection

    transaction.rollback()
    connection.close()
    engine.dispose()


# ---------------------------------------------------------------------------
# FastAPI TestClient using the same isolated connection
# ---------------------------------------------------------------------------

@pytest.fixture()
def client(db_conn):
    """TestClient with the test DB connection injected via dependency override."""
    from app.main import app
    from app.database import get_db

    def override_get_db():
        yield db_conn

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Seed helpers — insert minimal data inside individual tests
# ---------------------------------------------------------------------------

SERVICE_IDS = {
    "physio":        "a1000000-0000-0000-0000-000000000001",
    "wound":         "a1000000-0000-0000-0000-000000000002",
    "blood":         "a1000000-0000-0000-0000-000000000003",
    "iv":            "a1000000-0000-0000-0000-000000000004",
    "post_surgery":  "a1000000-0000-0000-0000-000000000005",
    "elderly":       "a1000000-0000-0000-0000-000000000006",
}

CAREGIVER_IDS = {
    "priya":   "b1000000-0000-0000-0000-000000000001",
    "rahul":   "b1000000-0000-0000-0000-000000000002",
    "anjali":  "b1000000-0000-0000-0000-000000000003",
    "deepak":  "b1000000-0000-0000-0000-000000000004",
    "sunita":  "b1000000-0000-0000-0000-000000000005",
}

PATIENT_IDS = {
    "amit":   "c1000000-0000-0000-0000-000000000001",
    "neha":   "c1000000-0000-0000-0000-000000000002",
    "ramesh": "c1000000-0000-0000-0000-000000000003",
    "kavita": "c1000000-0000-0000-0000-000000000004",
}


def insert_seed_data(conn: Connection):
    """
    Insert the full seed dataset from famcare_seed.sql into the test DB.
    Call this at the start of any test that needs existing bookings.
    """
    seed_sql = open(SEED_SQL_PATH).read()
    # Extract only INSERT statements
    inserts = re.findall(
        r"(INSERT INTO [\s\S]+?);",
        seed_sql,
        re.IGNORECASE,
    )
    for stmt in inserts:
        conn.execute(text(stmt))
