# Design

This complements [README.md](README.md) (what's where, how to run each surface) with
*why* the system is shaped the way it is — the architecture decisions, their rationale,
and the open risks/questions that came out of building it. Written for whoever picks
this up next, including a future session of whoever's working on this with an AI
assistant.

## System shape

One core pipeline, four surfaces:

```
                    ┌─────────────────┐
                    │  digest_engine.py │   search (Tavily) → summarize (Groq)
                    │  (the only code   │   → dedupe → email/store
                    │  that talks to    │
                    │  Tavily/Groq)     │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────────┐
              │              │                  │
      ┌───────▼──────┐ ┌─────▼──────┐  ┌────────▼────────┐
      │ backend/app.py│ │ Headless   │  │  (desktop used   │
      │ FastAPI,       │ │ runner     │  │  to call this    │
      │ hosted keys,   │ │ (GitHub    │  │  directly — see  │
      │ multi-user     │ │ Actions)   │  │  "Desktop" below)│
      └───────┬────────┘ └────────────┘  └──────────────────┘
              │
       ┌──────┴──────┐
       │             │
┌──────▼─────┐ ┌─────▼──────┐
│ Mobile app  │ │ Desktop app │
│ (Flutter)   │ │ (PySide6/QML)│
└─────────────┘ └─────────────┘
```

Mobile and desktop are both now thin HTTP clients of `backend/app.py`. Neither holds
Tavily/Groq/SMTP credentials; both authenticate with a per-user API key from
`/api/register`. This wasn't always true — see "Desktop's architecture" below.

## Core design decisions

### One shared scan, not one per user

`backend/_get_shared_results()` runs the default query set once, caches it for
`CACHE_TTL_SECONDS` (1 hour), and fans the same results out to every registered user.
Personalization happens only at the per-user dedup layer (`seen_items` table), not at
the search step. This is *the* load-bearing cost-control decision in the whole system:
Tavily/Groq usage for the shared scan stays roughly flat as the user count grows,
instead of scaling with subscribers.

**Consequence**: anything that bypasses this cache — ad-hoc custom search
(`/api/search`), AI application materials (`/api/materials`) — is a real, uncached,
billable API call per invocation, and is deliberately rate-capped per user per day on
the free plan for exactly that reason (`FREE_SEARCH_DAILY_CAP`,
`FREE_MATERIALS_DAILY_CAP` in `backend/app.py`). Any new feature that calls
`digest_engine`'s Tavily/Groq functions outside the shared-cache path needs the same
treatment, or it reintroduces per-user cost scaling.

### Hosted keys, not BYO keys

The backend holds one operator-owned set of Tavily/Groq/SMTP/Telegram credentials.
Clients never see them. This is what makes metering, plan tiers, and per-user caps
possible at all — a BYO-key client (which desktop used to be) can't be metered, because
there's no server in the loop to enforce anything.

**Desktop's architecture** changed on 2026-09-19 for exactly this reason: it used to run
`digest_engine.py` in-process with the user's own keys (unmetered, separate product from
mobile in every way that mattered). It's now a client of the same backend mobile uses,
via `backend_client.py`. See `feature/desktop-hosted-backend` (not yet merged to `main`
— check memory or `git branch -a` before assuming this is live) and
[CHANGELOG.md](CHANGELOG.md) for the full list of what that changed.

### Dedup: two different mechanisms depending on who's asking

- **Backend** (multi-user): per-user `seen_items` rows in SQLite, keyed by `(user_id,
  url)`. An item is only marked seen once actually delivered — emailed (`/api/send`) or
  explicitly dismissed (`/api/dismiss`). A plain `/api/scan` pull does *not* mark
  anything seen.
- **Headless runner / anything still calling `digest_engine.py` directly**: a single
  global `seen_items.json` (url → date), shared across whoever runs it. Not per-user —
  there's only one "user" in that context.

These two are intentionally separate stores; don't conflate them. If desktop is ever
extended in a way that touches `digest_engine.py` directly again, it should go through
the backend's per-user mechanism, not the global JSON file — mixing them silently
reintroduces cross-user or cross-installation leakage.

### The AI's job is narrow and grounded, on purpose

Every Groq call uses `response_format: json_object` against a fixed schema, and every
prompt explicitly forbids inventing anything not present in the search results or the
user's own pasted CV. There's no chat interface, no persona, no freeform generation
surface — the model does exactly two jobs (classify/summarize search results; draft
CV highlights + a cover letter from the user's own real background) and nothing else.
This is a deliberate product boundary, not a limitation to "fix" — see the "how is this
different from ChatGPT" framing in project history if extending the AI surface: keep new
LLM usage retrieval-grounded and schema-constrained rather than opening up general
conversation.

## Client-server contract

`backend/app.py` routes (see the file itself for the authoritative list — this doc will
drift):

- **Account**: `POST /api/register`, `GET /api/verify`, `POST /api/resend-verification`,
  `GET /api/me`, `POST /api/upgrade-request`
- **Discovery**: `POST /api/scan` (shared cache pull), `POST /api/search` (ad-hoc,
  capped)
- **Actions**: `POST /api/send` (email + mark seen), `POST /api/dismiss` (mark seen only)
- **Data**: `GET /api/history`, `GET/PUT /api/cv`, `POST /api/materials`,
  `GET/PUT /api/alerts` (premium Slack/Telegram)

Auth is one header (`X-API-Key`), one SQLite lookup (`backend/auth.py`) — no session,
no OAuth. `require_user` vs `require_verified_user` is the only access-control axis
today; there's no per-plan route gating beyond the caps enforced inline in each handler.

## Known gaps and risks (as of 2026-09-19)

Carried over from a deployment-architecture discussion — not yet acted on except where
noted:

- **API keys stored in plaintext** in `users.api_key` (SQLite). Should be hashed before
  storage; currently a DB leak is an instant full-account-takeover for every user.
- **No account recovery.** `users.email` has no UNIQUE constraint — re-registering the
  same email silently creates a second, orphaned account instead of recovering the
  first. A user who loses their API key has no way back into their existing account.
- **Unconfirmed**: whether the Railway persistent volume for `DB_PATH` is actually
  mounted. If not, every redeploy wipes every user's account, CV, and history.
- **No real billing.** Plan upgrades are a manual review of `/api/upgrade-request`
  entries. This is the ceiling on monetizing everything else in the system.
- **No per-user saved query lists on the backend.** Desktop used to have a local raw
  query-list editor (removed in the hosted-backend migration); the backend only offers
  the one shared default set plus ad-hoc single-query search. If that flexibility is
  wanted again, it needs a real backend feature (a `queries` table, an endpoint), not a
  per-client hack.

## Open product questions

- **Niche vs. general.** The product was built narrowly for London
  consulting/PE/VC/impact investing job search. Ad-hoc custom search now lets any user
  search for anything, which quietly broadens the addressable market — this was an
  incidental engineering consequence, not a deliberate repositioning decision. Worth a
  real conversation before leaning into or constraining it further.
- **Desktop's long-term fate.** It's now feature-equivalent to mobile via the hosted
  backend, but two separate client codebases (Dart/Flutter and Python/QML) still need
  independent maintenance for the same feature set. Whether that's worth it depends on
  whether desktop actually has meaningfully different users than mobile.
