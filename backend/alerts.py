"""Slack and Telegram delivery for premium users' scheduled-scan alerts.

Both channels are a single JSON-over-HTTPS POST — stdlib only, no SDKs, consistent
with the rest of this project. Slack uses a webhook URL the user creates themselves
in their own workspace; Telegram uses one shared bot (its token lives in the
server's own .env) with each user supplying their own chat_id.

Callers are expected to catch exceptions per-user — a failed send here must never
break the scheduled scan for everyone else.
"""
import json
import urllib.request

TELEGRAM_API_BASE = "https://api.telegram.org"


def _post_json(url: str, payload: dict, timeout: int = 15) -> None:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        resp.read()


def format_alert_message(jobs: list, news: list) -> str:
    job_word = "opportunity" if len(jobs) == 1 else "opportunities"
    news_word = "item" if len(news) == 1 else "items"
    lines = [f"{len(jobs)} new {job_word}, {len(news)} news {news_word}", ""]
    for j in jobs[:5]:
        title, firm, url = j.get("title", ""), j.get("firm", ""), j.get("url", "")
        suffix = f" — {firm}" if firm else ""
        lines.append(f"- {title}{suffix}" + (f"\n  {url}" if url else ""))
    if len(jobs) > 5:
        lines.append(f"...and {len(jobs) - 5} more")
    for n in news[:3]:
        headline, url = n.get("headline", ""), n.get("url", "")
        lines.append(f"- {headline}" + (f"\n  {url}" if url else ""))
    return "\n".join(lines)


def send_slack_alert(webhook_url: str, jobs: list, news: list) -> None:
    if not webhook_url:
        return
    _post_json(webhook_url, {"text": format_alert_message(jobs, news)})


def send_telegram_alert(bot_token: str, chat_id: str, jobs: list, news: list,
                         api_base: str = TELEGRAM_API_BASE) -> None:
    if not bot_token or not chat_id:
        return
    url = f"{api_base}/bot{bot_token}/sendMessage"
    _post_json(url, {"chat_id": chat_id, "text": format_alert_message(jobs, news)})
