"""API-key auth. Deliberately simple for a first pass — one header, one lookup.
No billing gate yet; /api/register hands out a key immediately, but it only works
once the email it was issued for is verified (require_verified_user) — otherwise
anyone could register under an address they don't own to bypass free-tier caps or
have digests emailed to someone who never asked for them.

Keys are stored only as a SHA-256 hash (device_keys.key_hash) — the raw key is shown to
the caller exactly once, at issuance, and never persisted. A high-entropy token like
this (128 bits from secrets.token_hex(16)) doesn't need a slow/salted password hash; it
needs a fast one-way lookup, which SHA-256 provides. This means a database leak alone no
longer hands out working credentials for every account.

One row per connected device, not per account — see device_keys in db.py. Registering a
new device for an already-verified account adds a key rather than replacing the old one,
so multiple devices can stay connected to the same account at once.
"""
import hashlib
import secrets

from fastapi import Depends, Header, HTTPException

import db


def generate_api_key() -> str:
    # 128 bits of entropy (secrets.token_hex(16)), grouped into readable 4-char chunks.
    # This is the entire auth credential — there's no password behind it — so it needs
    # real cryptographic strength, not just typability. It's delivered by email and meant
    # to be copy-pasted (see the "Access Key" field's own hint text), not hand-typed
    # character by character, so length isn't a real UX cost — only an earlier version of
    # this function (secrets.token_hex(4), 32 bits) traded strength for typability; that
    # was a real vulnerability (brute-forceable via offline SHA-256, no rate limiting),
    # fixed here before it reached production (the weak version was never deployed).
    raw = secrets.token_hex(16).upper()
    groups = [raw[i:i + 4] for i in range(0, len(raw), 4)]
    return "JH-" + "-".join(groups)


def hash_api_key(key: str) -> str:
    # Normalize key (strip spaces/hyphens, uppercase) so formats like 'jh-4f2a-9b1c' and 'JH4F2A9B1C' match
    normalized = key.strip().upper().replace("-", "").replace(" ", "")
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def generate_verify_token() -> str:
    return secrets.token_urlsafe(24)


def generate_pairing_code() -> str:
    # Short and typeable on purpose — unlike generate_api_key() above, this is single-use,
    # expires in minutes, and locked out after a few wrong guesses (see
    # PAIRING_CODE_TTL_SECONDS / PAIRING_CODE_MAX_ATTEMPTS in backend/app.py), so a small
    # keyspace is an acceptable tradeoff here specifically — those bounds do the work a
    # long key would otherwise need to do alone.
    return f"{secrets.randbelow(1_000_000):06d}"


def require_user(x_api_key: str = Header(...)) -> dict:
    with db.get_db() as conn:
        row = conn.execute(
            """
            SELECT users.* FROM users
            JOIN device_keys ON device_keys.user_id = users.id
            WHERE device_keys.key_hash = ?
            """,
            (hash_api_key(x_api_key),),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return dict(row)


def require_verified_user(user: dict = Depends(require_user)) -> dict:
    if not user["email_verified"]:
        raise HTTPException(
            status_code=403,
            detail="Please verify your email first — check your inbox for the verification link "
                   "(or POST /api/resend-verification if it didn't arrive).",
        )
    return user
