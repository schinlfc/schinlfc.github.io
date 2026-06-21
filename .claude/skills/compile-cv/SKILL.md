---
name: compile-cv
description: Compile the LaTeX CV in cv/src/ and update cv/cv.pdf. Defaults to XeLaTeX via latexmk; falls back to manual multi-pass xelatex if latexmk is unavailable. Detects bib files automatically. Use when user says "compile cv", "rebuild cv", "update cv pdf", or after editing cv/src/*.tex.
argument-hint: "[tex-filename, default 'cv.tex'] [--engine xelatex|pdflatex|lualatex]"
allowed-tools: ["Read", "Glob", "Bash", "Write"]
---

# Compile CV

Build the LaTeX CV in `cv/src/` and copy the resulting PDF to `cv/cv.pdf` (which `vitae.html` and other download links reference).

## Steps

1. **Resolve the source file:**
   - Default: `cv/src/cv.tex`
   - If `$ARGUMENTS` names a `.tex` file, use that instead. Confirm the file exists in `cv/src/`.
   - If multiple `.tex` files exist and no argument is given, list them and ask the user to pick.

2. **Resolve the engine** (precedence: argument > magic comment > default):
   - If `$ARGUMENTS` contains the `--engine` flag (`--engine <name>`), use that.
   - Otherwise grep the source for `% !TEX TS-program = ...` and use that.
   - Otherwise default to `xelatex`.

3. **Prefer `latexmk` (handles bib + passes automatically):**
   ```bash
   if command -v latexmk >/dev/null 2>&1; then
     cd cv/src && latexmk -<engine> -outdir=build -interaction=nonstopmode -halt-on-error cv.tex
   fi
   ```
   Map: `xelatex` → `-xelatex`; `pdflatex` → `-pdf`; `lualatex` → `-lualatex`.

4. **Fallback to manual multi-pass** if `latexmk` is unavailable:
   ```bash
   cd cv/src
   <engine> -output-directory=build -interaction=nonstopmode -halt-on-error cv.tex
   # If a .bib file exists in cv/src/, run biber or bibtex
   if ls *.bib >/dev/null 2>&1; then
     if grep -q '\\bibliography{' cv.tex && ! grep -q '\\addbibresource' cv.tex; then
       (cd build && bibtex cv)
     else
       (cd build && biber cv)
     fi
   fi
   <engine> -output-directory=build -interaction=nonstopmode -halt-on-error cv.tex
   <engine> -output-directory=build -interaction=nonstopmode -halt-on-error cv.tex
   ```

5. **On compile error:**
   - Read `cv/src/build/cv.log`. Find the first `! ` line (LaTeX error marker).
   - Report file + line + error to the user. Do NOT update `cv/cv.pdf`.
   - Suggest the likely fix if the error is well-known (missing package, undefined control sequence, runaway argument).

6. **On success:**
   - Copy `cv/src/build/cv.pdf` to `cv/cv.pdf`.
   - Report:
     - Page count (`pdfinfo cv/cv.pdf | grep Pages` if available, else skip)
     - File size before/after (so the user notices unexpected size changes)
     - Any `\overfull`/`\underfull` hbox warnings from the log (counts, not full list)
   - Suggest running `/check-links` if external links were added/changed.

7. **Sync the home-page "Last update" date — but only when the CV actually
   changed.** The CV stamps its own compile date (`Last Update: <Month DD,
   YYYY>` via `\DTMdisplaydate`), and `index.html` mirrors it in a static
   `<span id="cv-updated">` next to the CV download link. Because the stamp
   is the *compile* date, a no-op recompile on a new day bumps it even when
   nothing in the CV changed — and the home page should reflect real CV
   updates, not recompiles. So gate the sync on whether the source was
   edited this round:

   ```bash
   # "CV updated" = cv/src has uncommitted changes vs HEAD (a real edit
   # this round, not a bare recompile). git diff --quiet exits 0 when clean.
   if git diff --quiet HEAD -- cv/src 2>/dev/null; then
     echo "cv/src unchanged vs HEAD — recompile only; leaving index.html date as-is."
   else
     # Extract the stamp the freshly built PDF actually renders.
     STAMP=$(pdftotext cv/cv.pdf - 2>/dev/null \
       | grep -oE 'Last Update: [A-Z][a-z]+ [0-9]{1,2}, [0-9]{4}' \
       | head -1 | sed 's/^Last Update: //')
     # Rewrite the home-page span to match (only if it differs).
     if [ -n "$STAMP" ]; then
       perl -0pi -e "s{(<span id=\"cv-updated\">)[^<]*(</span>)}{\${1}$STAMP\${2}}" index.html
     fi
   fi
   ```

   Report whether `index.html` was updated and to what date (or that it was
   left untouched because the CV source was unchanged). If the `grep` yields
   nothing (the CV template changed its stamp wording), fall back to reading
   `cv/src/build/cv.pdf` manually and editing the span by hand — but only
   under the same "CV actually changed" condition. Do NOT bump the home-page
   date for a recompile that didn't touch the CV.

8. **Cleanup:** leave `cv/src/build/` in place (it's gitignored). Faster subsequent compiles.

## Notes

- Requires a TeX distribution. Run `scripts/validate-setup.sh` to confirm `xelatex` (or your chosen engine) is on PATH.
- The CV PDF is referenced from `vitae.html` and possibly elsewhere — after updating it, `/check-links` and a local preview are good follow-ups (publication-ready visuals rule).
- Cross-references: `.claude/rules/publications-cv-sync.md` (if updating the CV alters listed publications, also reconcile `research.html` and `vitae.html`).
