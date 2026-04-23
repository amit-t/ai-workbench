#!/usr/bin/env bash
# sync-context.sh — Push APPROVED workbench artifacts into each repos/*/ai/.
#
# Source of truth: .workbench-state/approved.json.
#
# Role-aware targeting:
#   role=service           → PRDs + specs + TDDs + ERDs + ADRs
#   role=automation-tests  → PRDs + BDDs + test-cases + test-specs + test-erds
#   role=shared-lib        → specs + TDDs + ADRs
#   role=infra             → ADRs only
#
# Artifact type → destination subdir mapping:
#   prd          → ai/outputs/prds/
#   eng-spec     → ai/outputs/specs/
#   tdd          → ai/outputs/tdd/
#   erd          → ai/outputs/erd/
#   adr          → ai/outputs/adrs/
#   bdd          → ai/outputs/bdd/
#   test-cases   → ai/outputs/test-cases/
#   test-spec    → ai/outputs/test-spec/
#   test-erd     → ai/outputs/test-erd/
#
# Usage:
#   ./scripts/sync-context.sh            # all repos
#   ./scripts/sync-context.sh --dry-run  # preview only
#   ./scripts/sync-context.sh <repo>     # single repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$WB_ROOT/project.conf" ]] || { echo "project.conf not found at $WB_ROOT" >&2; exit 1; }
source "$WB_ROOT/project.conf"

DRY_RUN=false
TARGET_REPO=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *)         TARGET_REPO="$arg" ;;
  esac
done

APPROVED="$WB_ROOT/.workbench-state/approved.json"
[[ -f "$APPROVED" ]] || { echo "Error: $APPROVED does not exist. Init the workbench state first." >&2; exit 1; }

export ROLE_MATRIX='{
  "service":           ["prd","eng-spec","tdd","erd","adr"],
  "automation-tests":  ["prd","bdd","test-cases","test-spec","test-erd"],
  "shared-lib":        ["eng-spec","tdd","adr"],
  "infra":             ["adr"]
}'

export TYPE_TO_SUBDIR='{
  "prd":"prds",
  "eng-spec":"specs",
  "tdd":"tdd",
  "erd":"erd",
  "adr":"adrs",
  "bdd":"bdd",
  "test-cases":"test-cases",
  "test-spec":"test-spec",
  "test-erd":"test-erd"
}'

sync_one() {
  local entry="$1"
  local name role
  name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
  role="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^role=/) print substr($i,6)}')"

  [[ -z "$name" || -z "$role" ]] && { echo "  skip: malformed REPOS entry '$entry'" >&2; return 0; }
  case "$role" in
    service|automation-tests|shared-lib|infra) ;;
    *) echo "  skip: unknown role '$role' for repo '$name' (expected: service|automation-tests|shared-lib|infra)" >&2; return 0 ;;
  esac

  [[ -n "$TARGET_REPO" && "$name" != "$TARGET_REPO" ]] && return 0

  local repo_dir="$WB_ROOT/repos/$name"
  if [[ ! -d "$repo_dir" ]]; then
    echo "  skip $name — not cloned at $repo_dir"
    return 0
  fi

  echo "── $name ($role) ──"

  WB_ROOT="$WB_ROOT" REPO_DIR="$repo_dir" ROLE="$role" DRY_RUN="$DRY_RUN" \
  python3 - <<'PYEOF'
import json, os, shutil, pathlib
root = pathlib.Path(os.environ['WB_ROOT'])
repo = pathlib.Path(os.environ['REPO_DIR'])
role = os.environ['ROLE']
dry  = os.environ.get('DRY_RUN', 'false') == 'true'

approved = json.loads((root / '.workbench-state' / 'approved.json').read_text()).get('items', [])
role_types = json.loads(os.environ['ROLE_MATRIX']).get(role, [])
type_dir   = json.loads(os.environ['TYPE_TO_SUBDIR'])

ai_base = repo / 'ai' / 'outputs'
if not dry:
    ai_base.mkdir(parents=True, exist_ok=True)

copied = 0
for item in approved:
    t = item.get('type')
    if t not in role_types:
        continue
    subdir = type_dir.get(t, t)
    src = (root / item['path']).resolve()
    root_resolved = root.resolve()
    try:
        src.relative_to(root_resolved)
    except ValueError:
        print(f"  error: {item['id']} path escapes workbench root: {item['path']}")
        continue
    if not src.is_file():
        print(f"  warn: missing source file {src}")
        continue
    dst_dir = ai_base / subdir
    dst = dst_dir / src.name
    if dry:
        print(f"  [dry-run] {item['id']}  {src.relative_to(root_resolved)}  ->  {dst.relative_to(root)}")
    else:
        dst_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print(f"  {item['id']}  ->  ai/outputs/{subdir}/{src.name}")
    copied += 1

if copied == 0:
    print("  (no approved artifacts for this role)")
PYEOF
}

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "No repos registered in project.conf." >&2
  exit 1
fi

for entry in "${REPOS[@]}"; do
  sync_one "$entry"
done

echo ""
echo "sync-context complete."
