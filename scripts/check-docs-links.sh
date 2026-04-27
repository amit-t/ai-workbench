#!/usr/bin/env bash
# check-docs-links.sh — regression guard for hardcoded owner URLs in Jekyll docs.
#
# Pages render from a single source for both forks (amit-t and Invenco-Cloud-Systems-ICS).
# Owner-aware URLs come from docs/_data/orgs.yml via docs/_includes/links.html, resolved
# at build time using site.github.owner_name (set by jekyll-github-metadata from
# PAGES_REPO_NWO at deploy time).
#
# This script fails (exit 1) if any hardcoded amit-t/* or Invenco-Cloud-Systems-ICS/*
# URL leaks back into a docs page or layout/include — which would break the inv fork's
# Pages output, since those URLs would point at the wrong owner.
#
# Allowlisted: the resolver itself (orgs.yml, links.html, _config.yml).
# Trigger: pre-commit, CI, or manual `bash scripts/check-docs-links.sh`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -d docs ]]; then
  echo "check-docs-links: docs/ not found at $REPO_ROOT" >&2
  exit 2
fi

# Files that legitimately contain hardcoded owner URLs (the resolver inputs).
ALLOWLIST=(
  "docs/_data/orgs.yml"
  "docs/_includes/links.html"
  "docs/_config.yml"
)

# Pattern: https://github.com/<owner>/...  OR  https://<owner>.github.io/...
PATTERN='https?://(github\.com/(amit-t|Invenco-Cloud-Systems-ICS)/|(amit-t|Invenco-Cloud-Systems-ICS)\.github\.io/)'

is_allowlisted() {
  local f="$1"
  for a in "${ALLOWLIST[@]}"; do
    [[ "$f" == "$a" ]] && return 0
  done
  return 1
}

violations=0
matches_buf=""

# Scan every .md and .html under docs/. Recursive on purpose — pages live in subdirs
# (skills/, steering/) too, and the spec's intent is "no hardcoded owner URLs anywhere
# in rendered docs source".
while IFS= read -r -d '' file; do
  rel="${file#./}"
  if is_allowlisted "$rel"; then
    continue
  fi
  # grep -E so the pattern's alternation works without backslash gymnastics.
  if hits=$(grep -nE "$PATTERN" "$file" 2>/dev/null); then
    while IFS= read -r line; do
      matches_buf+="${rel}:${line}"$'\n'
      violations=$((violations + 1))
    done <<< "$hits"
  fi
done < <(find docs \
  \( -path 'docs/_site*' -o -path 'docs/.jekyll-cache' -o -path 'docs/.bundle' -o -path 'docs/vendor' \) -prune -o \
  -type f \( -name '*.md' -o -name '*.html' \) -print0)

if (( violations > 0 )); then
  echo "check-docs-links: FAIL — $violations hardcoded owner URL(s) found:" >&2
  echo "" >&2
  printf '%s' "$matches_buf" >&2
  echo "" >&2
  echo "Remediation:" >&2
  echo "  Replace the URL with an owner-aware Liquid lookup, e.g.:" >&2
  echo "    https://github.com/amit-t/ai-workbench  →  {{ links.ai_workbench_repo }}" >&2
  echo "    https://amit-t.github.io/ai-workbench/  →  {{ links.ai_workbench_pages }}" >&2
  echo "    https://github.com/amit-t/ai-devkit     →  {{ links.ai_devkit_repo }}" >&2
  echo "  Then add '{% include links.html %}' after the page front-matter." >&2
  echo "  Owner key map: docs/_data/orgs.yml. Resolver: docs/_includes/links.html." >&2
  exit 1
fi

echo "check-docs-links: OK — no hardcoded owner URLs in docs/."
