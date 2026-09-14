"""API-key auth. Deliberately simple for a first pass — one header, one lookup.
No signup flow, no billing gate yet; /api/register just hands out a key. Swap this
for real accounts (and gate registration behind billing) once there's something to charge for.
"""
import secrets

from fastapi import Header, HTTPException

import db


def generate_api_key() -> str:
    return "jh_" + secrets.token_urlsafe(24)


def require_user(x_api_key: str = Header(...)) -> dict:
    with db.get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE api_key = ?", (x_api_key,)).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return dict(row)
