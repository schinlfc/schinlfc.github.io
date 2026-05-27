#!/usr/bin/env bash
# Generate publication thumbnail PNGs from paper PDFs.
#
# For each papers/*.pdf:
# - if it has an entry in PAGE_OVERRIDES below, render that page via pdftoppm
# - otherwise render page 1 via qlmanage (macOS built-in)
#
# Output: img/papers/<basename>.png
# SVG placeholders live at img/papers/placeholders/<basename>.svg as long-term fallbacks
# referenced by research.html when a PNG is missing.

set -euo pipefail

cd "$(dirname "$0")/.."

# Width target. qlmanage renders to this width directly; pdftoppm uses -scale-to-x.
THUMB_WIDTH=400

# Per-paper page overrides. Add lines as needed: "<basename>:<page>".
# basename is the .pdf filename without extension. Page is 1-indexed.
PAGE_OVERRIDES=(
  "chin-2026-kratom-reddit:2"   # page 1 of this PDF is a cover sheet; page 2 has the abstract
)

# Lookup helper: echoes the page number for a given basename, or nothing if no override.
get_page_override() {
  local base="$1"
  for entry in "${PAGE_OVERRIDES[@]}"; do
    if [[ "${entry%%:*}" == "$base" ]]; then
      echo "${entry#*:}"
      return
    fi
  done
}

if ! command -v qlmanage >/dev/null 2>&1; then
  echo "qlmanage not found — this script requires macOS." >&2
  exit 1
fi

PDFTOPPM="$(command -v pdftoppm || true)"
if [[ -z "$PDFTOPPM" && -x /opt/homebrew/bin/pdftoppm ]]; then
  PDFTOPPM=/opt/homebrew/bin/pdftoppm
fi

mkdir -p img/papers

shopt -s nullglob
pdfs=(papers/*.pdf)

if [[ ${#pdfs[@]} -eq 0 ]]; then
  echo "No PDFs found in papers/. Drop your peer-reviewed paper PDFs there using the"
  echo "naming convention chin-YEAR-slug.pdf, then re-run this script."
  exit 0
fi

count=0
for pdf in "${pdfs[@]}"; do
  base="$(basename "$pdf" .pdf)"
  out_png="img/papers/${base}.png"
  page="$(get_page_override "$base" || true)"

  if [[ -f "$out_png" && "$out_png" -nt "$pdf" ]]; then
    echo "skip (up-to-date): $out_png"
    continue
  fi

  if [[ -n "$page" && "$page" != "1" ]]; then
    if [[ -z "$PDFTOPPM" ]]; then
      echo "  WARN: $base needs page $page but pdftoppm is not installed (brew install poppler). Skipping." >&2
      continue
    fi
    echo "generating (page $page): $out_png"
    tmp="$(mktemp -t pdfthumb.XXXXXX)"
    "$PDFTOPPM" -png -f "$page" -l "$page" -singlefile -scale-to-x "$THUMB_WIDTH" -scale-to-y -1 "$pdf" "$tmp" >/dev/null 2>&1
    if [[ -f "${tmp}.png" ]]; then
      mv "${tmp}.png" "$out_png"
      count=$((count + 1))
    else
      echo "  WARN: pdftoppm did not produce output for $pdf" >&2
    fi
    rm -f "$tmp"
  else
    echo "generating (page 1): $out_png"
    tmpdir="$(mktemp -d)"
    qlmanage -t -s "$THUMB_WIDTH" -o "$tmpdir" "$pdf" >/dev/null 2>&1
    if [[ -f "$tmpdir/${base}.pdf.png" ]]; then
      mv "$tmpdir/${base}.pdf.png" "$out_png"
      count=$((count + 1))
    else
      echo "  WARN: qlmanage did not produce a thumbnail for $pdf" >&2
    fi
    rm -rf "$tmpdir"
  fi
done

echo
echo "Generated $count thumbnail(s) in img/papers/."
echo "If you removed a PDF, also delete the matching .png to fall back to the SVG placeholder."
