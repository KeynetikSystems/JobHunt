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
    cv_text TEXT NOT NULL DEFAULT '',
    plan TEXT NOT NULL DEFAULT 'free',
    slack_webhook_url TEXT NOT NULL DEFAULT '',
    telegram_chat_id TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS seen_items (
    user_id INTEGER NOT NULL REFERENCES users(id),
    url TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'job',
    title TEXT,
    firm TEXT,
    seniority TEXT,
    note TEXT,
    headline TEXT,
    source TEXT,
    summary TEXT,
    seen_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, url)
);

-- One row per rate-limited action performed, used to enforce free-plan usage caps
-- (e.g. AI application-material drafts per day) without a separate billing system.
CREATE TABLE IF NOT EXISTS usage_log (
    user_id INTEGER NOT NULL REFERENCES users(id),
    action TEXT NOT NULL,
    used_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Self-serve "I want premium" signal, captured instead of building real billing
-- before there's evidence anyone wants it. A human reviews these and flips plan
-- to 'premium' by hand.
CREATE TABLE IF NOT EXISTS upgrade_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    note TEXT NOT NULL DEFAULT '',
    requested_at TEXT NOT NULL DEFAULT (datetime('now'))
);
"""

# Columns added after the initial release. CREATE TABLE IF NOT EXISTS above only
# covers fresh databases, so existing ones (like a deployed backend.db) need these
# added by hand — this keeps the history feature working without a manual migration.
_SEEN_ITEMS_MIGRATIONS = [
    ("kind", "TEXT NOT NULL DEFAULT 'job'"),
    ("title", "TEXT"),
    ("firm", "TEXT"),
    ("seniority", "TEXT"),
    ("note", "TEXT"),
    ("headline", "TEXT"),
    ("source", "TEXT"),
    ("summary", "TEXT"),
]

_USERS_MIGRATIONS = [
    ("cv_text", "TEXT NOT NULL DEFAULT ''"),
    ("plan", "TEXT NOT NULL DEFAULT 'free'"),
    ("slack_webhook_url", "TEXT NOT NULL DEFAULT ''"),
    ("telegram_chat_id", "TEXT NOT NULL DEFAULT ''"),
]


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
        existing = {row["name"] for row in conn.execute("PRAGMA table_info(seen_items)")}
        for name, coltype in _SEEN_ITEMS_MIGRATIONS:
            if name not in existing:
                conn.execute(f"ALTER TABLE seen_items ADD COLUMN {name} {coltype}")
        existing_users = {row["name"] for row in conn.execute("PRAGMA table_info(users)")}
        for name, coltype in _USERS_MIGRATIONS:
            if name not in existing_users:
                conn.execute(f"ALTER TABLE users ADD COLUMN {name} {coltype}")
