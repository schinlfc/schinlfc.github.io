# MEMORY.md — schinlfc.github.io

Repo-local memory for this site. Holds `[LEARN]` tags, decisions, and conventions specific to **this codebase**.

For cross-project preferences (collaboration style, visual standards, the user's role, etc.), see the auto-memory at `~/.claude/projects/-Users-schin-schinlfc-github-io/memory/`. That layer loads automatically every session and is intentionally not duplicated here.

---

## Conventions

<!-- Add site-specific conventions as they emerge. Examples to seed:

- **Root-relative paths:** all asset references use `/css/...`, `/img/...`, never `./css/...`. Reason: shared partials (`page-navbar.html`, `footer.html`) are included from pages at different depths and only root-relative paths resolve identically.
- **Publication ordering:** newest first in `research.html` and `vitae.html`. Working papers above published papers within each year.
- **Image naming:** descriptive lowercase-with-dashes; no spaces, no MixedCase. Reason: avoids URL-encoding surprises in production.
-->

## Decisions

<!-- Record durable architectural / content decisions here. Each entry:
     - Date (YYYY-MM-DD)
     - What was decided
     - Why
     - What it implies for future edits

Example:

### 2026-05-27 — Skip quality_score.py
Decided not to install the upstream Quarto-targeted scorer. Reason: it doesn't grade `.html`, would produce misleading 0 scores in `/commit`. Implication: `/commit` will rely on qualitative gates (lint, link-check, partial consistency) until an HTML scorer is built. See CLAUDE.md "Quality Thresholds".
-->

### 2026-10-28 — Accepted papers move to the publications list (revised 2026-10-31)
When a working paper is accepted, move it from the Working Papers list into the matching peer-reviewed section of `research.html` as a full `pub-card`: APA citation with `(forthcoming)` and the journal in italics, and the SSRN "Working Paper" link kept. Use the site-themed SVG placeholder at `img/papers/placeholders/<key>.svg` as the thumbnail (point `src` at it directly, no `onerror`) until the published PDF exists and a first-page PNG can be generated; do **not** use the journal's cover image, and do **not** add an "Accepted at <journal>" `pub-status` pill (user removed both on 2026-10-31 for The Longer Reach of Lead; the citation line already carries the venue). Rename the `data-cite-key` from `wp-…` to `chin-YEAR-…` and update the same key in `json/citations.json` and `TITLE_MAP` in `scripts/update_citations.py`, or the weekly citation job drops the count. Mirror in `cv/src/cv.tex` and recompile. First applied to The Longer Reach of Lead (Economics and Human Biology).

### 2026-10-31 — All paper cards use the site-themed SVG covers
Every `pub-card` thumbnail on `research.html` points directly at `img/papers/placeholders/<key>.svg` (maroon, site-themed cover with title, coauthors, venue, and `vol(issue), pages · year` footer). The first-page PNG thumbnails and the journal-cover image were removed at the user's request; `scripts/generate-paper-thumbs.sh` is retained but unused. When a paper's volume/pages are finalized, update the SVG footer so all covers stay in the same format.

## [LEARN] tags

<!-- Inline corrections graduated from working sessions. Format:

### [LEARN:category] yyyy-mm-dd — short headline
**Wrong:** what was tried
**Right:** what works
**Why:** the reason, so future-me can judge edge cases

Categories: html, css, js, content, deploy, partials, publications, images, accessibility, build, audit
-->
