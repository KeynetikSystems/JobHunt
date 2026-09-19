"""HTTP client for the hosted backend (backend/app.py) — the desktop app's equivalent of
mobile_app/lib/api_client.dart. Plain urllib, same stdlib-only approach digest_engine.py
already uses for its own HTTP calls, rather than pulling in `requests` just for this.

The desktop app used to hold its own Tavily/Groq/SMTP keys and run digest_engine.py
in-process (see git history of main.py). This module is what replaced that: every action
now goes through the same backend the mobile app uses, so desktop users share the
operator's keys and get the same free/premium caps enforced — instead of desktop being an
entirely separate, unmetered, BYO-key product.
"""
import json
import ssl
import urllib.error
import urllib.request

import certifi

_ssl_context = ssl.create_default_context(cafile=certifi.where())


class BackendError(Exception):
    """Raised with a plain-language message already extracted from the backend's JSON
    error body (its `detail` field) where possible, so callers can show str(e) directly."""


def _request(method: str, url: str, headers: dict, body: dict | None = None) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30, context=_ssl_context) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        try:
            detail = json.loads(raw).get("detail", raw)
        except json.JSONDecodeError:
            detail = raw
        raise BackendError(str(detail)) from e
    except urllib.error.URLError as e:
        raise BackendError(f"Couldn't reach the server: {e.reason}") from e


def _auth_headers(api_key: str) -> dict:
    return {"Content-Type": "application/json", "X-API-Key": api_key}


def register(base_url: str, email: str) -> str:
    """Registers (or re-registers) this email and returns the API key. The key is inert
    until the verification email is clicked — see auth.require_verified_user server-side.

    Registering an email that already belongs to a *verified* account doesn't return a
    key here at all (recovery_email_sent=True instead) — the server emails a fresh one
    to that address rather than handing it back over HTTP to whoever merely typed the
    email in, since that would let anyone hijack a known email into an account
    takeover. Raises BackendError with a message telling the caller to check their
    inbox in that case."""
    result = _request("POST", f"{base_url}/api/register", {"Content-Type": "application/json"}, {"email": email})
    api_key = result.get("api_key")
    if api_key:
        return api_key
    raise BackendError(
        "This email already has a verified account — check your inbox for a new access key."
    )


def scan(base_url: str, api_key: str) -> dict:
    """Pulls this user's unseen items from the shared, hourly-cached scan — does not
    trigger a fresh Tavily/Groq search itself."""
    return _request("POST", f"{base_url}/api/scan", _auth_headers(api_key))


def search(base_url: str, api_key: str, query: str) -> dict:
    """One ad-hoc live search — costs a real Tavily+Groq call, capped server-side."""
    return _request("POST", f"{base_url}/api/search", _auth_headers(api_key), {"query": query})


def send(base_url: str, api_key: str, jobs: list, news: list) -> None:
    _request("POST", f"{base_url}/api/send", _auth_headers(api_key), {"jobs": jobs, "news": news})


def dismiss(base_url: str, api_key: str, jobs: list | None = None, news: list | None = None) -> None:
    _request("POST", f"{base_url}/api/dismiss", _auth_headers(api_key), {"jobs": jobs or [], "news": news or []})


def me(base_url: str, api_key: str) -> dict:
    return _request("GET", f"{base_url}/api/me", _auth_headers(api_key))


def resend_verification(base_url: str, api_key: str) -> None:
    _request("POST", f"{base_url}/api/resend-verification", _auth_headers(api_key))


def request_upgrade(base_url: str, api_key: str, note: str) -> None:
    _request("POST", f"{base_url}/api/upgrade-request", _auth_headers(api_key), {"note": note})


def history(base_url: str, api_key: str) -> list:
    return _request("GET", f"{base_url}/api/history", _auth_headers(api_key)).get("items", [])


def get_cv(base_url: str, api_key: str) -> str:
    return _request("GET", f"{base_url}/api/cv", _auth_headers(api_key)).get("cv_text", "")


def save_cv(base_url: str, api_key: str, cv_text: str) -> None:
    _request("PUT", f"{base_url}/api/cv", _auth_headers(api_key), {"cv_text": cv_text})


def materials(base_url: str, api_key: str, job: dict) -> dict:
    return _request("POST", f"{base_url}/api/materials", _auth_headers(api_key), {"job": job})
