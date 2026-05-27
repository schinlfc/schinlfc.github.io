#!/usr/bin/env bash
# Generate publication thumbnail PNGs from paper PDFs.
#
# For each papers/*.pdf, render the configured page via pdftoppm (poppler) at a
# fixed width. This keeps thumbnails at a consistent display width regardless of
# the source PDF's page size — important because journals use different page
# dimensions (e.g., Demography uses ~441x666 pts, not US letter).
#
# Output: img/papers/<basename>.png (width = $THUMB_WIDTH, height auto from page aspect)
# SVG placeholders at img/papers/placeholders/<basename>.svg are the long-term
# fallback referenced by research.html when a PNG is missing.

set -euo pipefail

cd "$(dirname "$0")/.."

# Fixed render width. Display in CSS is constrained further; this controls quality.
THUMB_WIDTH=400

# Per-paper page overrides. Add lines as needed: "<basename>:<page>".
# basename is the .pdf filename without extension. Page is 1-indexed.
PAGE_OVERRIDES=(
  "chin-2026-kratom-reddit:2"   # page 1 of this PDF is a Tandfonline cover sheet; page 2 has the abstract
)

# Lookup helper: echoes the page number for a given basename, default 1.
get_page() {
  local base="$1"
  for entry in "${PAGE_OVERRIDES[@]}"; do
    if [[ "${entry%%:*}" == "$base" ]]; then
      echo "${entry#*:}"
      return
    fi
  done
  echo 1
}

PDFTOPPM="$(command -v pdftoppm || true)"
if [[ -z "$PDFTOPPM" && -x /opt/homebrew/bin/pdftoppm ]]; then
  PDFTOPPM=/opt/homebrew/bin/pdftoppm
fi
if [[ -z "$PDFTOPPM" ]]; then
  echo "pdftoppm not found. Install with: brew install poppler" >&2
  exit 1
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
  page="$(get_page "$base")"

  if [[ -f "$out_png" && "$out_png" -nt "$pdf" ]]; then
    echo "skip (up-to-date): $out_png"
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
done

echo
echo "Generated $count thumbnail(s) in img/papers/."
echo "If you removed a PDF, also delete the matching .png to fall back to the SVG placeholder."
