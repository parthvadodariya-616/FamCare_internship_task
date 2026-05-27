from sqlalchemy import create_engine, text
from sqlalchemy.pool import QueuePool
from contextlib import contextmanager
from typing import Generator

from app.config import settings

# ---------------------------------------------------------------------------
# Engine
# ---------------------------------------------------------------------------
engine = create_engine(
    settings.DATABASE_URL,
    poolclass=QueuePool,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,      # drops stale connections before using them
    echo=False,              # set True to log every SQL statement
)


# ---------------------------------------------------------------------------
# Context manager — use in services
# ---------------------------------------------------------------------------
@contextmanager
def get_connection():
    """
    Yields a raw DBAPI connection inside a transaction.
    Commits on clean exit, rolls back on any exception.
    """
    with engine.begin() as conn:
        yield conn


# ---------------------------------------------------------------------------
# FastAPI dependency — use in routers
# ---------------------------------------------------------------------------
def get_db() -> Generator:
    """
    FastAPI dependency that yields a SQLAlchemy connection.
    engine.begin() auto-commits on exit and rolls back on exception.
    """
    with engine.begin() as conn:
        yield conn
