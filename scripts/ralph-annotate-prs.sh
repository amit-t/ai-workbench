#!/usr/bin/env bash
# ralph-annotate-prs.sh — Post-hoc M4 drift footer on ralph-authored PRs.
#
# Transitional fallback: until the ai-ralph `.ralph/pr_footer.md` append lands
# in pr_manager.sh, workbench adds the steering-drift footer to open ralph PRs
# by editing their bodies. Once the ralph-side change is merged and deployed,
# this script becomes a no-op (footer already appears natively) and the alias
# can be retired.
#
# Behavior:
#   - Generates the footer with `scripts/steering-overlays.py --footer`.
#   - Iterates project.conf REPOS; for each registered code repo:
#       - lists open PRs with head branch pattern `rp-*`
#       - if PR body does not already contain the footer marker, appends it
#
# Usage:
#   ./scripts/ralph-annotate-prs.sh                 # all registered repos
#   ./scripts/ralph-annotate-prs.sh --since 30m     # only PRs created in last N minutes
#   ./scripts/ralph-annotate-prs.sh --dry-run
#
# Requires: gh CLI authenticated for each registered repo's org.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$WB_ROOT/project.conf" ]] || { echo "project.conf not found at $WB_ROOT" >&2; exit 1; }
# shellcheck disable=SC1091
source "$WB_ROOT/project.conf"

SINCE=""
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)   SINCE="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) sed -n '2,22p' "$0"; exit 0 ;;
    *)         echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

command -v gh >/dev/null 2>&1 || { echo "gh CLI not installed." >&2; exit 1; }

FOOTER="$(WB_ROOT="$WB_ROOT" python3 "$SCRIPT_DIR/steering-overlays.py" --footer)"
if [[ -z "$FOOTER" ]]; then
  echo "No steering overrides — nothing to append."
  exit 0
fi

MARKER="### Steering drift for this workspace"

_since_iso() {
  # Convert 30m / 2h / 1d into an ISO8601 timestamp for gh search.
  local spec="$1"
  python3 - "$spec" <<'PYEOF'
import datetime, re, sys
spec = sys.argv[1]
m = re.fullmatch(r'(\d+)([mhd])', spec)
if not m:
    print('', end='')
    sys.exit(0)
n, unit = int(m.group(1)), m.group(2)
delta = {'m': datetime.timedelta(minutes=n),
         'h': datetime.timedelta(hours=n),
         'd': datetime.timedelta(days=n)}[unit]
t = datetime.datetime.now(datetime.UTC) - delta
print(t.strftime('%Y-%m-%dT%H:%M:%SZ'), end='')
PYEOF
}

SEARCH_SUFFIX=""
if [[ -n "$SINCE" ]]; then
  iso="$(_since_iso "$SINCE")"
  [[ -n "$iso" ]] && SEARCH_SUFFIX=" created:>=$iso"
fi

for entry in "${REPOS[@]}"; do
  name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
  url="$(echo "$entry"  | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^url=/)  print substr($i,5)}')"
  repo_slug="$(echo "$url" | sed -E 's#^https?://[^/]+/##; s#\.git$##')"
  [[ -z "$repo_slug" ]] && { echo "  skip $name: cannot infer repo slug"; continue; }

  echo "── $name ($repo_slug) ──"
  search="head:rp-${SEARCH_SUFFIX}"
  prs="$(gh pr list -R "$repo_slug" --state open --search "$search" \
         --json number,body 2>/dev/null || true)"
  [[ -z "$prs" || "$prs" == "[]" ]] && { echo "  no matching PRs"; continue; }

  echo "$prs" | python3 - "$repo_slug" "$MARKER" "$FOOTER" "$DRY_RUN" <<'PYEOF'
import json, subprocess, sys, tempfile, pathlib, os
data = json.load(sys.stdin)
repo_slug, marker, footer, dry = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == 'true'
for pr in data:
    num = pr['number']
    body = pr.get('body') or ''
    if marker in body:
        print(f"  PR #{num}: footer already present, skipping")
        continue
    new_body = body.rstrip() + '\n\n' + footer
    if dry:
        print(f"  [dry-run] PR #{num}: would append footer")
        continue
    with tempfile.NamedTemporaryFile('w', suffix='.md', delete=False) as f:
        f.write(new_body)
        tmp = f.name
    try:
        subprocess.run(
            ['gh', 'pr', 'edit', str(num), '-R', repo_slug, '--body-file', tmp],
            check=True,
        )
        print(f"  PR #{num}: footer appended")
    finally:
        os.unlink(tmp)
PYEOF
done
