"""SQLite storage for the backend: registered users and their per-user seen-item dedup.

SQLite is deliberately the starting point here, not Postgres — this is a first pass to
prove out the hosted-keys architecture, not a production deployment. The schema is plain
enough to move to Postgres later without changes beyond the connection setup.
"""
import hashlib
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
    api_key_hash TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    email_verified INTEGER NOT NULL DEFAULT 0,
    verify_token TEXT,
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
    # Existing accounts predate verification and can't retroactively prove
    # ownership — grandfathered in as verified. Fresh installs (SCHEMA above)
    # default new users to 0, requiring verification from day one.
    ("email_verified", "INTEGER NOT NULL DEFAULT 1"),
    ("verify_token", "TEXT"),
    # Existing rows still have their real key in the old plaintext `api_key` column
    # (kept, unused otherwise) until _backfill_api_key_hashes() below hashes it in.
    ("api_key_hash", "TEXT"),
]


def _backfill_api_key_hashes(conn: sqlite3.Connection) -> None:
    """One-time migration: existing rows from before API keys were hashed still have
    their real key in the old plaintext `api_key` column and no `api_key_hash` yet.
    Hashes it in place so require_user() can look up by hash for every row, old or new.
    No-op on a fresh install (SCHEMA already only has api_key_hash, so `api_key` won't
    exist as a column and PRAGMA table_info won't list it)."""
    columns = {row["name"] for row in conn.execute("PRAGMA table_info(users)")}
    if "api_key" not in columns:
        return
    rows = conn.execute(
        "SELECT id, api_key FROM users WHERE api_key_hash IS NULL AND api_key IS NOT NULL"
    ).fetchall()
    for row in rows:
        key_hash = hashlib.sha256(row["api_key"].encode("utf-8")).hexdigest()
        conn.execute("UPDATE users SET api_key_hash = ? WHERE id = ?", (key_hash, row["id"]))


def _create_unique_index(conn: sqlite3.Connection, name: str, column: str) -> None:
    """CREATE UNIQUE INDEX works retroactively on an existing table (unlike adding a
    UNIQUE constraint via ALTER TABLE, which SQLite doesn't support without a full table
    rebuild). Fails if the column already has duplicate values — logs a warning and
    keeps starting up rather than crashing, since a first pass with unknown existing
    data shouldn't take the whole server down over it; duplicates need manual cleanup."""
    try:
        conn.execute(f"CREATE UNIQUE INDEX IF NOT EXISTS {name} ON users({column})")
    except sqlite3.IntegrityError as e:
        print(f"WARNING: couldn't enforce uniqueness on users.{column} ({e}) — "
              f"there are existing duplicate values that need manual cleanup.")


def _warn_if_db_path_looks_ephemeral() -> None:
    """Best-effort self-check, since nothing else can confirm this from inside the
    repo: if this process is running on Railway (any RAILWAY_* env var present) but
    DB_PATH is still the in-container default rather than a path under a mounted
    volume, every redeploy silently wipes every user's account, CV, and history.
    Loud stdout warning at startup rather than a config assert, since a misconfigured
    volume shouldn't be fatal — it should be impossible to miss in the deploy logs."""
    on_railway = any(k.startswith("RAILWAY_") for k in os.environ)
    if on_railway and "DB_PATH" not in os.environ:
        print(
            "WARNING: running on Railway but DB_PATH is not set — the database is "
            "living inside the container's own filesystem and WILL be wiped on the "
            "next redeploy. Set DB_PATH to a path under a mounted Railway volume "
            "(e.g. /data/backend.db) to persist it."
        )


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
    _warn_if_db_path_looks_ephemeral()
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
        _backfill_api_key_hashes(conn)
        _create_unique_index(conn, "idx_users_email", "email")
        _create_unique_index(conn, "idx_users_api_key_hash", "api_key_hash")
