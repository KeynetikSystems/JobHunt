# JobHuntAI

Finds career opportunities and PE/VC/impact/consulting news (currently tuned for
London), summarizes them with an LLM, and delivers them as a digest — by email, in a
desktop app, or in a mobile app.

Both a History page (every job/news item ever emailed or dismissed) and AI-assisted
"Draft CV highlights & cover letter" drafting are live on `main` in every client.

The project's separate PySide6/QML desktop app was retired in favor of building the
Flutter client for desktop too — its code (last state: feature-equivalent to mobile,
hosted-keys architecture) is preserved at
[KeynetikSystems/Ledger-qml-archive](https://github.com/KeynetikSystems/Ledger-qml-archive)
for history, not deleted outright.

The project has three moving parts that all sit on top of one shared pipeline:

| Surface | What it is | Where |
|---|---|---|
| Core pipeline | Search → summarize → dedupe → email/store | [`digest_engine.py`](digest_engine.py) |
| Backend | Multi-user FastAPI service, hosted keys | [`backend/`](backend/) |
| Mobile/desktop app | Flutter client for the backend (all platforms) | [`mobile_app/`](mobile_app/) |
| Headless runner | Scheduled digest via GitHub Actions | [`.github/workflows/`](.github/workflows/) |

## How the pipeline works

`digest_engine.py` is the only place that talks to Tavily (search) and Groq
(summarization). Every other surface imports it directly rather than reimplementing any
of this:

1. **Search** — runs a set of Tavily queries (job listings + PE/VC news) concurrently,
   skipping anything already in `seen_items.json`.
2. **Summarize** — sends the raw results to Groq, which filters down to genuine listings
   / notable news and returns structured JSON (title, firm, seniority, note / headline,
   source, summary).
3. **Dedupe** — once something is actually delivered (emailed, or marked seen via the
   backend's dismiss/send), its URL is written to `seen_items.json` so it never
   resurfaces.
4. **Archive** — every run is recorded to `history.json`, keyed by URL — this backs the
   headless runner's own record-keeping. The backend keeps its own equivalent per-user
   history in SQLite (`seen_items` table), which is what both desktop's and mobile's
   History pages actually read from.
5. **Application materials** — given a chosen opportunity and a CV/background, Groq
   drafts tailored CV highlights and a full cover letter, grounded only in facts already
   present in the CV (the prompt explicitly forbids inventing experience). The backend
   exposes this as `/api/materials`, backed by each user's CV text stored in SQLite; the
   headless runner has no equivalent (there's no interactive user to draft for).

All local state (`seen_items.json`, `history.json`, `queries.json`, `cv.txt`, `.env`) is
gitignored — it's per-installation data, not project source. This local state is only
actually used by whatever runs `digest_engine.py` in-process — the backend server (for
the shared scan) and the headless runner.

## Backend (multi-user, hosted keys)

[`backend/app.py`](backend/app.py) is the "hosted keys" architecture: the server holds
the Tavily/Groq/SMTP credentials, and clients (desktop, mobile) authenticate with an
API key and never see those credentials directly.

- **One shared scan, not one per user.** `_get_shared_results()` caches the last scan
  for an hour and fans it out to every registered user; personalization happens only at
  the per-user seen/dedup layer, so Tavily/Groq cost stays roughly flat as users grow
  instead of scaling with subscriber count.
- **Storage**: SQLite (`backend/db.py`), deliberately a first pass — schema is plain
  enough to move to Postgres later without changes beyond the connection setup.
- **Auth**: one header, one lookup (`backend/auth.py`) — no signup flow or billing gate
  yet; `/api/register` just hands out a key.

```bash
cd backend
pip install -r requirements.txt
uvicorn app:app --reload
```
Interactive docs at `http://127.0.0.1:8000/docs`.

Deployed via [`Dockerfile`](Dockerfile) + [`railway.json`](railway.json) (Railway). The
Dockerfile builds from the repo root rather than `backend/` alone, because the backend
imports `digest_engine.py`, `config.py`, and `send_report.py` from the parent directory.

**Not yet built**: billing (Stripe) — plan upgrades are still a manual review of
`/api/upgrade-request` — and a real scheduler (the shared-scan cache refreshes lazily on
request rather than on a cron). Per-user custom queries and AI-assisted application
materials are both built (`/api/search`, `/api/materials`), each with its own daily cap
on the free plan.

Routes: `GET /api/health`, `POST /api/register`, `GET /api/verify`,
`POST /api/resend-verification`, `POST /api/scan`, `POST /api/search`, `POST /api/send`,
`POST /api/dismiss`, `GET /api/me`, `GET /api/history`, `GET/PUT /api/profile`,
`POST /api/materials`, `GET/PUT /api/alerts`, `POST /api/upgrade-request`,
`GET /api/export`, `DELETE /api/account`.

## Mobile/desktop app

Flutter client for the backend, living in [`mobile_app/`](mobile_app/) — the only
client now, builds for mobile and desktop (Windows/macOS/Linux) from one codebase.
Talks to `backend/app.py` via [`api_client.dart`](mobile_app/lib/api_client.dart) using
the per-user API key from `/api/register`; never holds Tavily/Groq/SMTP credentials
itself.

Screens: Dashboard ([`dashboard_screen.dart`](mobile_app/lib/screens/dashboard_screen.dart)),
History ([`history_screen.dart`](mobile_app/lib/screens/history_screen.dart)), Settings
([`settings_screen.dart`](mobile_app/lib/screens/settings_screen.dart)).

```bash
cd mobile_app
flutter pub get
flutter run
```

## Headless runner (GitHub Actions)

[`.github/workflows/main.yml`](.github/workflows/main.yml) and
[`main2.yml`](.github/workflows/main2.yml) run `digest_engine.py` directly on a daily
cron, then [`build_archive.py`](build_archive.py) publishes the day's report into
`docs/` as a GitHub Pages archive. `main2.yml` sets `SKIP_EMAIL=true` so the archive/
dedup state still advances without actually sending mail (email delivery is treated as a
desktop-app-only feature there).

Both workflows run `pip install -r requirements.txt` against a root-level
[`requirements.txt`](requirements.txt) — `certifi` is the only third-party dependency
the headless scripts (`digest_engine.py`, `config.py`, `send_report.py`,
`build_archive.py`) actually need; everything else they use is stdlib.

## Repo layout

```
digest_engine.py       Core pipeline — search, summarize, dedupe, history, application materials
config.py               .env loading, project ROOT
send_report.py          Resend HTTP API email delivery
build_archive.py        GitHub Pages archive builder
backend/                 FastAPI multi-user backend (app.py, db.py, auth.py)
mobile_app/              Flutter client — mobile and desktop
.github/workflows/       Scheduled digest CI
reports/, docs/          Generated HTML digests / GitHub Pages archive (not hand-edited)
```

## Roadmap notes

Product direction discussed alongside this codebase, for whoever picks this up next:

- **Free vs. premium split**: free = manual scans, shared default query set, capped
  custom searches/history/AI drafts; premium = scheduled auto-scans pushed via
  Slack/Telegram, unlimited custom search, unlimited AI-assisted application materials,
  and full history. AI-assisted application materials (CV highlights/cover letter) and
  custom search are live on both clients (Flutter, backend), not premium-only — the caps
  are what actually differ by plan.
- ~~BYO-key vs. hosted-key tension~~ — resolved: the original desktop app was migrated
  onto the hosted backend instead of calling `digest_engine.py` in-process, so it was
  metered and gated by plan exactly like mobile. What's still genuinely missing is real
  billing (Stripe/Paddle or platform in-app purchases) to act on that metering — plan
  upgrades are still a manual review of `/api/upgrade-request`.
- ~~Two separate client codebases (Dart/Flutter, Python/QML)~~ — resolved: the PySide6/
  QML desktop app was retired in favor of Flutter's own desktop build targets, so there's
  one client codebase for mobile and desktop. The QML app's final state is archived at
  [KeynetikSystems/Ledger-qml-archive](https://github.com/KeynetikSystems/Ledger-qml-archive).
