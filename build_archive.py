"""Maintains a browsable GitHub Pages archive of past digest runs.

Run after digest_engine.run_digest() has written a fresh
reports/digest-YYYY-MM-DD.html file. This script:

  1. Copies that file into docs/ (the folder GitHub Pages serves).
  2. Scans every digest-*.html already in docs/ and rewrites docs/index.html
     as a newest-first list linking to each one, with a rough item count
     pulled from each file's <ul> sections.

Stdlib only, consistent with the rest of this project.

Usage (from repo root, after a run):
    python build_archive.py
"""
import re
import shutil
from datetime import datetime
from html import escape
from pathlib import Path

ROOT = Path(__file__).parent
REPORTS_DIR = ROOT / "reports"
DOCS_DIR = ROOT / "docs"

DATE_RE = re.compile(r"digest-(\d{4}-\d{2}-\d{2})\.html$")


def _count_list_items(html_text: str) -> tuple[int, int]:
    """Counts <li> items inside each <ul>...</ul> block. Returns (jobs, news)
    based on build_html()'s fixed section order: jobs list first, news second.
    Files with no <ul> (e.g. "no listings found" text-only sections) count as 0."""
    uls = re.findall(r"<ul>(.*?)</ul>", html_text, re.DOTALL)
    counts = [len(re.findall(r"<li[\s>]", block)) for block in uls]
    jobs = counts[0] if len(counts) > 0 else 0
    news = counts[1] if len(counts) > 1 else 0
    return jobs, news


def _copy_new_reports() -> None:
    """Copies any digest-*.html (skipping -preview and -FAILED variants) from
    reports/ into docs/, so the archive only ever grows with real sent digests."""
    if not REPORTS_DIR.exists():
        return
    DOCS_DIR.mkdir(exist_ok=True)
    for src in REPORTS_DIR.glob("digest-*.html"):
        if "preview" in src.name or "FAILED" in src.name:
            continue
        if not DATE_RE.search(src.name):
            continue
        dest = DOCS_DIR / src.name
        shutil.copy2(src, dest)


def build_index() -> Path:
    _copy_new_reports()
    DOCS_DIR.mkdir(exist_ok=True)

    entries = []
    for path in DOCS_DIR.glob("digest-*.html"):
        match = DATE_RE.search(path.name)
        if not match:
            continue
        iso_date = match.group(1)
        try:
            pretty_date = datetime.strptime(iso_date, "%Y-%m-%d").strftime("%A %d %B %Y")
        except ValueError:
            pretty_date = iso_date
        text = path.read_text(encoding="utf-8", errors="replace")
        jobs, news = _count_list_items(text)
        entries.append((iso_date, pretty_date, path.name, jobs, news))

    entries.sort(key=lambda e: e[0], reverse=True)

    rows = []
    for iso_date, pretty_date, filename, jobs, news in entries:
        rows.append(
            '<li style="margin-bottom:10px;">'
            f'<a href="{escape(filename)}" style="color:#1a1a1a;font-weight:bold;">{escape(pretty_date)}</a>'
            f'<span style="color:#666;"> &mdash; {jobs} job{"s" if jobs != 1 else ""}, '
            f'{news} news item{"s" if news != 1 else ""}</span>'
            '</li>'
        )

    body = "\n".join(rows) if rows else "<p>No digests have run yet.</p>"
    generated = datetime.now().strftime("%A %d %B %Y, %H:%M")

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Opportunity Digest Archive</title>
<meta name="robots" content="noindex">
</head>
<body style="font-family: Arial, sans-serif; max-width: 640px; margin: 40px auto; color:#1a1a1a;">
<h1>Opportunity &amp; PE/VC Digest Archive</h1>
<p style="color:#666; font-size: 13px;">Last updated {escape(generated)}</p>
<ul style="list-style: none; padding: 0;">
{body}
</ul>
</body>
</html>
"""
    index_path = DOCS_DIR / "index.html"
    index_path.write_text(html, encoding="utf-8")
    return index_path


if __name__ == "__main__":
    path = build_index()
    print(f"Archive index written to {path}")
