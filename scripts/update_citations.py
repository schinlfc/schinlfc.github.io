#!/usr/bin/env python3
"""Refresh Google Scholar citation counts into json/citations.json.

Scrapes the public Google Scholar profile and maps each article title to the
stable slug used as a data-cite-key on research.html.

Safe by design: if the fetch is blocked (Google returns a consent/robot page
with no article rows), or nothing changed, the script leaves
json/citations.json untouched and exits 0 -- so the weekly GitHub Action
stays green and NEVER overwrites good numbers with a captcha page.

Usage:
    python3 scripts/update_citations.py
"""
import json
import os
import re
import sys
from datetime import datetime, timezone

import requests
from bs4 import BeautifulSoup

PROFILE_URL = (
    "https://scholar.google.com/citations"
    "?user=Yx02X_IAAAAJ&hl=en&cstart=0&pagesize=100"
)
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


def scrape():
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
        count = int(cited) if cited.isdigit() else 0
        slug = match_slug(title)
        if slug:
            found[slug] = count
    return rows, found


def main() -> int:
    try:
        with open(OUT_PATH) as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        data = {}
    data.setdefault("source", "Google Scholar")
    data.setdefault(
        "profile",
        "https://scholar.google.com/citations?user=Yx02X_IAAAAJ&hl=en",
    )

    try:
        rows, found = scrape()
    except Exception as e:  # network error, non-200, parse failure
        print(f"[update_citations] fetch failed: {e}. Leaving JSON unchanged.")
        return 0

    # A real profile page has many rows; a consent/robot wall has none.
    if len(rows) < 3 or not found:
        print(
            f"[update_citations] profile returned too few rows ({len(rows)}) "
            "-- likely blocked. Leaving JSON unchanged."
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
