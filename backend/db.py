"""SQLite storage for the backend: registered users and their per-user seen-item dedup.

SQLite is deliberately the starting point here, not Postgres — this is a first pass to
prove out the hosted-keys architecture, not a production deployment. The schema is plain
enough to move to Postgres later without changes beyond the connection setup.
"""
import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path

# Overridable so a deploy can point this at a mounted persistent volume
# (e.g. DB_PATH=/data/backend.db on Railway) instead of the app's own
# directory, which typically isn't the durable part of a container image.
DB_PATH = Path(os.environ.get("DB_PATH", str(Path(__file__).parent / "backend.db")))

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT UNIQUE NOT NULL,
    email TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS seen_items (
    user_id INTEGER NOT NULL REFERENCES users(id),
    url TEXT NOT NULL,
    seen_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, url)
);
"""


@contextmanager
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with get_db() as conn:
        conn.executescript(SCHEMA)
