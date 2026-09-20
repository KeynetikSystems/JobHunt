"""JobHunt backend — first pass at the hosted-keys architecture discussed alongside the
desktop app and Flutter prototype: the server holds the Tavily/Groq/SMTP credentials,
clients (desktop, mobile) authenticate with their own API key and never see those keys.

Scan architecture: one shared scan, cached and fanned out to every registered user, rather
than a scan per user. Most users' queries are close to identical by default, so sharing the
scan keeps Tavily/Groq usage (the actual cost driver here) roughly flat as users grow,
instead of scaling with the number of subscribers. Per-user personalization happens at the
dedup/send step, not at the search step — each user has their own seen-items list, and only
sees an item as "new" (and only gets it marked seen) once they've actually had it emailed to
them, mirroring the desktop app's own dry-run-doesn't-mark-seen behavior.

A background thread proactively refreshes the shared scan cache every CACHE_TTL_SECONDS
(instead of only refreshing lazily on the next request) and, on each refresh, delivers
new items to premium users who've configured a Slack webhook or Telegram chat ID —
free-plan users still only see new items when they open the app and pull /api/scan.

Deliberately NOT in this first pass: billing (Stripe/Paddle) — plan upgrades are either
flipped manually in the database or requested via /api/upgrade-request and reviewed by
hand — and per-user custom queries (everyone gets the shared default query set for now).
Both are straightforward to layer on once this core mechanism is proven out.

Run locally:
    cd backend
    pip install -r requirements.txt
    uvicorn app:app --reload
Then open http://127.0.0.1:8000/docs for interactive testing.
"""
import os
import smtplib
import sys
import threading
import time
from email.mime.text import MIMEText
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
import digest_engine  # noqa: E402

from fastapi import Depends, FastAPI, HTTPException, Request  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from fastapi.responses import HTMLResponse  # noqa: E402
from pydantic import BaseModel, EmailStr  # noqa: E402

import alerts  # noqa: E402
import auth  # noqa: E402
import db  # noqa: E402

app = FastAPI(title="JobHunt backend")
db.init_db()

# The mobile and desktop clients are native apps, not browser pages — CORS is a
# browser-only enforcement mechanism and doesn't affect them either way. This only
# matters for stopping some third-party website's JavaScript from calling this API
# from a visitor's browser. Defaults to allowing none (safe) rather than "*" (was
# previously wide open to any origin); set ALLOWED_ORIGINS to a comma-separated list
# if a real browser-based client (e.g. an admin dashboard) is ever added.
_allowed_origins = [o.strip() for o in os.environ.get("ALLOWED_ORIGINS", "").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -- shared scan cache ----------------------------------------------------------
# All users read from this single cache; only the first request after it goes stale
# pays the Tavily/Groq cost of a real scan. This is what keeps usage cost roughly
# flat as the user count grows, not a rate limiter bolted on separately.
_cache_lock = threading.Lock()
_cache = {"jobs": [], "news": [], "fetched_at": 0.0}
CACHE_TTL_SECONDS = 3600

# -- free-plan usage caps ---------------------------------------------------
# No billing yet — a user's plan is flipped manually in the database once they've
# paid outside the app. These caps exist purely to bound cost (Groq calls, response
# size) while that manual process is in place, not as a monetization mechanism.
FREE_MATERIALS_DAILY_CAP = 5
FREE_SEARCH_DAILY_CAP = 10
FREE_HISTORY_DAYS = 30


def _usage_count_today(user_id: int, action: str) -> int:
    with db.get_db() as conn:
        row = conn.execute(
            "SELECT COUNT(*) AS n FROM usage_log WHERE user_id = ? AND action = ? AND used_at >= date('now')",
            (user_id, action),
        ).fetchone()
    return row["n"]


def _log_usage(user_id: int, action: str) -> None:
    with db.get_db() as conn:
        conn.execute("INSERT INTO usage_log (user_id, action) VALUES (?, ?)", (user_id, action))


def _get_shared_results() -> tuple[list, list]:
    with _cache_lock:
        stale = (time.time() - _cache["fetched_at"]) > CACHE_TTL_SECONDS
        if stale:
            env = digest_engine.load_env()
            if not env.get("TAVILY_API_KEY") or not env.get("GROQ_API_KEY"):
                raise HTTPException(
                    status_code=500,
                    detail="Server is missing TAVILY_API_KEY/GROQ_API_KEY in its own .env",
                )
            jobs, news = digest_engine.collect_jobs_and_news(env, seen={}, log=print)
            _cache["jobs"] = jobs
            _cache["news"] = news
            _cache["fetched_at"] = time.time()
        return _cache["jobs"], _cache["news"]


def _new_items_for_user(user_id: int, jobs: list, news: list) -> tuple[list, list]:
    """Filters the shared scan results down to what this specific user hasn't
    seen yet — shared by /api/scan (pull) and the scheduled alert job (push)."""
    with db.get_db() as conn:
        seen_rows = conn.execute("SELECT url FROM seen_items WHERE user_id = ?", (user_id,)).fetchall()
    seen_urls = {row["url"] for row in seen_rows}
    new_jobs = [j for j in jobs if j.get("url") not in seen_urls]
    new_news = [n for n in news if n.get("url") not in seen_urls]
    return new_jobs, new_news


# -- scheduled scan + premium alerts -----------------------------------------
# Runs in a background thread so premium users get pushed new items automatically
# instead of having to open the app and pull /api/scan themselves ("real-time"
# vs. free's "manual"). A failed alert for one user is logged and skipped, never
# allowed to break the loop for everyone else.

def _run_scan_and_alert_once() -> None:
    jobs, news = _get_shared_results()
    env = digest_engine.load_env()
    bot_token = env.get("TELEGRAM_BOT_TOKEN", "")
    with db.get_db() as conn:
        premium_users = conn.execute("SELECT * FROM users WHERE plan = 'premium'").fetchall()
    for row in premium_users:
        user = dict(row)
        if not user["slack_webhook_url"] and not user["telegram_chat_id"]:
            continue
        new_jobs, new_news = _new_items_for_user(user["id"], jobs, news)
        if not new_jobs and not new_news:
            continue
        try:
            if user["slack_webhook_url"]:
                alerts.send_slack_alert(user["slack_webhook_url"], new_jobs, new_news)
            if user["telegram_chat_id"]:
                alerts.send_telegram_alert(bot_token, user["telegram_chat_id"], new_jobs, new_news)
            _mark_seen(user["id"], new_jobs, new_news)
        except Exception as e:
            print(f"Alert delivery failed for user {user['id']}: {e}")


def _scheduled_scan_loop() -> None:
    while True:
        time.sleep(CACHE_TTL_SECONDS)
        try:
            _run_scan_and_alert_once()
        except Exception as e:
            print(f"Scheduled scan failed: {e}")


threading.Thread(target=_scheduled_scan_loop, daemon=True).start()


# -- schemas ----------------------------------------------------------------

class RegisterRequest(BaseModel):
    email: EmailStr


class RegisterResponse(BaseModel):
    # Present for a new signup or a retry of one that never got verified — neither case
    # exposes anything sensitive yet, since require_verified_user blocks everything
    # until verified. Absent (recovery_email_sent=True instead) for an already-verified
    # account, where handing a working key straight back over HTTP to whoever merely
    # typed that email in would be an account-takeover primitive.
    api_key: str | None = None
    recovery_email_sent: bool = False


class ScanResponse(BaseModel):
    jobs: list
    news: list


class SearchRequest(BaseModel):
    query: str


class SendRequest(BaseModel):
    jobs: list
    news: list


class DismissRequest(BaseModel):
    jobs: list = []
    news: list = []


class HistoryItem(BaseModel):
    kind: str
    url: str
    title: str | None = None
    firm: str | None = None
    seniority: str | None = None
    note: str | None = None
    headline: str | None = None
    source: str | None = None
    summary: str | None = None
    seen_at: str


class HistoryResponse(BaseModel):
    items: list[HistoryItem]


class CvRequest(BaseModel):
    cv_text: str


class CvResponse(BaseModel):
    cv_text: str


class MaterialsRequest(BaseModel):
    job: dict


class MaterialsResponse(BaseModel):
    cv_highlights: str
    cover_letter: str


class MeResponse(BaseModel):
    email: str
    email_verified: bool
    plan: str
    materials_used_today: int
    materials_daily_cap: int | None  # null = unlimited (premium)


class AlertsRequest(BaseModel):
    slack_webhook_url: str = ""
    telegram_chat_id: str = ""


class AlertsResponse(BaseModel):
    slack_webhook_url: str
    telegram_chat_id: str


class UpgradeRequestBody(BaseModel):
    note: str = ""


class UpgradeRequestResponse(BaseModel):
    status: str


def _send_verification_email(to_addr: str, verify_url: str) -> None:
    """Best-effort — registration still succeeds if this fails (a transient SMTP
    hiccup shouldn't lock someone out of retrying), but the account stays
    unverified until POST /api/resend-verification is called."""
    env = digest_engine.load_env()
    smtp_host = env.get("SMTP_HOST", "smtp.gmail.com")
    smtp_port = int(env.get("SMTP_PORT", "587"))
    smtp_user = env.get("SMTP_USER")
    smtp_pass = env.get("SMTP_PASS")
    if not smtp_user or not smtp_pass:
        raise RuntimeError("SMTP_USER and SMTP_PASS must be set in the server's .env")

    msg = MIMEText(
        f"Confirm this is your email address to activate your JobHuntAI account:\n\n{verify_url}\n\n"
        "If you didn't request this, ignore this email."
    )
    msg["Subject"] = "Verify your email — JobHuntAI"
    msg["From"] = smtp_user
    msg["To"] = to_addr

    with smtplib.SMTP(smtp_host, smtp_port) as server:
        server.starttls()
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)


def _send_recovery_email(to_addr: str, api_key: str) -> None:
    """Delivers a freshly-issued API key to an already-verified account's own inbox —
    the only safe way to hand it over, since the HTTP response itself never can (see
    RegisterResponse). Requires SMTP to be configured; if it's not, recovery for
    verified accounts genuinely doesn't work yet, same tradeoff as verification email."""
    env = digest_engine.load_env()
    smtp_host = env.get("SMTP_HOST", "smtp.gmail.com")
    smtp_port = int(env.get("SMTP_PORT", "587"))
    smtp_user = env.get("SMTP_USER")
    smtp_pass = env.get("SMTP_PASS")
    if not smtp_user or not smtp_pass:
        raise RuntimeError("SMTP_USER and SMTP_PASS must be set in the server's .env")

    msg = MIMEText(
        f"A new access key was requested for your JobHuntAI account:\n\n{api_key}\n\n"
        "Your old key no longer works. Paste this one into the app's Settings/Backend "
        "connection screen. If you didn't request this, someone else knows your email "
        "address — consider that before reusing this key."
    )
    msg["Subject"] = "Your new access key — JobHuntAI"
    msg["From"] = smtp_user
    msg["To"] = to_addr

    with smtplib.SMTP(smtp_host, smtp_port) as server:
        server.starttls()
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)


def _mark_seen(user_id: int, jobs: list, news: list) -> None:
    """Records jobs/news as seen for this user, keeping their details so /api/history
    can show what was previously surfaced, not just that a URL was dismissed."""
    with db.get_db() as conn:
        for j in jobs:
            url = j.get("url")
            if not url:
                continue
            conn.execute(
                """
                INSERT INTO seen_items (user_id, url, kind, title, firm, seniority, note)
                VALUES (?, ?, 'job', ?, ?, ?, ?)
                ON CONFLICT (user_id, url) DO UPDATE SET
                    seen_at = datetime('now'), kind = 'job', title = excluded.title,
                    firm = excluded.firm, seniority = excluded.seniority, note = excluded.note
                """,
                (user_id, url, j.get("title", ""), j.get("firm", ""), j.get("seniority", ""), j.get("note", "")),
            )
        for n in news:
            url = n.get("url")
            if not url:
                continue
            conn.execute(
                """
                INSERT INTO seen_items (user_id, url, kind, headline, source, summary)
                VALUES (?, ?, 'news', ?, ?, ?)
                ON CONFLICT (user_id, url) DO UPDATE SET
                    seen_at = datetime('now'), kind = 'news', headline = excluded.headline,
                    source = excluded.source, summary = excluded.summary
                """,
                (user_id, url, n.get("headline", ""), n.get("source", ""), n.get("summary", "")),
            )


# -- routes -------------------------------------------------------------------

def _serve_legal_doc(filename: str) -> HTMLResponse:
    path = Path(__file__).parent.parent / filename
    text = path.read_text(encoding="utf-8") if path.exists() else f"{filename} not found."
    escaped = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    html = (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>"
        "<style>body{font-family:sans-serif;max-width:720px;margin:2rem auto;padding:0 1rem;"
        "line-height:1.5;white-space:pre-wrap}</style></head>"
        f"<body>{escaped}</body></html>"
    )
    return HTMLResponse(html)


@app.get("/privacy", response_class=HTMLResponse)
def privacy():
    return _serve_legal_doc("PRIVACY.md")


@app.get("/terms", response_class=HTMLResponse)
def terms():
    return _serve_legal_doc("TERMS.md")


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.post("/api/register", response_model=RegisterResponse)
def register(body: RegisterRequest, request: Request):
    """Issues an API key immediately, but it's inert (require_verified_user rejects
    it) until the recipient clicks the link this sends — otherwise anyone could
    register under an address they don't own to dodge free-tier caps with disposable
    accounts, or have digests emailed to someone who never asked for them.

    email is UNIQUE, so registering an address that already exists doesn't create a
    second, orphaned account — it recovers the existing one instead. Either way, this
    adds a new row to device_keys rather than replacing an existing one, so connecting
    a second device (e.g. desktop after mobile) doesn't log the first one out:
    - Not yet verified: nothing sensitive is protected yet, so this just issues another
      key and resends verification, exactly as if it were a first registration.
    - Already verified: a real account with real data is at stake, so the new key is
      never returned in this response (anyone who merely knows the email could ask for
      it otherwise) — it's emailed to the address that already proved ownership."""
    with db.get_db() as conn:
        existing = conn.execute("SELECT * FROM users WHERE email = ?", (body.email,)).fetchone()

    if existing and existing["email_verified"]:
        api_key = auth.generate_api_key()
        with db.get_db() as conn:
            conn.execute(
                "INSERT INTO device_keys (user_id, key_hash) VALUES (?, ?)",
                (existing["id"], auth.hash_api_key(api_key)),
            )
        try:
            _send_recovery_email(body.email, api_key)
        except Exception as e:
            print(f"Recovery email failed for {body.email}: {e}")
        return RegisterResponse(recovery_email_sent=True)

    api_key = auth.generate_api_key()
    verify_token = auth.generate_verify_token()
    with db.get_db() as conn:
        if existing:
            user_id = existing["id"]
            conn.execute("UPDATE users SET verify_token = ? WHERE id = ?", (verify_token, user_id))
        else:
            cursor = conn.execute(
                "INSERT INTO users (email, verify_token) VALUES (?, ?)",
                (body.email, verify_token),
            )
            user_id = cursor.lastrowid
        conn.execute(
            "INSERT INTO device_keys (user_id, key_hash) VALUES (?, ?)",
            (user_id, auth.hash_api_key(api_key)),
        )
    verify_url = f"{str(request.base_url).rstrip('/')}/api/verify?token={verify_token}"
    try:
        _send_verification_email(body.email, verify_url)
    except Exception as e:
        print(f"Verification email failed for {body.email}: {e}")
    return RegisterResponse(api_key=api_key)


@app.get("/api/verify", response_class=HTMLResponse)
def verify(token: str):
    with db.get_db() as conn:
        row = conn.execute("SELECT * FROM users WHERE verify_token = ?", (token,)).fetchone()
        if not row:
            return HTMLResponse("<p>That verification link is invalid or has already been used.</p>", status_code=400)
        conn.execute(
            "UPDATE users SET email_verified = 1, verify_token = NULL WHERE id = ?", (row["id"],)
        )
    return HTMLResponse("<p>Email verified — you can go back to the app now.</p>")


@app.post("/api/resend-verification")
def resend_verification(request: Request, user: dict = Depends(auth.require_user)):
    if user["email_verified"]:
        return {"status": "already_verified"}
    verify_token = auth.generate_verify_token()
    with db.get_db() as conn:
        conn.execute("UPDATE users SET verify_token = ? WHERE id = ?", (verify_token, user["id"]))
    verify_url = f"{str(request.base_url).rstrip('/')}/api/verify?token={verify_token}"
    try:
        _send_verification_email(user["email"], verify_url)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Couldn't send the email: {e}")
    return {"status": "sent"}


@app.post("/api/scan", response_model=ScanResponse)
def scan(user: dict = Depends(auth.require_verified_user)):
    jobs, news = _get_shared_results()
    new_jobs, new_news = _new_items_for_user(user["id"], jobs, news)
    return ScanResponse(jobs=new_jobs, news=new_news)


@app.post("/api/search", response_model=ScanResponse)
def search(body: SearchRequest, user: dict = Depends(auth.require_verified_user)):
    """Runs a live, user-supplied search — the mobile app's replacement for a plain "run
    scan now" button. Unlike /api/scan this bypasses the shared cache and costs a real
    Tavily+Groq call per request, so it's capped on the free plan the same way /api/materials
    is; premium is unlimited."""
    query = body.query.strip()
    if not query:
        raise HTTPException(status_code=400, detail="Enter a search query.")
    if user["plan"] != "premium":
        used = _usage_count_today(user["id"], "search")
        if used >= FREE_SEARCH_DAILY_CAP:
            raise HTTPException(
                status_code=429,
                detail=f"Daily limit of {FREE_SEARCH_DAILY_CAP} searches reached on the free plan. Try again tomorrow.",
            )
    env = digest_engine.load_env()
    if not env.get("TAVILY_API_KEY") or not env.get("GROQ_API_KEY"):
        raise HTTPException(status_code=500, detail="Server is missing TAVILY_API_KEY/GROQ_API_KEY in its own .env")
    try:
        jobs, news = digest_engine.search_custom_query(query, env, log=print)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    _log_usage(user["id"], "search")
    new_jobs, new_news = _new_items_for_user(user["id"], jobs, news)
    return ScanResponse(jobs=new_jobs, news=new_news)


@app.post("/api/send")
def send(body: SendRequest, user: dict = Depends(auth.require_verified_user)):
    try:
        digest_engine.finalize_and_send(body.jobs, body.news, log=print, to_addr=user["email"])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    _mark_seen(user["id"], body.jobs, body.news)
    return {"status": "sent"}


@app.post("/api/dismiss")
def dismiss(body: DismissRequest, user: dict = Depends(auth.require_verified_user)):
    """Marks items seen without emailing — the in-app equivalent of /api/send's seen-marking,
    for clients (mobile) that show results directly instead of delivering them by email."""
    _mark_seen(user["id"], body.jobs, body.news)
    return {"status": "dismissed", "count": len(body.jobs) + len(body.news)}


@app.get("/api/me", response_model=MeResponse)
def me(user: dict = Depends(auth.require_user)):
    """Lets a client show plan status and remaining free-tier usage without
    hardcoding the cap values client-side."""
    is_premium = user["plan"] == "premium"
    return MeResponse(
        email=user["email"],
        email_verified=bool(user["email_verified"]),
        plan=user["plan"],
        materials_used_today=_usage_count_today(user["id"], "materials"),
        materials_daily_cap=None if is_premium else FREE_MATERIALS_DAILY_CAP,
    )


@app.get("/api/history", response_model=HistoryResponse)
def history(user: dict = Depends(auth.require_verified_user)):
    """Everything this user has previously seen (sent or dismissed), newest first —
    backs the mobile app's History tab. Free plan sees the last FREE_HISTORY_DAYS
    days only; premium sees everything (still capped at 200 rows per response)."""
    query = "SELECT * FROM seen_items WHERE user_id = ?"
    params = [user["id"]]
    if user["plan"] != "premium":
        query += " AND seen_at >= date('now', ?)"
        params.append(f"-{FREE_HISTORY_DAYS} days")
    query += " ORDER BY seen_at DESC LIMIT 200"
    with db.get_db() as conn:
        rows = conn.execute(query, params).fetchall()
    return HistoryResponse(items=[HistoryItem(**dict(row)) for row in rows])


@app.get("/api/cv", response_model=CvResponse)
def get_cv(user: dict = Depends(auth.require_verified_user)):
    """The user's own background/experience, saved once here so mobile doesn't resend
    it on every /api/materials call — mirrors the desktop app's cv.txt."""
    return CvResponse(cv_text=user["cv_text"])


@app.put("/api/cv", response_model=CvResponse)
def put_cv(body: CvRequest, user: dict = Depends(auth.require_verified_user)):
    with db.get_db() as conn:
        conn.execute("UPDATE users SET cv_text = ? WHERE id = ?", (body.cv_text, user["id"]))
    return CvResponse(cv_text=body.cv_text)


@app.post("/api/materials", response_model=MaterialsResponse)
def materials(body: MaterialsRequest, user: dict = Depends(auth.require_verified_user)):
    """Tailored CV highlights + a cover letter for one job, using this user's saved CV
    and the server's own Groq key — the mobile equivalent of the desktop app's
    "Draft CV highlights & cover letter" button. Free plan is capped per day since
    each call costs a real Groq request the server itself pays for; premium is unlimited."""
    if not user["cv_text"].strip():
        raise HTTPException(status_code=400, detail="Add your CV/background first (PUT /api/cv).")
    if user["plan"] != "premium":
        used = _usage_count_today(user["id"], "materials")
        if used >= FREE_MATERIALS_DAILY_CAP:
            raise HTTPException(
                status_code=429,
                detail=f"Daily limit of {FREE_MATERIALS_DAILY_CAP} application drafts reached on the free plan. Try again tomorrow.",
            )
    env = digest_engine.load_env()
    groq_key = env.get("GROQ_API_KEY")
    groq_model = env.get("GROQ_MODEL") or digest_engine.DEFAULT_GROQ_MODEL
    try:
        result = digest_engine.generate_application_materials(body.job, user["cv_text"], groq_key, groq_model)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    _log_usage(user["id"], "materials")
    return MaterialsResponse(**result)


@app.get("/api/alerts", response_model=AlertsResponse)
def get_alerts(user: dict = Depends(auth.require_verified_user)):
    return AlertsResponse(slack_webhook_url=user["slack_webhook_url"], telegram_chat_id=user["telegram_chat_id"])


@app.put("/api/alerts", response_model=AlertsResponse)
def put_alerts(body: AlertsRequest, user: dict = Depends(auth.require_verified_user)):
    """Configures where scheduled-scan alerts get pushed. Premium only — free-plan
    users still get new items, just by pulling /api/scan themselves."""
    if user["plan"] != "premium":
        raise HTTPException(
            status_code=403,
            detail="Multi-channel alerts are a premium feature. Request an upgrade via /api/upgrade-request.",
        )
    with db.get_db() as conn:
        conn.execute(
            "UPDATE users SET slack_webhook_url = ?, telegram_chat_id = ? WHERE id = ?",
            (body.slack_webhook_url, body.telegram_chat_id, user["id"]),
        )
    return AlertsResponse(slack_webhook_url=body.slack_webhook_url, telegram_chat_id=body.telegram_chat_id)


@app.post("/api/upgrade-request", response_model=UpgradeRequestResponse)
def upgrade_request(body: UpgradeRequestBody, user: dict = Depends(auth.require_verified_user)):
    """Captures interest in premium instead of building real billing before there's
    evidence anyone wants it — reviewed by hand, then the plan is flipped manually."""
    with db.get_db() as conn:
        conn.execute(
            "INSERT INTO upgrade_requests (user_id, note) VALUES (?, ?)",
            (user["id"], body.note),
        )
    return UpgradeRequestResponse(status="received")
