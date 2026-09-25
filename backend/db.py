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
    email TEXT UNIQUE NOT NULL,
    email_verified INTEGER NOT NULL DEFAULT 0,
    verify_token TEXT,
    -- Short-lived (see PAIRING_CODE_TTL_SECONDS in backend/app.py), single-use pairing
    -- code — lets an already-connected device hand a new device access without an email
    -- round-trip. Unlike device_keys.key_hash (the permanent credential), a short code is
    -- an acceptable tradeoff here specifically because it expires fast and locks out
    -- after a few wrong guesses (pairing_code_attempts).
    pairing_code TEXT,
    pairing_code_expires_at INTEGER,
    pairing_code_attempts INTEGER NOT NULL DEFAULT 0,
    -- Personal profile: full_name/phone/location/linkedin_url are reference fields for
    -- the user's own use when filling out application forms elsewhere, not fed into AI
    -- drafting (except full_name, for signing cover letters). work_history/education/
    -- skills are what actually grounds /api/materials — structured in place of the old
    -- single freeform cv_text blob, so the AI gets cleaner context per category.
    full_name TEXT NOT NULL DEFAULT '',
    phone TEXT NOT NULL DEFAULT '',
    location TEXT NOT NULL DEFAULT '',
    linkedin_url TEXT NOT NULL DEFAULT '',
    work_history TEXT NOT NULL DEFAULT '',
    education TEXT NOT NULL DEFAULT '',
    skills TEXT NOT NULL DEFAULT '',
    plan TEXT NOT NULL DEFAULT 'free',
    slack_webhook_url TEXT NOT NULL DEFAULT '',
    telegram_chat_id TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- One row per connected device/app-install, not per account — an account can have
-- many. Registering a new device for an already-verified account adds a row here
-- rather than replacing one, so e.g. mobile and desktop can both stay connected to
-- the same account at once instead of each new connection logging the others out.
CREATE TABLE IF NOT EXISTS device_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id),
    key_hash TEXT UNIQUE NOT NULL,
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
    # Legacy step-stone column — existing rows' freeform CV text moves from here into
    # the new work_history column (see _migrate_cv_text_to_profile() below). Left in
    # place afterward, unused; new installs never have this column at all.
    ("cv_text", "TEXT NOT NULL DEFAULT ''"),
    ("full_name", "TEXT NOT NULL DEFAULT ''"),
    ("phone", "TEXT NOT NULL DEFAULT ''"),
    ("location", "TEXT NOT NULL DEFAULT ''"),
    ("linkedin_url", "TEXT NOT NULL DEFAULT ''"),
    ("work_history", "TEXT NOT NULL DEFAULT ''"),
    ("education", "TEXT NOT NULL DEFAULT ''"),
    ("skills", "TEXT NOT NULL DEFAULT ''"),
    ("plan", "TEXT NOT NULL DEFAULT 'free'"),
    ("slack_webhook_url", "TEXT NOT NULL DEFAULT ''"),
    ("telegram_chat_id", "TEXT NOT NULL DEFAULT ''"),
    # Existing accounts predate verification and can't retroactively prove
    # ownership — grandfathered in as verified. Fresh installs (SCHEMA above)
    # default new users to 0, requiring verification from day one.
    ("email_verified", "INTEGER NOT NULL DEFAULT 1"),
    ("verify_token", "TEXT"),
    # Legacy step-stone column — existing rows' real key moves from plaintext `api_key`
    # through here and into device_keys (see _backfill_api_key_hashes() and
    # _migrate_api_key_hash_to_device_keys() below). Left in place afterward, unused.
    ("api_key_hash", "TEXT"),
    ("pairing_code", "TEXT"),
    ("pairing_code_expires_at", "INTEGER"),
    ("pairing_code_attempts", "INTEGER NOT NULL DEFAULT 0"),
]


def _backfill_api_key_hashes(conn: sqlite3.Connection) -> None:
    """One-time migration: rows from before API keys were hashed still have their real
    key in the old plaintext `api_key` column and no `api_key_hash` yet. Hashes it in
    place — a stepping stone for _migrate_api_key_hash_to_device_keys() below, which
    does the actual move to the per-device table. No-op on a fresh install or one that's
    already past this point (no `api_key` column left to read)."""
    columns = {row["name"] for row in conn.execute("PRAGMA table_info(users)")}
    if "api_key" not in columns:
        return
    rows = conn.execute(
        "SELECT id, api_key FROM users WHERE api_key_hash IS NULL AND api_key IS NOT NULL"
    ).fetchall()
    for row in rows:
        key_hash = hashlib.sha256(row["api_key"].encode("utf-8")).hexdigest()
        conn.execute("UPDATE users SET api_key_hash = ? WHERE id = ?", (key_hash, row["id"]))


def _migrate_api_key_hash_to_device_keys(conn: sqlite3.Connection) -> None:
    """One-time migration: rows from before per-device keys existed have their one key
    in the now-legacy `users.api_key_hash` column (itself populated either originally,
    or just now by _backfill_api_key_hashes() above). Copies it into device_keys so that
    whatever device is already using it keeps working under the new per-device model.
    The legacy column is left in place afterward, harmlessly unused — no-op on a fresh
    install, which never has an `api_key_hash` column on `users` at all."""
    columns = {row["name"] for row in conn.execute("PRAGMA table_info(users)")}
    if "api_key_hash" not in columns:
        return
    rows = conn.execute("SELECT id, api_key_hash FROM users WHERE api_key_hash IS NOT NULL").fetchall()
    for row in rows:
        exists = conn.execute(
            "SELECT 1 FROM device_keys WHERE key_hash = ?", (row["api_key_hash"],)
        ).fetchone()
        if not exists:
            conn.execute(
                "INSERT INTO device_keys (user_id, key_hash) VALUES (?, ?)",
                (row["id"], row["api_key_hash"]),
            )


def _migrate_cv_text_to_profile(conn: sqlite3.Connection) -> None:
    """One-time migration: rows from before the personal-profile split still have their
    freeform CV/background text in the now-legacy `cv_text` column. Can't intelligently
    split unstructured text into work history vs. education vs. skills, so it all moves
    into work_history — the closest single bucket — leaving education/skills for the
    user to fill in themselves. Legacy column is left in place afterward, unused; no-op
    on a fresh install, which never has a `cv_text` column at all."""
    columns = {row["name"] for row in conn.execute("PRAGMA table_info(users)")}
    if "cv_text" not in columns:
        return
    rows = conn.execute(
        "SELECT id, cv_text FROM users WHERE work_history = '' AND cv_text != ''"
    ).fetchall()
    for row in rows:
        conn.execute("UPDATE users SET work_history = ? WHERE id = ?", (row["cv_text"], row["id"]))


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
        _migrate_api_key_hash_to_device_keys(conn)
        _migrate_cv_text_to_profile(conn)
        _create_unique_index(conn, "idx_users_email", "email")
