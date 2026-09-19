"""API-key auth. Deliberately simple for a first pass — one header, one lookup.
No billing gate yet; /api/register hands out a key immediately, but it only works
once the email it was issued for is verified (require_verified_user) — otherwise
anyone could register under an address they don't own to bypass free-tier caps or
have digests emailed to someone who never asked for them.
"""
import secrets

from fastapi import Depends, Header, HTTPException

import db


def generate_api_key() -> str:
    return "jh_" + secrets.token_urlsafe(24)


def generate_verify_token() -> str:
    return secrets.token_urlsafe(24)


def require_user(x_api_key: str = Header(...)) -> dict:
    with db.get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE api_key = ?", (x_api_key,)).fetchone()
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
