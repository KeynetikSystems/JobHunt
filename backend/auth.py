"""API-key auth. Deliberately simple for a first pass — one header, one lookup.
No billing gate yet; /api/register hands out a key immediately, but it only works
once the email it was issued for is verified (require_verified_user) — otherwise
anyone could register under an address they don't own to bypass free-tier caps or
have digests emailed to someone who never asked for them.

Keys are stored only as a SHA-256 hash (device_keys.key_hash) — the raw key is shown to
the caller exactly once, at issuance, and never persisted. A high-entropy token like
this (192 bits from secrets.token_urlsafe(24)) doesn't need a slow/salted password hash;
it needs a fast one-way lookup, which SHA-256 provides. This means a database leak alone
no longer hands out working credentials for every account.

One row per connected device, not per account — see device_keys in db.py. Registering a
new device for an already-verified account adds a key rather than replacing the old one,
so multiple devices can stay connected to the same account at once.
"""
import hashlib
import secrets

from fastapi import Depends, Header, HTTPException

import db


def generate_api_key() -> str:
    return "jh_" + secrets.token_urlsafe(24)


def hash_api_key(key: str) -> str:
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def generate_verify_token() -> str:
    return secrets.token_urlsafe(24)


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
