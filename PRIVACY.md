# Privacy Policy

**Last updated: 2026-09-21**

> **This is a working draft, not legal advice.** Have a qualified lawyer review
> this before public launch — especially UK/EU data protection compliance
> (UK GDPR), since the product's audience is UK-based job seekers and it
> stores personal data (profile/work history). Fill in the remaining
> `[bracketed]` placeholder (your full legal name) before publishing.

This policy covers JobHuntAI ("Ledger" in-app), operated by **[full legal
name]**, an individual (not a registered company) ("we", "us"). Contact:
**keynetiqsystems@gmail.com**.

## Who this policy applies to

This app is aimed at UK-based job seekers, so this policy is written to meet
UK GDPR — and UK GDPR applies to processing UK residents' personal data
regardless of where the operator is located, so this isn't affected by
**[operator's jurisdiction — see below]**. If you're outside the UK/EU, some
of the rights described below (e.g. under "Your rights") may not apply to
you by law, though we don't distinguish in practice.

## How the app works — one data flow, not several

JobHuntAI is a single app (built with Flutter, for mobile and desktop) that
talks to our hosted backend server for everything — search, summarization,
your saved profile, and history. Nothing runs locally with your own API keys;
the backend always does the work on your behalf and stores the data described
below.

## What we collect

- **Email address**, when you register — verified before your account can
  send or receive anything.
- **Personal profile**, if you fill it in under Settings: full name, phone
  number, location, LinkedIn/portfolio URL, work history, education, and
  skills. Used only to generate tailored application materials for
  opportunities you specifically choose to draft for — never sent anywhere
  except to our AI provider (Groq), alongside the one role you asked about.
- **Job and news items you've been shown** ("history"), so we don't show you
  the same thing twice and so the History screen works.
- **Usage counts** (e.g. how many AI drafts or custom searches you've made
  today), to enforce free-plan limits.
- **Slack webhook URL / Telegram chat ID**, only if you configure alerts
  (premium feature).
- **Device access keys** — each device you connect (phone, another phone,
  desktop) gets its own key tied to your account, so signing in on a new
  device doesn't log out an existing one.
- Standard server logs (IP address, timestamps) for debugging and abuse
  prevention.

We do not collect payment information — there is currently no billing
(subscriptions are planned but not yet built).

## How we use it

- To deliver the job/news results you asked for (a shared scan or your own
  search).
- To generate CV highlights and cover letters for opportunities you
  specifically choose to draft for.
- To avoid re-showing you things you've already seen.
- To enforce free-tier usage limits fairly.
- To send you a one-time email verification link when you register, an access
  key if you register an already-verified email from a new device, and
  transactional alerts if you've configured them.

We do not sell your data, and we do not use your profile or search history
for advertising.

## Third parties we share data with

Running the service requires sending some data to these processors:

- **Tavily** (search) — receives search queries, not your personal data.
- **Groq** (AI summarization / drafting) — receives job listing text and,
  when you request application materials, your profile details and the
  specific job you're applying to.
- **Resend** (email delivery) — receives your email address to deliver
  verification links, access-key recovery emails, and digests.
- **Slack / Telegram** — if you configure alerts, receives job/news summaries
  (not your profile) via the webhook/chat you set up yourself.

We don't control these third parties' own data practices; see their
respective privacy policies.

## Data retention and deletion

We keep your account data until you ask us to delete it. **To request
deletion, email us at keynetiqsystems@gmail.com** — there's currently no
self-serve "delete my account" button in the app (a known gap; a self-serve
option should be added before wide release).

## Security

- We don't use passwords — access is by a random key issued at registration
  or when you connect a new device, which functions like a password. Don't
  share it.
- Your account isn't usable until you verify you own the email you
  registered with.
- Data is stored in a server-side database; reasonable measures are taken
  to secure it, but no system is perfectly secure.

## Your rights

If you're in the UK/EU, you have the right to access, correct, or delete
your personal data, and to object to or restrict certain processing. Contact
us at **keynetiqsystems@gmail.com** to exercise these rights.

## Children's privacy

This service isn't directed at children and isn't intended for use by
anyone under 16.

## International data transfers

All three processors we send data to (Groq, Tavily, Resend) are US-based, so
your data may be processed outside the UK/EU:

- **Groq** and **Resend** both maintain a standard Data Processing Addendum
  that automatically applies through their normal terms of service (no
  separate signature required), incorporating the EU Standard Contractual
  Clauses and the UK's International Data Transfer Addendum. Resend also
  participates in the EU-U.S. Data Privacy Framework, an additional
  recognized transfer mechanism.
- **Tavily** does not offer a standard Data Processing Agreement to
  non-enterprise customers — only via custom negotiation, which we have not
  pursued. This is a real, currently-unaddressed gap; it's mitigated in
  practice by Tavily receiving only search query text, not your profile or
  other personal data (see "What we collect" above), but it should still be
  resolved — either a negotiated DPA with Tavily, or replacing it with a
  processor that offers standard GDPR-compliant terms — before relying on
  this policy for a real launch.

**[Have a lawyer confirm this assessment and whether it's sufficient —
this is our own reading of each processor's published terms as of
2026-09-21, not a legal opinion.]**

## Changes to this policy

We may update this policy as the product changes. Material changes will be
reflected here with an updated date.
