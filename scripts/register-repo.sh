#!/usr/bin/env bash
# register-repo.sh — Append a code repo to project.conf and clone it into repos/.
#
# Usage:
#   ./scripts/register-repo.sh <name> <git_url> <role> [<stack>]
#
# Roles: service | automation-tests | shared-lib | infra

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF="$WB_ROOT/project.conf"

NAME="${1:?Usage: register-repo.sh <name> <git_url> <role> [<stack>]}"
URL="${2:?}"
ROLE="${3:?}"
STACK="${4:-unspecified}"

case "$ROLE" in
  service|automation-tests|shared-lib|infra) ;;
  *) echo "Invalid role: $ROLE (expected: service | automation-tests | shared-lib | infra)" >&2; exit 1 ;;
esac

[[ -f "$CONF" ]] || { echo "project.conf not found at $CONF" >&2; exit 1; }

# Check for duplicate
if grep -qE "name=$NAME;" "$CONF"; then
  echo "Already registered: $NAME"
  exit 0
fi

GH_USER="$(gh api user -q .login 2>/dev/null || echo unknown)"
ENTRY="  \"name=$NAME;url=$URL;role=$ROLE;stack=$STACK;added_by=$GH_USER;graphified=false\""

# Insert before closing ) of REPOS=(
python3 - "$CONF" "$ENTRY" <<'PYEOF'
import sys, re
conf_path, new_line = sys.argv[1], sys.argv[2]
with open(conf_path) as f: content = f.read()
# Match REPOS=( ... )
m = re.search(r'REPOS=\((.*?)\)', content, re.DOTALL)
if not m:
    sys.stderr.write("Could not find REPOS=( ... ) block in project.conf\n"); sys.exit(1)
inner = m.group(1)
new_inner = inner.rstrip() + ("\n" if inner.strip() else "") + new_line + "\n"
content = content[:m.start(1)] + new_inner + content[m.end(1):]
with open(conf_path, 'w') as f: f.write(content)
print("Appended to project.conf")
PYEOF

# Clone
REPO_DIR="$WB_ROOT/repos/$NAME"
if [[ -d "$REPO_DIR/.git" ]]; then
  echo "Already cloned: $REPO_DIR"
else
  echo "Cloning $URL → $REPO_DIR"
  git clone "$URL" "$REPO_DIR"
fi

echo "Done. $NAME registered as $ROLE."
echo
echo "→ Build wb context for this repo:  wb.rescan ${NAME}"

# ── Graphify integration ────────────────────────────────────────────────────
# Resolve GRAPHIFY_MODE: env > project.conf > default "auto".
_GRAPHIFY_MODE=""
if [[ -n "${WB_GRAPHIFY_MODE:-}" ]]; then
  _GRAPHIFY_MODE="$WB_GRAPHIFY_MODE"
else
  _GRAPHIFY_MODE="$(grep -E '^GRAPHIFY_MODE=' "$CONF" 2>/dev/null \
                    | sed -E 's/^GRAPHIFY_MODE="?([^"]*)"?$/\1/' | head -1)"
fi
[[ -z "$_GRAPHIFY_MODE" ]] && _GRAPHIFY_MODE="auto"

case "$_GRAPHIFY_MODE" in
  auto)
    echo
    echo "→ GRAPHIFY_MODE=auto: invoking wb.graphify $NAME"
    WB_ROOT="$WB_ROOT" "$SCRIPT_DIR/graphify-repos.sh" "$NAME" || {
      echo "register-repo: wb.graphify $NAME failed (continuing — REPOS entry kept; rerun later)." >&2
    }
    ;;
  manual)
    echo
    echo "→ GRAPHIFY_MODE=manual: run when ready:  wb.graphify ${NAME}"
    ;;
  *)
    echo
    echo "→ GRAPHIFY_MODE=$_GRAPHIFY_MODE (unknown — skipping auto-graphify). Run:  wb.graphify ${NAME}"
    ;;
esac
