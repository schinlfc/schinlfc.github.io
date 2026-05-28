#!/usr/bin/env bash
# Verify every content page wires up the shared partials.
#
# Loading model (from inspection of this repo):
#   - Navbar: each page declares <div id="page-navbar"></div> and a script block
#     calls $("#page-navbar").load("page-navbar.html").
#   - Footer: each page declares <div id="page-footer"></div> and includes
#     <script src="js/main.js"></script>, which loads footer.html into that div.
#   - Acknowledge (opt-in): pages that want the land-acknowledgement block
#     declare <div id="acknowledge"></div> AND call $("#acknowledge").load(...).
#     Having one without the other is a silent bug.
#
# Enforces .claude/rules/shared-partial-consistency.md.

set -uo pipefail

cd "$(dirname "$0")/.."

# Full content pages (must include navbar + footer; acknowledge is opt-in)
PAGES=(index.html research.html research-advising.html teaching.html projects.html)

# Special pages: reported but not required to comply with the full-page rule.
# - acknowledge.html: HTML fragment used as a partial itself
# - 404.html: not-found page (currently a redirect)
SPECIAL_PAGES=(acknowledge.html 404.html)

fail=0

printf '%-22s  %-12s  %-12s  %-12s  %-18s\n' "page" "navbar-div" "navbar-load" "footer-wired" "acknowledge"
printf '%-22s  %-12s  %-12s  %-12s  %-18s\n' "----" "----------" "-----------" "------------" "-----------"

for page in "${PAGES[@]}"; do
  if [[ ! -f "$page" ]]; then
    printf '%-22s  %-12s  %-12s  %-12s  %-18s\n' "$page" "MISSING" "MISSING" "MISSING" "MISSING"
    fail=1
    continue
  fi

  navbar_div=$(grep -q 'id="page-navbar"' "$page" && echo ok || echo NO)
  navbar_load=$(grep -q '\.load("page-navbar.html"' "$page" && echo ok || echo NO)

  has_footer_div=$(grep -q 'id="page-footer"' "$page" && echo yes || echo no)
  has_main_js=$(grep -q 'js/main\.js' "$page" && echo yes || echo no)
  if [[ "$has_footer_div" == "yes" && "$has_main_js" == "yes" ]]; then
    footer_wired=ok
  else
    footer_wired="NO($has_footer_div/$has_main_js)"
  fi

  has_ack_div=$(grep -q 'id="acknowledge"' "$page" && echo yes || echo no)
  has_ack_load=$(grep -q '\.load("acknowledge.html"' "$page" && echo ok || echo no)
  if [[ "$has_ack_div" == "yes" && "$has_ack_load" == "ok" ]]; then
    ack_status="ok (opt-in)"
  elif [[ "$has_ack_div" == "no" && "$has_ack_load" == "no" ]]; then
    ack_status="not used"
  else
    ack_status="BUG($has_ack_div/$has_ack_load)"
    fail=1
  fi

  [[ $navbar_div == NO || $navbar_load == NO || $footer_wired != ok ]] && fail=1

  printf '%-22s  %-12s  %-12s  %-12s  %-18s\n' "$page" "$navbar_div" "$navbar_load" "$footer_wired" "$ack_status"
done

echo
echo "Special pages (informational only):"
for page in "${SPECIAL_PAGES[@]}"; do
  if [[ -f "$page" ]]; then
    size=$(wc -c < "$page" | tr -d ' ')
    echo "  $page (${size} bytes)"
  fi
done

echo
if [[ $fail -eq 0 ]]; then
  echo "All content pages wire up partials correctly."
  exit 0
else
  cat <<EOF
One or more content pages have partial-wiring issues.

navbar-div  : the page declares <div id="page-navbar"></div>
navbar-load : the page has \$("#page-navbar").load("page-navbar.html")
footer-wired: the page has BOTH <div id="page-footer"></div> AND <script src="js/main.js"></script>
acknowledge : opt-in. "BUG" means the page has one of (div, JS load) but not the other.

See .claude/rules/shared-partial-consistency.md.
EOF
  exit 1
fi
