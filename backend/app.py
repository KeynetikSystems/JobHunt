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

Deliberately NOT in this first pass: billing (Stripe), a real scheduler (the shared cache
refreshes lazily on the first request after it goes stale, not on a cron), and per-user
custom queries (everyone gets the shared default query set for now). All straightforward
to layer on once this core mechanism is proven out.

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
    with db.get_db() as conn:
        seen_rows = conn.execute(
            "SELECT url FROM seen_items WHERE user_id = ?", (user["id"],)
        ).fetchall()
    seen_urls = {row["url"] for row in seen_rows}
    new_jobs = [j for j in jobs if j.get("url") not in seen_urls]
    new_news = [n for n in news if n.get("url") not in seen_urls]
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


@app.get("/api/history", response_model=HistoryResponse)
def history(user: dict = Depends(auth.require_user)):
    """Everything this user has previously seen (sent or dismissed), newest first —
    backs the mobile app's History tab."""
    with db.get_db() as conn:
        rows = conn.execute(
            "SELECT * FROM seen_items WHERE user_id = ? ORDER BY seen_at DESC LIMIT 200",
            (user["id"],),
        ).fetchall()
    return HistoryResponse(items=[HistoryItem(**dict(row)) for row in rows])
