#!/usr/bin/env python3
"""Refresh Google Scholar citation counts into json/citations.json.

Two fetch paths, chosen automatically:

  1. SerpApi (reliable) -- used when the SERPAPI_KEY env var is set. Hits the
     google_scholar_author engine, which never gets rate-limited. Recommended
     for the scheduled GitHub Action. Free tier easily covers a weekly run.
  2. Direct profile scrape (free, no key) -- fallback when SERPAPI_KEY is
     absent. Works from residential IPs but Google frequently 429s datacenter
     IPs like GitHub's runners.

Either way the result maps each article title to the stable slug used as a
data-cite-key on research.html.

Safe by design: if the fetch is blocked / errors / returns too few articles,
or nothing changed, the script leaves json/citations.json untouched and exits
0 -- so the weekly GitHub Action stays green and NEVER overwrites good numbers
with a captcha page.

Usage:
    python3 scripts/update_citations.py            # direct scrape
    SERPAPI_KEY=xxxx python3 scripts/update_citations.py   # via SerpApi
"""
import json
import os
import re
import sys
from datetime import datetime, timezone

import requests
from bs4 import BeautifulSoup

AUTHOR_ID = "Yx02X_IAAAAJ"
PROFILE_URL = (
    f"https://scholar.google.com/citations"
    f"?user={AUTHOR_ID}&hl=en&cstart=0&pagesize=100"
)
SERPAPI_URL = "https://serpapi.com/search.json"
OUT_PATH = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "json", "citations.json")
)

# Normalized (lowercase, alphanumeric-only) title SUBSTRING -> slug.
# Matched against each Google Scholar article title, longest substring first.
# Keys for papers not yet on the profile (maternal lead, NASCAR) are included
# so they auto-populate the day they appear on Google Scholar.
TITLE_MAP = {
    "welfarecostoflatelifedepression": "chin-2022-welfare-cost-depression",
    "kratomdrinksandconsumptiontrends": "chin-2026-kratom-reddit",
    "unregulatedriseofkratomdrinks": "chin-2026-kratom-drinks-rise",
    "growingoldinruralamerica": "chin-2025-rural-america",
    "beyondincome": "chin-2026-beyond-income",
    "kratombeveragesonline": "chin-2025-kratom-beverages-online",
    "fromcheatingtolearning": "chin-2026-ai-economics",
    "longerreachoflead": "wp-longer-reach-lead",
    "airpollutionandcrime": "wp-air-pollution-crime",
    "compensationofconscience": "wp-compensation-conscience",
    "lossorgainfromseparation": "wp-loss-or-gain",
    "maternalleadexposure": "wp-maternal-lead",
    "leadedgasolineoninfanthealth": "wp-nascar-infant-health",
}

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
}


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]", "", s.lower())


def match_slug(title: str):
    n = norm(title)
    for sub in sorted(TITLE_MAP, key=len, reverse=True):
        if sub in n:
            return TITLE_MAP[sub]
    return None


def _to_int(v) -> int:
    if isinstance(v, int):
        return v
    # Google Scholar sometimes appends an asterisk to a count (e.g. "1*") and
    # may group thousands with commas. Pull the digits out rather than testing
    # isdigit(), which would wrongly read "1*" as 0 and zero out a real count.
    m = re.search(r"\d[\d,]*", str(v))
    return int(m.group().replace(",", "")) if m else 0


def scrape_serpapi(key: str):
    """Return (articles, {slug: count}) via the SerpApi Scholar Author engine."""
    params = {
        "engine": "google_scholar_author",
        "author_id": AUTHOR_ID,
        "hl": "en",
        "num": 100,
        "api_key": key,
    }
    resp = requests.get(SERPAPI_URL, params=params, timeout=45)
    resp.raise_for_status()
    payload = resp.json()
    if payload.get("error"):
        raise RuntimeError(f"SerpApi error: {payload['error']}")
    articles = payload.get("articles") or []
    found = {}
    for art in articles:
        title = art.get("title", "")
        count = _to_int((art.get("cited_by") or {}).get("value"))
        slug = match_slug(title)
        if slug:
            found[slug] = count
    return articles, found


def scrape_profile():
    """Return (rows, {slug: count}) by scraping the public profile HTML."""
    resp = requests.get(PROFILE_URL, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")
    rows = soup.select("tr.gsc_a_tr")
    found = {}
    for row in rows:
        title_el = row.select_one(".gsc_a_at")
        cite_el = row.select_one(".gsc_a_c")
        if not title_el:
            continue
        title = title_el.get_text(strip=True)
        cited = cite_el.get_text(strip=True) if cite_el else ""
        slug = match_slug(title)
        if slug:
            found[slug] = _to_int(cited)
    return rows, found


def fetch():
    """Pick the fetch path: SerpApi if a key is set, else direct scrape."""
    key = os.environ.get("SERPAPI_KEY", "").strip()
    if key:
        print("[update_citations] fetching via SerpApi.")
        return scrape_serpapi(key)
    print("[update_citations] no SERPAPI_KEY set; using direct profile scrape.")
    return scrape_profile()


def main() -> int:
    try:
        with open(OUT_PATH) as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        data = {}
    data.setdefault("source", "Google Scholar")
    data.setdefault(
        "profile",
        f"https://scholar.google.com/citations?user={AUTHOR_ID}&hl=en",
    )

    try:
        items, found = fetch()
    except Exception as e:  # network error, non-200, bad key, parse failure
        print(f"[update_citations] fetch failed: {e}. Leaving JSON unchanged.")
        return 0

    # A real result lists many articles; a consent/robot wall or error has none.
    if len(items) < 3 or not found:
        print(
            f"[update_citations] fetch returned too few articles ({len(items)}) "
            "-- likely blocked or empty. Leaving JSON unchanged."
        )
        return 0

    old_counts = dict(data.get("counts", {}))
    new_counts = dict(old_counts)
    new_counts.update(found)  # merge: preserve slugs not present in this fetch

    if new_counts == old_counts:
        print("[update_citations] no change.")
        return 0

    data["counts"] = new_counts
    data["last_updated"] = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    with open(OUT_PATH, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

    changed = {k: v for k, v in new_counts.items() if old_counts.get(k) != v}
    print(
        "[update_citations] updated: "
        + ", ".join(f"{k}={v}" for k, v in sorted(changed.items()))
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
