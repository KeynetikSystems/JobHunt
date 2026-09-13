"""Emails a generated digest report over SMTP. Stdlib only."""
import smtplib
from email.mime.text import MIMEText
from pathlib import Path

from config import load_env


def send_report(subject: str, html_path: Path, to_addr: str) -> None:
    env = load_env()
    smtp_host = env.get("SMTP_HOST", "smtp.gmail.com")
    smtp_port = int(env.get("SMTP_PORT", "587"))
    smtp_user = env.get("SMTP_USER")
    smtp_pass = env.get("SMTP_PASS")
    if not smtp_user or not smtp_pass:
        raise RuntimeError("SMTP_USER and SMTP_PASS must be set in .env")

    msg = MIMEText(html_path.read_text(encoding="utf-8"), "html")
    msg["Subject"] = subject
    msg["From"] = smtp_user
    msg["To"] = to_addr

    with smtplib.SMTP(smtp_host, smtp_port) as server:
        server.starttls()
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)
