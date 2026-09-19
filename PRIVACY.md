# Privacy Policy

**Last updated: 2026-09-19**

> **This is a working draft, not legal advice.** Have a qualified lawyer review
> this before public launch — especially UK/EU data protection compliance
> (UK GDPR), since the product's audience is UK-based job seekers and it
> stores personal data (CVs). Fill in the `[bracketed]` placeholders before
> publishing.

This policy covers JobHuntAI, operated by **[KeynetikSystems / your legal
name]** ("we", "us"). Contact: **[support@yourdomain.example]**.

## Two very different data flows — read this first

JobHuntAI ships as two separate apps that handle your data completely
differently:

- **Desktop app**: runs entirely on your own computer. It uses your own
  Tavily/Groq/email credentials, and **never sends any of your data to us**
  — not your searches, not your CV, nothing. Your `.env`, `history.json`,
  and `cv.txt` files stay on your machine.
- **Mobile app**: talks to our hosted backend server, which **does** store
  your data as described below, because the backend holds the shared API
  keys and does the work on your behalf.

If you only use the desktop app, the rest of this policy about server-side
data doesn't apply to you — there's no server-side data to describe.

## What we collect (mobile / backend only)

- **Email address**, when you register.
- **CV / background text**, if you paste it into Settings, used only to
  generate tailored application materials for jobs you choose to draft for.
- **Job and news items you've been shown** ("history"), so we don't show you
  the same thing twice and so the History screen works.
- **Usage counts** (e.g. how many AI drafts you've requested today), to
  enforce free-plan limits.
- **Slack webhook URL / Telegram chat ID**, only if you configure alerts.
- Standard server logs (IP address, timestamps) for debugging and abuse
  prevention.

We do not collect payment information — there is currently no billing.

## How we use it

- To deliver the job/news digest you asked for.
- To generate CV highlights and cover letters for opportunities you
  specifically choose to draft for.
- To avoid re-showing you things you've already seen.
- To enforce free-tier usage limits fairly.
- To send you a one-time email verification link when you register, and
  transactional alerts if you've configured them.

We do not sell your data, and we do not use your CV or search history for
advertising.

## Third parties we share data with

Running the service requires sending some data to these processors:

- **Tavily** (search) — receives search queries, not your personal data.
- **Groq** (AI summarization / drafting) — receives job listing text and,
  when you request application materials, your CV text and the specific
  job you're applying to.
- **Our SMTP provider** — receives your email address to deliver digests
  and the verification email.
- **Slack / Telegram** — if you configure alerts, receives job/news summaries
  (not your CV) via the webhook/chat you set up yourself.

We don't control these third parties' own data practices; see their
respective privacy policies.

## Data retention and deletion

We keep your account data until you ask us to delete it. **To request
deletion, email us at [support@yourdomain.example]** — there's currently no
self-serve "delete my account" button in the app (a known gap; a self-serve
option should be added before wide release).

## Security

- We don't use passwords — access is by a random API key issued at
  registration, which functions like a password. Don't share it.
- Your account isn't usable until you verify you own the email you
  registered with.
- Data is stored in a server-side database; reasonable measures are taken
  to secure it, but no system is perfectly secure.

## Your rights

If you're in the UK/EU, you have the right to access, correct, or delete
your personal data, and to object to or restrict certain processing. Contact
us at **[support@yourdomain.example]** to exercise these rights.

## Children's privacy

This service isn't directed at children and isn't intended for use by
anyone under 16.

## International data transfers

Some processors above (e.g. Groq, Tavily) may process data outside the
UK/EU. **[Confirm their data-transfer safeguards before relying on this
policy.]**

## Changes to this policy

We may update this policy as the product changes. Material changes will be
reflected here with an updated date.
