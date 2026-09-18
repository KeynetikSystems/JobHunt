# JobHuntAI

Finds career opportunities and PE/VC/impact/consulting news (currently tuned for
London), summarizes them with an LLM, and delivers them as a digest — by email, in a
desktop app, or in a mobile app. Also drafts AI-assisted, CV-grounded cover letters and
CV highlights for individual opportunities.

The project has four moving parts that all sit on top of one shared pipeline:

| Surface | What it is | Where |
|---|---|---|
| Core pipeline | Search → summarize → dedupe → email/store | [`digest_engine.py`](digest_engine.py) |
| Desktop app | Single-user PySide6/QML GUI, BYO API keys | [`main.py`](main.py), [`Main.qml`](Main.qml) |
| Backend | Multi-user FastAPI service, hosted keys | [`backend/`](backend/) |
| Mobile app | Flutter client for the backend | [`mobile_app/`](mobile_app/) |
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
4. **Archive** — every run (including preview/dry-run scans) is recorded to
   `history.json`, keyed by URL, with a `status` of `"found"` or `"emailed"` — this is
   what backs the History views in the desktop and mobile apps.
5. **Application materials** — given a chosen opportunity and the user's own
   pasted-in CV/background (`cv.txt`), Groq drafts tailored CV highlights and a full
   cover letter, grounded only in facts already present in the CV (the prompt
   explicitly forbids inventing experience).

All local state (`seen_items.json`, `history.json`, `queries.json`, `cv.txt`, `.env`) is
gitignored — it's per-installation data, not project source.

## Desktop app (JobHuntAI / "Ledger")

A single-user, offline-first Windows/macOS app. Runs `digest_engine.py` in-process — no
server involved — using API keys the user pastes into Settings themselves.

```bash
pip install -r requirements-desktop.txt
cp .env.example .env   # fill in TAVILY_API_KEY, GROQ_API_KEY, DIGEST_TO_EMAIL, SMTP_*
python main.py
```

Pages (left-hand nav in [`Main.qml`](Main.qml)):
- **Dashboard** — run a scan, review today's jobs/news, email the digest. Each job card
  can draft CV highlights + a cover letter for that specific role
  ([`ApplicationMaterialsPanel.qml`](ApplicationMaterialsPanel.qml)).
- **History** — every opportunity/news item ever found, found-vs-emailed status, newest
  first ([`HistoryCard.qml`](HistoryCard.qml)).
- **Settings** — email delivery, API keys, search queries, and the user's CV/background
  text used for application-material drafting.

macOS builds are produced by [`.github/workflows/build-macos.yml`](.github/workflows/build-macos.yml)
via PyInstaller, which bundles all four QML files (`Main.qml`, `SettingsField.qml`,
`HistoryCard.qml`, `ApplicationMaterialsPanel.qml`) via `--add-data`.

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

Routes: `GET /api/health`, `POST /api/register`, `POST /api/scan`, `POST /api/send`,
`POST /api/dismiss`, `GET /api/history`.

```bash
cd backend
pip install -r requirements.txt
uvicorn app:app --reload
```
Interactive docs at `http://127.0.0.1:8000/docs`.

Deployed via [`Dockerfile`](Dockerfile) + [`railway.json`](railway.json) (Railway). The
Dockerfile builds from the repo root rather than `backend/` alone, because the backend
imports `digest_engine.py`, `config.py`, and `send_report.py` from the parent directory.

**Not yet built**: billing (Stripe), a real scheduler (the cache refreshes lazily on
request rather than on a cron), per-user custom queries (everyone gets the shared
default set), and AI-assisted application materials (currently desktop-only).

## Mobile app

Flutter client for the backend, living in [`mobile_app/`](mobile_app/). Talks to
`backend/app.py` via [`api_client.dart`](mobile_app/lib/api_client.dart) using the
per-user API key from `/api/register`; never holds Tavily/Groq/SMTP credentials itself.

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
send_report.py          SMTP delivery
build_archive.py        GitHub Pages archive builder
main.py, *.qml           Desktop app (PySide6/QML)
backend/                 FastAPI multi-user backend (app.py, db.py, auth.py)
mobile_app/              Flutter mobile client
.github/workflows/       Scheduled digest + macOS build CI
reports/, docs/          Generated HTML digests / GitHub Pages archive (not hand-edited)
```

## Roadmap notes

Product direction discussed alongside this codebase, for whoever picks this up next:

- **Free vs. premium split**: free = manual scans, fixed query set, capped history;
  premium = scheduled auto-scans, unlimited custom queries/history, multi-channel
  alerts, and AI-assisted application materials (the CV-highlights/cover-letter
  feature currently shipped on desktop only).
- **BYO-key vs. hosted-key tension**: the desktop app is BYO-API-key (can't be metered
  or monetized per-user); the backend already has the hosted-keys + per-user auth
  needed to meter usage and gate features by plan — moving the desktop app onto the
  backend (instead of calling `digest_engine.py` in-process) is the main blocker to
  real tiering.
