"""Core pipeline: search (Tavily) -> summarize (Groq) -> dedupe -> email.

Standalone — no Claude Code / Anthropic API involved. Used by both the
JobHuntAI desktop GUI (main.py) and headless runs (Windows Task Scheduler calls
this file directly: `python digest_engine.py`).

All HTTP calls use only the standard library, so nothing needs `pip install`.
"""
import json
import re
import time
import urllib.request
import urllib.error
import ssl
import certifi

# SSL context for secure HTTPS connections
ssl_context = ssl.create_default_context(cafile=certifi.where())

from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, datetime
from html import escape
from pathlib import Path

from config import ROOT, load_env
from send_report import send_report

SEEN_FILE = ROOT / "seen_items.json"
REPORTS_DIR = ROOT / "reports"
QUERIES_FILE = ROOT / "queries.json"

TAVILY_URL = "https://api.tavily.com/search"
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
DEFAULT_GROQ_MODEL = "openai/gpt-oss-120b"

DEFAULT_JOB_QUERIES = [
    # Consulting
    "strategy consulting jobs London hiring",
    "management consulting graduate scheme London",
    "boutique consulting firm London hiring experienced",
    "strategy consulting jobs Manchester hiring",
    "strategy consulting jobs Edinburgh hiring",
    "management consulting jobs Birmingham hiring",
    "consulting jobs Scotland hiring",
    "strategy consulting jobs UK hiring",
    "management consulting graduate scheme UK",
    # Impact investing
    "impact investing jobs London",
    "impact fund analyst London hiring",
    "impact investing jobs Scotland",
    "impact investing jobs Manchester",
    "impact investing jobs UK",
    "impact fund analyst UK hiring",
    # Private equity
    "private equity analyst London hiring",
    "private equity associate London vacancy",
    "private equity analyst Manchester hiring",
    "private equity analyst Edinburgh hiring",
    "private equity jobs Birmingham hiring",
    "private equity jobs Scotland hiring",
    "private equity analyst UK hiring",
    "private equity associate UK vacancy",
    # Venture capital
    "venture capital associate London jobs",
    "venture capital analyst London hiring",
    "venture capital jobs Manchester hiring",
    "venture capital jobs Edinburgh hiring",
    "venture capital jobs Scotland hiring",
    "venture capital associate UK jobs",
    "venture capital analyst UK hiring",
]

DEFAULT_NEWS_QUERIES = [
    "private equity news London this week",
    "private equity news Scotland this week",
    "private equity news Manchester this week",
    "venture capital Europe news this week",
    "UK private equity deal announcement",
    "European VC funding round London",
    "Scotland VC funding round news",
    "impact investing news Europe",
    "UK private equity news this week",
    "UK venture capital funding news this week",
    "UK impact investing news this week",
    "UK investment firm acquisition announcement",
]

JOB_SUMMARY_PROMPT = """You are filtering raw web search results down to genuine, currently-open \
job listings for roles based in the UK in: management/strategy consulting, \
impact investing, private equity, or venture capital.

Raw search results (JSON array of title/url/content):
{raw_json}

From these, select only results that are actually specific job postings or \
clear hiring signals (ignore generic "browse jobs" landing pages, unrelated \
content, and anything not UK-based). For each one, write a concise \
one-line note explaining the role and why it's notable. Do not invent \
anything not present in the search results.

Respond with ONLY a JSON object in this exact shape, nothing else:
{{"items": [{{"title": "...", "firm": "...", "note": "...", "url": "..."}}]}}
If nothing qualifies, respond with: {{"items": []}}
"""

NEWS_SUMMARY_PROMPT = """You are filtering raw web search results down to the most notable private \
equity / venture capital news from London and Europe broadly, from the last \
week. Each result's "content" field is a substantial excerpt of the actual \
article, not just a headline — read it and synthesize the real substance \
(what happened, who's involved, why it matters), not just the headline.

Raw search results (JSON array of title/url/content):
{raw_json}

Select the 5-10 most significant, genuinely PE/VC-relevant items. For each, \
write a 2-3 sentence summary in your own words covering the key facts and \
why it matters. Do not quote the source directly except for one short phrase \
under 15 words if truly necessary. Do not invent anything not present in the \
search results.

Respond with ONLY a JSON object in this exact shape, nothing else:
{{"items": [{{"headline": "...", "source": "...", "summary": "...", "url": "..."}}]}}
If nothing qualifies, respond with: {{"items": []}}
"""


def _extract_retry_after(body: str) -> float | None:
    """Groq's 429 body includes 'Please try again in 6.17s' — use their number instead of guessing."""
    match = re.search(r"try again in ([\d.]+)s", body)
    return float(match.group(1)) if match else None


def _http_post_json(url: str, payload: dict, headers: dict, max_retries: int = 4) -> dict:
    """POSTs JSON with retry+backoff on transient failures (timeouts, 429, 5xx).
    Permanent errors (bad key, bad model, malformed request) raise immediately."""
    data = json.dumps(payload).encode("utf-8")
    full_headers = {"User-Agent": "OpportunityScanner/1.0", **headers}
    last_error = None
    for attempt in range(max_retries):
        req = urllib.request.Request(url, data=data, headers=full_headers, method="POST")
        wait = 2 ** (attempt + 1)  # default backoff: 2s, 4s, 8s, 16s
        try:
            with urllib.request.urlopen(req, timeout=60, context=ssl_context) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            last_error = RuntimeError(f"HTTP {e.code} from {url}: {body[:500]}")
            if e.code not in (429, 500, 502, 503, 504) or attempt == max_retries - 1:
                raise last_error from e
            if e.code == 429:
                retry_after = _extract_retry_after(body)
                if retry_after is not None:
                    wait = retry_after + 0.5
        except urllib.error.URLError as e:
            last_error = RuntimeError(f"Network error calling {url}: {e.reason}")
            if attempt == max_retries - 1:
                raise last_error from e
        time.sleep(wait)
    raise last_error


def tavily_search(query: str, api_key: str, topic: str = "general", days: int | None = None,
                   max_results: int = 8, include_raw_content: bool = False) -> list:
    payload = {
        "api_key": api_key,
        "query": query,
        "topic": topic,
        "search_depth": "basic" if not include_raw_content else "advanced",
        "max_results": max_results,
        "include_answer": False,
        "include_raw_content": include_raw_content,
    }
    if days:
        payload["days"] = days
    result = _http_post_json(TAVILY_URL, payload, {"Content-Type": "application/json"})
    return result.get("results", [])


def groq_complete(prompt: str, api_key: str, model: str) -> dict:
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    }
    result = _http_post_json(GROQ_URL, payload, headers)
    text = result["choices"][0]["message"]["content"]
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {"items": [], "_parse_error": text[:500]}


def load_seen() -> dict:
    if SEEN_FILE.exists():
        return json.loads(SEEN_FILE.read_text(encoding="utf-8"))
    return {}


def save_seen(seen: dict) -> None:
    SEEN_FILE.write_text(json.dumps(seen, indent=2), encoding="utf-8")


def load_queries() -> tuple[list, list]:
    """Reads queries.json if present (edited via the GUI's Queries tab), else the built-in defaults."""
    if QUERIES_FILE.exists():
        data = json.loads(QUERIES_FILE.read_text(encoding="utf-8"))
        return (data.get("job_queries") or DEFAULT_JOB_QUERIES,
                data.get("news_queries") or DEFAULT_NEWS_QUERIES)
    return list(DEFAULT_JOB_QUERIES), list(DEFAULT_NEWS_QUERIES)


def save_queries(job_queries: list, news_queries: list) -> None:
    QUERIES_FILE.write_text(
        json.dumps({"job_queries": job_queries, "news_queries": news_queries}, indent=2),
        encoding="utf-8",
    )


def gather_and_filter(queries: list, api_key: str, seen: dict, topic: str, days: int | None,
                       log=lambda m: None, max_results: int = 8, include_raw_content: bool = False,
                       content_chars: int = 300) -> list:
    """Runs all queries concurrently. One query failing (even after retries) doesn't kill the batch.

    include_raw_content=True fetches full scraped article text (Tavily "advanced" search) instead
    of a short snippet — used for news, where actually reading the article matters. Left off for
    jobs, where a title + short snippet is enough to judge relevance and keeps searches cheap/fast.
    """
    raw, seen_urls_this_run = [], set()
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = {
            executor.submit(tavily_search, q, api_key, topic, days, max_results, include_raw_content): q
            for q in queries
        }
        for future in as_completed(futures):
            q = futures[future]
            try:
                results = future.result()
            except Exception as e:
                log(f"  query failed ({q!r}): {e}")
                continue
            for r in results:
                url = r.get("url")
                if not url or url in seen or url in seen_urls_this_run:
                    continue
                seen_urls_this_run.add(url)
                if include_raw_content:
                    text = r.get("raw_content") or r.get("content") or ""
                else:
                    text = r.get("content") or ""
                raw.append({"title": r.get("title", ""), "url": url, "content": text[:content_chars]})
    return raw


MAX_RESULTS_PER_SUMMARY = 25  # keeps requests under Groq free-tier TPM limits


def _summarize_with_shrink(prompt_template: str, raw_results: list, groq_key: str, groq_model: str, log,
                            max_results: int = MAX_RESULTS_PER_SUMMARY) -> list:
    """Summarizes via Groq. If the payload trips the free-tier tokens-per-minute cap (HTTP 413),
    halves the input and retries — a couple of times if needed — instead of failing the whole run."""
    results = raw_results[:max_results]
    for _ in range(3):
        try:
            return groq_complete(prompt_template.format(raw_json=json.dumps(results)), groq_key, groq_model).get("items", [])
        except RuntimeError as e:
            if "HTTP 413" in str(e) and len(results) > 4:
                log(f"  payload too large for Groq's rate limit — retrying with fewer results ({len(results)} -> {len(results)//2})")
                results = results[:len(results) // 2]
                continue
            raise
    return []


def build_html(jobs: list, news: list) -> str:
    today = date.today().strftime("%A %d %B %Y")
    parts = [
        '<div style="font-family: Arial, sans-serif; max-width: 640px; margin: 0 auto;">',
        f'<h2 style="color:#1a1a1a;">Opportunity &amp; PE/VC Digest &mdash; {today}</h2>',
        '<h3 style="color:#1a1a1a;">Career opportunities (London)</h3>',
    ]
    if jobs:
        parts.append("<ul>")
        for j in jobs:
            parts.append(
                f'<li><b>{escape(j.get("title",""))}</b>'
                f'{" &mdash; " + escape(j["firm"]) if j.get("firm") else ""}'
                f'<br>{escape(j.get("note",""))}'
                f'<br><a href="{escape(j.get("url",""))}">{escape(j.get("url",""))}</a></li><br>'
            )
        parts.append("</ul>")
    else:
        parts.append("<p>No new listings found this week.</p>")

    parts.append('<h3 style="color:#1a1a1a;">PE/VC news &mdash; London &amp; Europe</h3>')
    if news:
        parts.append("<ul>")
        for n in news:
            parts.append(
                f'<li><b>{escape(n.get("headline",""))}</b>'
                f'{" &mdash; " + escape(n["source"]) if n.get("source") else ""}'
                f'<br>{escape(n.get("summary",""))}'
                f'<br><a href="{escape(n.get("url",""))}">{escape(n.get("url",""))}</a></li><br>'
            )
        parts.append("</ul>")
    else:
        parts.append("<p>No notable news found this week.</p>")
    parts.append("</div>")
    return "\n".join(parts)


def _failure_html(error_msg: str) -> str:
    return (
        '<div style="font-family: Arial, sans-serif;">'
        '<h2 style="color:#b00020;">Weekly digest failed</h2>'
        f'<p>The run on {date.today().isoformat()} did not complete. Error:</p>'
        f'<pre style="background:#f4f4f4;padding:8px;white-space:pre-wrap;">{escape(error_msg)}</pre>'
        '<p>Check run.log in the OpportunityScanner folder for full details.</p>'
        '</div>'
    )


def send_failure_alert(error_msg: str) -> None:
    """Best-effort notification so an unattended headless failure doesn't go unnoticed.
    Swallows its own errors — if we can't email, there's nothing more to do."""
    try:
        env = load_env()
        to_addr = env.get("DIGEST_TO_EMAIL")
        if not to_addr:
            return
        REPORTS_DIR.mkdir(exist_ok=True)
        path = REPORTS_DIR / f"digest-{date.today().isoformat()}-FAILED.html"
        path.write_text(_failure_html(error_msg), encoding="utf-8")
        send_report(f"Opportunity Digest FAILED - {date.today().isoformat()}", path, to_addr)
    except Exception:
        pass


def collect_jobs_and_news(env: dict, seen: dict, log) -> tuple[list, list]:
    tavily_key = env.get("TAVILY_API_KEY")
    groq_key = env.get("GROQ_API_KEY")
    groq_model = env.get("GROQ_MODEL") or DEFAULT_GROQ_MODEL
    job_queries, news_queries = load_queries()

    log("Searching for job listings (Tavily)...")
    raw_jobs = gather_and_filter(job_queries, tavily_key, seen, topic="general", days=None, log=log)
    log(f"  {len(raw_jobs)} candidate job results after dedup")

    log("Searching for PE/VC news (Tavily, fetching full article text)...")
    raw_news = gather_and_filter(news_queries, tavily_key, seen, topic="news", days=10, log=log,
                                  max_results=4, include_raw_content=True, content_chars=1500)
    log(f"  {len(raw_news)} candidate news results after dedup")

    log("Summarizing job listings (Groq)...")
    jobs = _summarize_with_shrink(JOB_SUMMARY_PROMPT, raw_jobs, groq_key, groq_model, log) if raw_jobs else []
    log(f"  {len(jobs)} job listings selected")

    log("Summarizing news (Groq)...")
    news = _summarize_with_shrink(NEWS_SUMMARY_PROMPT, raw_news, groq_key, groq_model, log, max_results=10) if raw_news else []
    log(f"  {len(news)} news items selected")

    return jobs, news


def finalize_and_send(jobs: list, news: list, log=print, to_addr: str | None = None,
                       skip_email: bool = False) -> Path:
    """Writes the dated report and marks jobs/news URLs seen. Used by run_digest's own
    non-dry-run path, the GUI's separate "Email me this" action, and the backend (which passes
    a specific user's address instead of relying on the single DIGEST_TO_EMAIL in .env).

    skip_email=True still writes the real report file and updates seen_items.json (so the
    archive/dedup state advances normally) but skips the SMTP send — used by the GitHub Actions
    workflow when only the archive is wanted, not the email. Defaults to False so existing
    desktop-app call sites are unaffected."""
    html = build_html(jobs, news)
    REPORTS_DIR.mkdir(exist_ok=True)
    html_path = REPORTS_DIR / f"digest-{date.today().isoformat()}.html"
    html_path.write_text(html, encoding="utf-8")

    if skip_email:
        log("Skipping email send (skip_email=True) — report saved and seen store will still update.")
    else:
        env = load_env()
        to_addr = to_addr or env.get("DIGEST_TO_EMAIL")
        if not to_addr:
            raise RuntimeError("Missing DIGEST_TO_EMAIL in .env")
        log(f"Sending email to {to_addr}...")
        send_report(f"Daily Opportunity & PE/VC Digest - {date.today().isoformat()}", html_path, to_addr)
        log("Sent.")

    seen = load_seen()
    for item in jobs:
        if item.get("url"):
            seen[item["url"]] = date.today().isoformat()
    for item in news:
        if item.get("url"):
            seen[item["url"]] = date.today().isoformat()
    save_seen(seen)
    return html_path


def run_digest(log=print, dry_run: bool = False, skip_email: bool = False) -> tuple[Path, bool, list, list]:
    """Runs the full pipeline once. Returns (html_path, sent, jobs, news).

    dry_run=True skips sending the email AND skips updating the seen store,
    so it's safe to use for previewing without affecting the next real run.

    skip_email=True (and dry_run=False) still writes the real dated report and updates
    seen_items.json — only the SMTP send is skipped. Use this when you want the archive/dedup
    state to advance normally (e.g. for a GitHub Pages archive) without sending mail. Ignored
    if dry_run=True, since dry runs never send email anyway. Defaults to False, so existing
    call sites (desktop app, headless __main__) keep emailing exactly as before.
    """
    env = load_env()
    tavily_key = env.get("TAVILY_API_KEY")
    groq_key = env.get("GROQ_API_KEY")
    to_addr = env.get("DIGEST_TO_EMAIL")

    if not tavily_key or not groq_key:
        raise RuntimeError("Missing TAVILY_API_KEY or GROQ_API_KEY in .env")
    if not dry_run and not skip_email and not to_addr:
        raise RuntimeError("Missing DIGEST_TO_EMAIL in .env")

    seen = load_seen()
    jobs, news = collect_jobs_and_news(env, seen, log)

    if dry_run:
        html = build_html(jobs, news)
        REPORTS_DIR.mkdir(exist_ok=True)
        html_path = REPORTS_DIR / f"digest-{date.today().isoformat()}-preview.html"
        html_path.write_text(html, encoding="utf-8")
        log(f"Saved digest to {html_path}")
        log("Preview only — not sending email or updating the seen store.")
        return html_path, False, jobs, news

    if not jobs and not news:
        log("Nothing new this week." + ("" if skip_email else " Email still sent (says so explicitly) rather than skipped silently."))

    html_path = finalize_and_send(jobs, news, log=log, skip_email=skip_email)
    log(f"Saved digest to {html_path}")
    return html_path, not skip_email, jobs, news


if __name__ == "__main__":
    import os

    def _log(msg):
        print(f"[{datetime.now().isoformat(timespec='seconds')}] {msg}")

    # Set SKIP_EMAIL=true in the environment (e.g. a GitHub Actions workflow) to run the full
    # pipeline and update seen_items.json / write the dated report, without sending an email.
    # Unset or any other value keeps the original always-emails behavior.
    skip_email = os.environ.get("SKIP_EMAIL", "").strip().lower() in ("1", "true", "yes")

    try:
        _log("Starting headless run..." + (" (email disabled)" if skip_email else ""))
        run_digest(log=_log, skip_email=skip_email)
    except Exception as e:
        _log(f"FAILED: {e}")
        send_failure_alert(str(e))
        raise
