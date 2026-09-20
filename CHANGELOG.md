# Changelog

## 2026-09-20

### Add Personal Profile section, replacing the single freeform CV field

Settings (mobile and desktop) gained a "Personal Profile" section: full name, phone,
location, LinkedIn/portfolio URL (reference fields for the user's own use when filling
out application forms elsewhere), plus work history, education, and skills as three
separate structured fields, replacing the old single "CV/background" text blob.

- **Backend**: `users.cv_text` retired in favor of seven new columns. `GET/PUT /api/cv`
  replaced by `GET/PUT /api/profile`. `digest_engine.generate_application_materials()`
  now takes a `profile: dict` instead of a `cv_text: str`, and its prompt references
  work history/education/skills as separate sections instead of one undifferentiated
  block — also now signs cover letters with the user's real name. `/api/materials`
  requires work history or skills (not just "any CV text") before drafting.
- **Migration**: existing installs get `cv_text` copied into the new `work_history`
  column (`db._migrate_cv_text_to_profile`) — can't intelligently split unstructured
  text into education/skills, so it all lands in one bucket for the user to reorganize
  themselves. Legacy column left in place afterward, unused.
- **Desktop**: `backend.cvText` → `backend.profile` (QVariantMap), `saveCv()` →
  `saveProfile(...)` (7 string params). New fields added to the Settings page.
- **Mobile**: new `UserProfile` model, `ApiClient.getCv()/saveCv()` →
  `getProfile()/saveProfile()`. Settings screen's CV section replaced with the same
  seven fields.

Verified live against an isolated backend: confirmed the `cv_text` → `work_history`
migration actually runs (simulated a legacy row, restarted the server, confirmed the
text landed in the right place), a full profile save/fetch round-trips exactly, and
`/api/materials` correctly rejects an empty profile with the new message. `flutter
analyze` and both widget tests clean; desktop verified via headless load + qmllint
(zero errors).

### Fix: single-key-per-account model broke multi-device use

Direct regression from the account-recovery fix in the 2026-09-19 hardening pass below:
connecting a second device (e.g. desktop, after already being connected on mobile) with
the same email overwrote the one `users.api_key_hash` column, silently invalidating the
first device's key on its very next request — no warning, just a 401.

Moved API keys off the `users` row entirely, into a new `device_keys` table (one row per
connected device, many-to-one with a user). Registering a new device for an
already-verified account now adds a key instead of replacing one, so mobile and desktop
(or any number of devices) can stay connected to the same account simultaneously. The
security property the recovery fix actually cared about is untouched: a new key for a
verified account is still only ever delivered by email, never returned over HTTP, so a
non-owner still can't obtain a working key just by knowing the address.

`backend/auth.py`'s `require_user` now joins `device_keys` instead of reading
`users.api_key_hash` directly. Existing installs get a two-step migration
(`db._migrate_api_key_hash_to_device_keys`, on top of the existing plaintext→hash
backfill) so whichever key a device is already using keeps working under the new model.
No client-side changes needed — the `/api/register` response shape is unchanged.

Verified live against an isolated backend (separate `DB_PATH` **and** stubbed
`TAVILY_API_KEY`/`GROQ_API_KEY`, per the credentials-isolation lesson from the earlier
incident): confirmed a second device registering doesn't invalidate the first, and
separately simulated a legacy pre-fix row and confirmed its key survives the migration
on server restart.

**Also found, not yet fixed**: `PUT /api/alerts` accepts any string for
`slack_webhook_url` with zero validation, and the server POSTs to it directly and
repeatedly (every scan refresh). A real SSRF hole — a malicious value pointing at an
internal address would have the server hit it on a schedule. See `DESIGN.md`.

## 2026-09-19

### Release-readiness hardening

Closed three of the five release blockers identified in a deployment-risk review (see
[DESIGN.md](DESIGN.md)'s "Known gaps and risks" for the full picture, including the two
still open that need a human, not code):

- **API keys hashed at rest.** `users.api_key_hash` (SHA-256) replaces plaintext
  `api_key`. Existing rows are migrated automatically (`db._backfill_api_key_hashes`);
  a database leak alone no longer hands out working credentials for every account.
- **Account recovery.** `email` is now UNIQUE. Re-registering an existing, unverified
  email safely re-issues a key directly (nothing sensitive is at stake pre-verification
  anyway); re-registering an existing, *verified* email never returns the key over HTTP
  — it's emailed to the address that already proved ownership, since handing it back
  directly would let anyone who merely knows an email hijack that account. Both clients
  (`api_client.dart`, `backend_client.py`) updated to handle the new "check your email"
  response shape.
- **CORS locked down.** `allow_origins=["*"]` → `ALLOWED_ORIGINS` env var, empty by
  default. Native clients were never affected by CORS either way (it's a browser-only
  mechanism); this only ever mattered for stopping a browser-based third party from
  calling the API cross-origin.
- **Railway volume risk converted from "unconfirmed" to "self-checking."** `db.init_db()`
  now warns loudly at startup if it detects it's running on Railway (`RAILWAY_*` env
  vars present) without a `DB_PATH` override — so a misconfigured volume shows up in
  the deploy logs instead of silently wiping every user's data on the next redeploy.

Verified against a locally-run backend instance with **both** `DB_PATH` and
`TAVILY_API_KEY`/`GROQ_API_KEY` isolated this time (see the credentials-isolation
lesson from the previous incident): confirmed keys are hashed not plaintext, an old key
is invalidated the moment a new one is issued, a verified account's re-registration
correctly withholds the key, and no duplicate rows are created.

**Not fixed here** (need a human, not more code): real billing is still a manual
`/api/upgrade-request` review; `PRIVACY.md`/`TERMS.md` haven't had actual legal review;
desktop is still missing Slack/Telegram alerts config and Privacy/Terms links versus
mobile (found during a parity re-check, not yet closed).

### Repo organization: split today's work into feature branches, now merged

Everything below this entry was developed in one working session with no intermediate
commits, then split after the fact into separate branches so each piece could be
reviewed/merged independently, mirroring the repo's existing `feature/*` convention
(`feature/history-viewer`, `feature/ai-application-materials`, also merged into `main`):

| Branch | Contains |
|---|---|
| `feature/backend-custom-search` | `POST /api/search` — shared dependency of both clients below |
| `feature/mobile-custom-search` | The "Mobile" entries below |
| `feature/desktop-hosted-backend` | The "Desktop" entries below |

All three are now merged into `main`, backend first (both clients depend on
`POST /api/search`). See the "Release-readiness hardening" entry above for what shipped
on top of this merge.

### Desktop: migrated onto the hosted backend (shared API keys)

The desktop app no longer holds its own Tavily/Groq/SMTP keys or calls `digest_engine.py`
in-process. It's now a client of `backend/app.py` — the same server the mobile app
uses — via new [backend_client.py](backend_client.py), a stdlib-`urllib` HTTP client
mirroring `mobile_app/lib/api_client.dart`. This directly closes the "two products
pretending to be one" architecture gap flagged earlier: desktop users now share the
operator's keys and the same free/premium caps as mobile, instead of desktop being a
separate, unmetered product.

- `main.py`'s `DigestBackend` rewritten: `runScan`/`runSearch`/`sendEmail`/
  `draftApplicationMaterials`/`dismissItem`/`loadHistory` all now call the backend's
  HTTP API instead of `digest_engine.py` directly. Added `connect`/`disconnect`/
  `refreshAccount`/`resendVerification`/`requestUpgrade`/`saveCv`, mirroring mobile's
  Settings actions.
- Removed entirely: local Tavily/Groq/SMTP key fields and the raw job/news query-list
  editor (no backend equivalent exists for per-user saved query lists yet — the backend
  only offers the one shared default set plus ad-hoc `/api/search`).
- Settings page rewritten: connection status box, an Account section (plan, verification,
  AI-draft usage, resend/upgrade actions) shown once connected, a Backend URL + email
  connect/disconnect flow, and CV editing that now saves to the backend instead of a
  local file.
- Real behavior changes worth knowing about: "Run scan now" now pulls from the shared,
  hourly-refreshed cache instead of triggering a fresh personalized search per click
  (necessary — a shared key can't afford a fresh search per user per click). "Email me
  this" now sends via the backend's own SMTP account, not the user's own. History now
  only shows items that were actually emailed or dismissed (matching mobile's semantics),
  not everything a scan ever surfaced — the found-vs-emailed status badge in
  `HistoryCard.qml` was removed since the backend has no such distinction.
- Updated [README.md](README.md)'s desktop section and the roadmap notes accordingly,
  and fixed several other stale claims found in the process (the two desktop feature
  branches this described as unmerged were actually merged into `main` a while ago; the
  backend's `/api/materials` and `/api/search` already existed and weren't reflected).
- Removed `digest_engine.dismiss_items()` and `search_custom_query()`'s `seen` parameter
  — both added earlier today for the desktop polish pass below, both now dead code since
  desktop calls `backend_client.dismiss()`/`.search()` instead of `digest_engine` directly.

**Caution for next time**: verifying this end-to-end against a locally-run copy of the
backend inadvertently triggered one real, live Tavily+Groq call against the real
production keys in the repo's own root `.env` — the test only isolated the database
(`DB_PATH`), not the credentials, and a freshly-started backend process always has a
cold in-memory scan cache. Register/`/api/me`/CV/dismiss/history were verified safely;
`/api/scan`/`/api/search` were not re-tested after catching this. Isolate or stub
`TAVILY_API_KEY`/`GROQ_API_KEY` before any future test that might reach `/api/scan` or
`/api/search`.

### Desktop: parity polish with the mobile app

Brought several of the mobile Dashboard/Settings redesign's interaction patterns to the
desktop app ([Main.qml](Main.qml), [main.py](main.py), [digest_engine.py](digest_engine.py)),
without touching its BYO-key/in-process architecture:

- **Per-item dismiss** — each job/news card gets a "✕" that marks just that item seen
  without emailing the whole digest (`DigestBackend.dismissItem`, backed by a new
  `digest_engine.dismiss_items()`), the desktop equivalent of mobile's swipe-to-dismiss.
- **Feed filter chips (All/Jobs/News) + seniority sort** — new [FilterChip.qml](FilterChip.qml)
  component; sorting is done in `DigestBackend.jobs` itself so the Repeater just renders
  whatever order the property returns.
- **Ad-hoc search**, additive alongside the existing query-list editor — `runSearch()` calls
  `digest_engine.search_custom_query()` directly with the user's own keys, no rate cap needed
  since (unlike the backend's mobile-facing version) desktop isn't paying a shared API bill.
  `search_custom_query()` gained an optional `seen` parameter so desktop can pass its global
  `seen_items.json` and avoid resurfacing already-dismissed/emailed items (the backend leaves
  it unset and dedupes per-user downstream instead).
- **Friendly error messages** — `_friendly_error()` in `main.py` mirrors the mobile app's
  `friendlyError()`, translating desktop's urllib-flavored network exceptions instead of
  showing raw `f"...failed: {e}"` text.
- **Settings sectioned into bordered cards** — new [SettingsSection.qml](SettingsSection.qml)
  component (mirrors mobile's `_sectionBox`) wraps Email delivery / API keys / Search queries /
  CV; nested fields switched from the section's own panel color to the darker ink background
  for visual contrast, matching the mobile equivalent.
- Fixed two dead tooltips on the Tavily/Groq key fields that were commented out in the source.

Verified with `qmllint` (zero errors; only the same "unqualified access" style warning the
file already had throughout) and a headless load (`QT_QPA_PLATFORM=offscreen`) that ran
cleanly for the full timeout window with no stderr output — `main()` exits immediately with
code -1 if the QML fails to produce root objects, so a clean run for the full window confirms
the new components resolved and bound correctly.

Deliberately not done: moving desktop onto the hosted backend (a much bigger architectural
call flagged separately, not "polish"), and no visual redesign — desktop already shared
mobile's exact color palette and fonts before this pass.

### Mobile: error-message and typography consistency sweep

Follow-up to the design pass below — the first pass fixed "raw error surfacing" and
"icon-only buttons/small type" only where explicitly cited, missing several other spots
with the same issue. This pass closes those gaps app-wide instead of piecemeal:

- Added [lib/error_utils.dart](mobile_app/lib/error_utils.dart) (`friendlyError()`) and
  switched every screen/widget that was showing a raw stringified exception to it:
  `settings_screen.dart` (connect, resend-verification, upgrade request, save alerts, save
  CV), `history_screen.dart`, and `application_materials_panel.dart`. `dashboard_screen.dart`
  now uses the shared helper instead of its own private copy.
- Added a tooltip to History's icon-only refresh button (same gap the Dashboard search
  button had already been fixed for).
- Swept the remaining sub-11px text found across the app up to 11px: `history_card.dart`'s
  date label, `inline_ad_card.dart`'s "AD" label, the "Copy" button in
  `application_materials_panel.dart`, and the Dashboard's own recent-searches label (added
  in the pass below but missed in that pass's own typography fix).

### Mobile: custom search + design pass

#### Added
- **Custom search** replaces the old fixed "Run scan now" button. `POST /api/search`
  ([backend/app.py](backend/app.py)) runs a live, user-typed Tavily query through Groq
  (`digest_engine.search_custom_query`), classifying results into the existing job/news
  card shapes. Capped at 10/day on the free plan (unlimited premium) since — unlike the
  shared scan cache — every search is a real, billable API call.
- **Feed filtering & sorting.** All / Jobs / News chips above the feed, plus a seniority
  sort toggle for jobs. Section headers ("JOBS" / "NEWS") when viewing All.
- **Result persistence.** The last search's results and query are saved on-device
  ([lib/local_store.dart](mobile_app/lib/local_store.dart)) and restored on app launch,
  so the Dashboard isn't empty every time the app is reopened.
- **Pull-to-refresh** on the Dashboard feed — re-runs the last search.
- **Recent searches.** The last 8 queries are saved and shown as tappable chips above the
  search box; a first-time user (no history yet) sees example queries instead.
- **On-device notification toggle**, available on every plan (Settings → Notifications).
  Local result notifications already fired for all users before this change but were
  undiscoverable and uncontrollable; premium's Slack/Telegram push is unaffected and
  documented separately.
- Friendlier error messages for search/dismiss failures (network errors get a plain-language
  message instead of a raw stringified exception).

#### Changed
- Settings screen restructured into clearly bordered sections (Account, Notifications,
  Backend, CV) instead of one continuous scroll of headers and fields.
- Bottom navigation icons changed to fit the "Ledger" theme (`menu_book_outlined` for
  Dashboard, `history_edu_outlined` for History); Settings keeps the universally-recognized
  gear icon.
- Search button now has a tooltip/semantic label (it was icon-only with no accessible name).
- Minor type-size and contrast cleanup on small body text.

#### Notes / deliberately out of scope
- True background push (FCM) for free users was considered and rejected for this pass —
  it needs new infrastructure (Firebase project, device token registration, a server-side
  sender) well beyond a "lighter nudge." What shipped instead is parity/visibility for the
  on-device notifications that already existed.
- A full accessibility/contrast audit (WCAG-level color contrast rework) was out of scope;
  only the concretely-flagged issues (icon-only button, undersized hint text) were fixed.

### Android build fixes

Three real, independently-verified build breaks fixed while upgrading AGP to 9.4.0 / KGP
to 2.3.20:
1. Missing core library desugaring for `flutter_local_notifications` (uses `java.time` on
   API < 26).
2. KGP 2.3.20 incremental-compiler crash when the project and the pub cache live on
   different Windows drives — worked around with `kotlin.incremental=false`.
3. Missing Flutter build-directory redirection in `android/build.gradle.kts` — Gradle was
   writing the APK under `android/app/build/...` while `flutter run` looked for it under
   the top-level `build/...`, so `gradlew assembleDebug` succeeded while `flutter run` still
   failed to find the output.
