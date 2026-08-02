#!/bin/bash
# Refresh Google Scholar citation counts from this machine, then commit and push.
#
# Why this exists
# ---------------
# The weekly GitHub Action (.github/workflows/update-citations.yml) cannot do
# this job. Google Scholar returns 403 to GitHub's datacenter IPs, so every
# scheduled run (2026-07-13, 07-20, 07-27) reported success while updating
# nothing -- the scraper's "leave the JSON untouched when blocked" guard turns a
# block into a silent no-op. Residential IPs are not blocked, so the refresh
# runs here instead, driven by a launchd agent:
#
#   ~/Library/LaunchAgents/com.schinlfc.citations-refresh.plist
#
# The Action is left in place: it is harmless, and it will start working on its
# own the day a SERPAPI_KEY repo secret is added.
#
# Safety contract
# ---------------
# This runs unattended, so it is deliberately timid. It only ever commits
# json/citations.json, and it bails out rather than resolving any repository
# state it did not create (wrong branch, in-progress merge, pending edits to
# the citations file, a diverged remote). A skipped run is always preferable to
# a surprising one; the next run picks it up.
#
# Manual run (same behavior as the scheduled one):
#   ./scripts/refresh-citations-local.sh
#
# Log: ~/Library/Logs/citations-refresh.log

set -uo pipefail

# launchd hands us a minimal PATH; be explicit about where the tools live.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

REPO="${CITATIONS_REPO:-/Users/schin/schinlfc.github.io}"
VENV="${CITATIONS_VENV:-$HOME/.local/share/citations-refresh/venv}"
LOG="${CITATIONS_LOG:-$HOME/Library/Logs/citations-refresh.log}"
TARGET="json/citations.json"
BRANCH="main"

mkdir -p "$(dirname "$LOG")"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }
skip() { log "SKIP: $*"; exit 0; }

log "--- refresh start ---"

cd "$REPO" 2>/dev/null || { log "ERROR: repo not found at $REPO"; exit 1; }

# --- Guards: refuse to act on a repo that is mid-something ------------------

current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ "$current_branch" = "$BRANCH" ] || skip "on branch '$current_branch', not '$BRANCH'"

git_dir="$(git rev-parse --git-dir)"
if [ -e "$git_dir/MERGE_HEAD" ] || [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
  skip "a merge or rebase is in progress"
fi

# Pending hand-edits to the citations file mean a human is mid-thought here.
if ! git diff --quiet -- "$TARGET" || ! git diff --cached --quiet -- "$TARGET"; then
  skip "$TARGET has uncommitted changes"
fi

# --- Sync with origin (fast-forward only; never rebase the user's work) -----

export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=20"

if ! git fetch --quiet origin "$BRANCH" 2>>"$LOG"; then
  log "WARN: git fetch failed (offline?); continuing with local state"
else
  behind="$(git rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo 0)"
  if [ "${behind:-0}" -gt 0 ]; then
    if git merge --ff-only --quiet "origin/$BRANCH" 2>>"$LOG"; then
      log "fast-forwarded $behind commit(s) to origin/$BRANCH"
    else
      skip "local $BRANCH has diverged from origin; resolve by hand"
    fi
  fi
fi

# --- Dependencies ----------------------------------------------------------

if [ ! -x "$VENV/bin/python3" ]; then
  log "creating venv at $VENV"
  python3 -m venv "$VENV" >>"$LOG" 2>&1 || { log "ERROR: venv creation failed"; exit 1; }
fi
if ! "$VENV/bin/python3" -c 'import requests, bs4' 2>/dev/null; then
  log "installing requests + beautifulsoup4"
  "$VENV/bin/pip" install --quiet requests beautifulsoup4 >>"$LOG" 2>&1 \
    || { log "ERROR: dependency install failed"; exit 1; }
fi

# --- Scrape ----------------------------------------------------------------
# update_citations.py is the single source of truth for parsing and for the
# decision to write; it exits 0 and leaves the file alone when blocked.

"$VENV/bin/python3" scripts/update_citations.py >>"$LOG" 2>&1 \
  || { log "ERROR: update_citations.py failed"; exit 1; }

if git diff --quiet -- "$TARGET"; then
  log "no citation changes"
  log "--- refresh end ---"
  exit 0
fi

# --- Commit and push (this path only) --------------------------------------

summary="$(git diff --unified=0 -- "$TARGET" | grep -E '^\+ +"' | tr -d ' "' | tr '\n' ' ')"
log "changed: $summary"

git commit --quiet -m "chore: refresh Google Scholar citation counts" -- "$TARGET" 2>>"$LOG" \
  || { log "ERROR: commit failed"; exit 1; }

if git push --quiet origin "$BRANCH" 2>>"$LOG"; then
  log "pushed to origin/$BRANCH"
else
  log "WARN: push failed; commit is local and will go out with the next push"
fi

log "--- refresh end ---"
