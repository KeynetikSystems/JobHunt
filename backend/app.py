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
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
import digest_engine  # noqa: E402

from fastapi import Depends, FastAPI, HTTPException  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from pydantic import BaseModel, EmailStr  # noqa: E402

import alerts  # noqa: E402
import auth  # noqa: E402
import db  # noqa: E402

app = FastAPI(title="JobHunt backend")
db.init_db()

# Permissive for local development against the Flutter/desktop clients. Tighten to your
# real client origins before this is reachable from the public internet.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
    api_key: str


class ScanResponse(BaseModel):
    jobs: list
    news: list


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

@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.post("/api/register", response_model=RegisterResponse)
def register(body: RegisterRequest):
    api_key = auth.generate_api_key()
    with db.get_db() as conn:
        conn.execute("INSERT INTO users (api_key, email) VALUES (?, ?)", (api_key, body.email))
    return RegisterResponse(api_key=api_key)


@app.post("/api/scan", response_model=ScanResponse)
def scan(user: dict = Depends(auth.require_user)):
    jobs, news = _get_shared_results()
    new_jobs, new_news = _new_items_for_user(user["id"], jobs, news)
    return ScanResponse(jobs=new_jobs, news=new_news)


@app.post("/api/send")
def send(body: SendRequest, user: dict = Depends(auth.require_user)):
    try:
        digest_engine.finalize_and_send(body.jobs, body.news, log=print, to_addr=user["email"])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    _mark_seen(user["id"], body.jobs, body.news)
    return {"status": "sent"}


@app.post("/api/dismiss")
def dismiss(body: DismissRequest, user: dict = Depends(auth.require_user)):
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
        plan=user["plan"],
        materials_used_today=_usage_count_today(user["id"], "materials"),
        materials_daily_cap=None if is_premium else FREE_MATERIALS_DAILY_CAP,
    )


@app.get("/api/history", response_model=HistoryResponse)
def history(user: dict = Depends(auth.require_user)):
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
def get_cv(user: dict = Depends(auth.require_user)):
    """The user's own background/experience, saved once here so mobile doesn't resend
    it on every /api/materials call — mirrors the desktop app's cv.txt."""
    return CvResponse(cv_text=user["cv_text"])


@app.put("/api/cv", response_model=CvResponse)
def put_cv(body: CvRequest, user: dict = Depends(auth.require_user)):
    with db.get_db() as conn:
        conn.execute("UPDATE users SET cv_text = ? WHERE id = ?", (body.cv_text, user["id"]))
    return CvResponse(cv_text=body.cv_text)


@app.post("/api/materials", response_model=MaterialsResponse)
def materials(body: MaterialsRequest, user: dict = Depends(auth.require_user)):
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
def get_alerts(user: dict = Depends(auth.require_user)):
    return AlertsResponse(slack_webhook_url=user["slack_webhook_url"], telegram_chat_id=user["telegram_chat_id"])


@app.put("/api/alerts", response_model=AlertsResponse)
def put_alerts(body: AlertsRequest, user: dict = Depends(auth.require_user)):
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
def upgrade_request(body: UpgradeRequestBody, user: dict = Depends(auth.require_user)):
    """Captures interest in premium instead of building real billing before there's
    evidence anyone wants it — reviewed by hand, then the plan is flipped manually."""
    with db.get_db() as conn:
        conn.execute(
            "INSERT INTO upgrade_requests (user_id, note) VALUES (?, ?)",
            (user["id"], body.note),
        )
    return UpgradeRequestResponse(status="received")
