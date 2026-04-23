#!/usr/bin/env bash
# ralph-plan.sh — Wraps ai-ralph workspace-mode planning.
#
# Workspace mode (ai-ralph PR #3 and after) reads workbench context + repos/* and
# writes per-repo .ralph/fix_plan.md plus a workbench-level ralph/workspace-plan.md.
#
# Until PR #3 merges, this script falls back to per-repo planning: for each repo in
# project.conf, sync the appropriate role-filtered context and run `ralph-plan` from
# that repo's cwd.
#
# Usage:
#   ./scripts/ralph-plan.sh                    # all repos
#   ./scripts/ralph-plan.sh <repo>             # single repo
#   ./scripts/ralph-plan.sh --agent devin      # force agent
#   ./scripts/ralph-plan.sh --workspace        # force workspace mode (once supported)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$WB_ROOT/project.conf" ]] || { echo "project.conf not found" >&2; exit 1; }
source "$WB_ROOT/project.conf"

AGENT_NAME="claude"
[[ "${DEVIN_DEFAULT:-true}" == "true" ]] && AGENT_NAME="devin"

WORKSPACE_MODE=""
TARGET_REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)     AGENT_NAME="${2:-claude}"; shift 2 ;;
    --workspace) WORKSPACE_MODE="true"; shift ;;
    *)           TARGET_REPO="$1"; shift ;;
  esac
done

# --- Helpers (declare before use) -----------------------------------------------

_ralph_has_workspace_flag() {
  command -v ralph-plan >/dev/null 2>&1 || return 1
  ralph-plan --help 2>&1 | grep -qiE -- '(--workspace|workspace mode)' && return 0
  return 1
}

_per_repo_plan() {
  for entry in "${REPOS[@]}"; do
    local name role
    name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
    role="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^role=/) print substr($i,6)}')"

    [[ -n "$TARGET_REPO" && "$name" != "$TARGET_REPO" ]] && continue

    local repo_dir="$WB_ROOT/repos/$name"
    [[ -d "$repo_dir" ]] || { echo "  skip $name — not cloned"; continue; }

    echo "  planning $name ($role) with $AGENT_NAME..."
    (cd "$repo_dir" && ralph-plan --engine "$AGENT_NAME") || {
      echo "    plan failed for $name" >&2
    }
  done
}

# --- Step 1: sync context first -------------------------------------------------
echo "[1/2] Syncing context into per-repo ai/ dirs..."
"$SCRIPT_DIR/ralph-context.sh" ${TARGET_REPO:+$TARGET_REPO}

# --- Step 2: plan ---------------------------------------------------------------
if [[ "$WORKSPACE_MODE" == "true" ]] || _ralph_has_workspace_flag; then
  echo "[2/2] Running ralph-plan in workspace mode..."
  # TODO(phase-2): finalize exact flag/command once PR #3 merges. Assumed:
  #   ralph-plan --workspace --root "$WB_ROOT" --engine "$AGENT_NAME"
  cd "$WB_ROOT"
  if ! ralph-plan --workspace --engine "$AGENT_NAME"; then
    echo "workspace mode call failed — falling back to per-repo mode" >&2
    _per_repo_plan
  fi
else
  echo "[2/2] Workspace mode not detected — running per-repo plan (ai-ralph pre-PR#3 fallback)..."
  _per_repo_plan
fi

# --- Step 3: write workspace-plan.md rollup -------------------------------------
# TODO(phase-2): aggregate each repo's .ralph/fix_plan.md into ralph/workspace-plan.md
printf "# Workspace Plan Rollup\n\n_TODO(phase-2): aggregate per-repo fix_plans from repos/*/.ralph/fix_plan.md_\n" \
  > "$WB_ROOT/ralph/workspace-plan.md"

echo ""
echo "ralph-plan complete. Review: $WB_ROOT/ralph/workspace-plan.md"
