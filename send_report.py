"""Emails via Resend's HTTP API (port 443), not raw SMTP.

PaaS hosts commonly restrict outbound SMTP ports (25/465/587) to curb spam abuse
while leaving HTTPS wide open — confirmed on this project's Railway deployment:
smtplib connects to smtp.gmail.com:587 failed with ENETUNREACH (no route at all),
while HTTPS calls to Tavily/Groq/Resend work fine from the same container.
"""
import json
import ssl
import urllib.error
import urllib.request
from pathlib import Path

import certifi

from config import load_env

RESEND_URL = "https://api.resend.com/emails"
_ssl_context = ssl.create_default_context(cafile=certifi.where())


def send_email(to_addr: str, subject: str, text: str | None = None, html: str | None = None) -> None:
    env = load_env()
    api_key = env.get("RESEND_API_KEY")
    from_addr = env.get("RESEND_FROM", "onboarding@resend.dev")
    if not api_key:
        raise RuntimeError("RESEND_API_KEY must be set in .env")
    if not text and not html:
        raise ValueError("send_email requires text or html content")

    payload = {"from": from_addr, "to": [to_addr], "subject": subject}
    if html:
        payload["html"] = html
    if text:
        payload["text"] = text

    req = urllib.request.Request(
        RESEND_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            # Resend sits behind Cloudflare, which blocks the default
            # "Python-urllib/x.x" User-Agent as a bot signature (HTTP 403 / error 1010).
            "User-Agent": "JobHuntAI/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10, context=_ssl_context) as resp:
            resp.read()
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Resend API error {e.code}: {body[:300]}") from e


def send_report(subject: str, html_path: Path, to_addr: str) -> None:
    send_email(to_addr, subject, html=html_path.read_text(encoding="utf-8"))
