#!/usr/bin/env bash
# Generate first-page thumbnail PNGs from paper PDFs.
#
# Reads each .pdf in papers/, runs qlmanage (macOS built-in) to produce a
# thumbnail, and saves it to img/papers/<basename>.png.
#
# Filename convention (paired): papers/chin-YEAR-slug.pdf -> img/papers/chin-YEAR-slug.png
# SVG placeholders live at img/papers/placeholders/chin-YEAR-slug.svg and are
# used as a fallback when the PNG is missing (research.html handles the swap).
#
# Requirements:
# - macOS (uses qlmanage)
# - sips (built-in, used to resize)

set -euo pipefail

cd "$(dirname "$0")/.."

# Target width for thumbnails (matches the .pub-thumb width in css/main.css).
# Generated at 2x for retina, then displayed at 200px.
THUMB_WIDTH=400

if ! command -v qlmanage >/dev/null 2>&1; then
  echo "qlmanage not found — this script requires macOS." >&2
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

  if [[ -f "$out_png" && "$out_png" -nt "$pdf" ]]; then
    echo "skip (up-to-date): $out_png"
    continue
  fi

  echo "generating: $out_png"
  tmpdir="$(mktemp -d)"
  qlmanage -t -s "$THUMB_WIDTH" -o "$tmpdir" "$pdf" >/dev/null 2>&1

  # qlmanage names the output <input>.png
  if [[ -f "$tmpdir/${base}.pdf.png" ]]; then
    mv "$tmpdir/${base}.pdf.png" "$out_png"
    count=$((count + 1))
  else
    echo "  WARN: qlmanage did not produce a thumbnail for $pdf" >&2
  fi
  rm -rf "$tmpdir"
done

echo
echo "Generated $count thumbnail(s) in img/papers/."
echo "If you removed a PDF, also delete the matching .png to fall back to the SVG placeholder."
