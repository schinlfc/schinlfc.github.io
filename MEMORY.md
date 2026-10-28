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

### 2026-10-28 — Accepted papers move to the publications list
When a working paper is accepted, move it from the Working Papers list into the matching peer-reviewed section of `research.html` as a full `pub-card`: APA citation with `(forthcoming)` and the journal in italics, the SSRN "Working Paper" link kept, a `pub-status` pill reading "Accepted at <journal>", and the journal's cover (Elsevier: `https://ars.els-cdn.com/content/image/X<ISSN>.jpg`) as the thumbnail until the published PDF exists. Rename the `data-cite-key` from `wp-…` to `chin-YEAR-…` and update the same key in `json/citations.json` and `TITLE_MAP` in `scripts/update_citations.py`, or the weekly citation job drops the count. Mirror in `cv/src/cv.tex` and recompile. First applied to The Longer Reach of Lead (Economics and Human Biology).

## [LEARN] tags

<!-- Inline corrections graduated from working sessions. Format:

### [LEARN:category] yyyy-mm-dd — short headline
**Wrong:** what was tried
**Right:** what works
**Why:** the reason, so future-me can judge edge cases

Categories: html, css, js, content, deploy, partials, publications, images, accessibility, build, audit
-->
