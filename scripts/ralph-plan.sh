#!/usr/bin/env bash
# ralph-plan.sh — Thin workbench wrapper that drives ai-ralph planning.
#
# Workbench wraps; ralph owns the core. This script only:
#   1. Preflights that ralph workspace mode is enabled.
#   2. Syncs approved workbench context into repos/<name>/ai/.
#   3. Resolves the plan mode and calls ralph-plan with the right flags.
#   4. Echoes ralph's own summary output verbatim.
#
# Plan mode is one of:
#   workspace — single `ralph-plan --workspace` call at repos/.
#               Requires ralph-plan with --workspace support
#               (landed via ai-ralph feat/workspace-plan-mode).
#   per-repo  — loop through project.conf REPOS and call ralph-plan once per repo.
#               Retained as fallback while rolling out workspace mode, and for
#               environments running an older ralph.
#
# Mode resolution order (first match wins):
#   1. CLI flag:      --mode workspace | --mode per-repo
#   2. Env var:       WB_RALPH_PLAN_MODE
#   3. project.conf:  RALPH_PLAN_MODE (auto | workspace | per-repo)
#   4. Auto-detect:   `ralph-plan --help` mentions workspace ⇒ workspace
#   5. Default:       workspace
#
# Engine and thinking depth are resolved similarly, with defaults:
#   RALPH_PLAN_ENGINE=devin  RALPH_PLAN_THINKING=ultra
#
# Usage:
#   ./scripts/ralph-plan.sh                         # all repos, resolved mode
#   ./scripts/ralph-plan.sh --mode per-repo
#   ./scripts/ralph-plan.sh <repo>                  # only meaningful in per-repo mode
#   ./scripts/ralph-plan.sh --engine claude --thinking hard
#   ./scripts/ralph-plan.sh --dry-run               # echo the ralph command, do not run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$WB_ROOT/project.conf" ]] || { echo "project.conf not found at $WB_ROOT" >&2; exit 1; }
# shellcheck disable=SC1091
source "$WB_ROOT/project.conf"

CLI_MODE=""
CLI_ENGINE=""
CLI_THINKING=""
CLI_REPO=""
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)      CLI_MODE="${2:-}"; shift 2 ;;
    --engine)    CLI_ENGINE="${2:-}"; shift 2 ;;
    --thinking)  CLI_THINKING="${2:-}"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --help|-h)   sed -n '2,32p' "$0"; exit 0 ;;
    -*)          echo "Unknown flag: $1" >&2; exit 2 ;;
    *)           CLI_REPO="$1"; shift ;;
  esac
done

# Preflight: workspace enabled, ralph on PATH.
"$SCRIPT_DIR/ralph-enable-check.sh"

_detect_workspace_support() {
  command -v ralph-plan >/dev/null 2>&1 || return 1
  ralph-plan --help 2>&1 | grep -q -- '--workspace'
}

_resolve_mode() {
  local mode="${CLI_MODE:-${WB_RALPH_PLAN_MODE:-${RALPH_PLAN_MODE:-auto}}}"
  case "$mode" in
    workspace|per-repo) echo "$mode"; return 0 ;;
    auto)
      if _detect_workspace_support; then
        echo "workspace"
      else
        echo "per-repo"
      fi
      return 0
      ;;
    *)
      echo "Invalid mode '$mode'. Use workspace | per-repo | auto." >&2
      exit 2
      ;;
  esac
}

ENGINE="${CLI_ENGINE:-${RALPH_PLAN_ENGINE:-devin}}"
THINKING="${CLI_THINKING:-${RALPH_PLAN_THINKING:-ultra}}"
MODE="$(_resolve_mode)"

echo "[wb.ralph-plan] mode=$MODE engine=$ENGINE thinking=$THINKING"

# Step 1: sync approved workbench context into repos/<name>/ai/.
echo "[1/2] Syncing approved context..."
if [[ -n "$CLI_REPO" && "$MODE" == "per-repo" ]]; then
  "$SCRIPT_DIR/sync-context.sh" "$CLI_REPO"
else
  "$SCRIPT_DIR/sync-context.sh"
fi

# Step 2: call ralph-plan.
echo "[2/2] Running ralph-plan ($MODE)..."

_workspace_call() {
  local cmd=(ralph-plan --workspace --engine "$ENGINE" --thinking "$THINKING")
  echo "  > (cd $WB_ROOT/repos && ${cmd[*]})"
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi
  (cd "$WB_ROOT/repos" && "${cmd[@]}")
}

_per_repo_call() {
  if [[ ${#REPOS[@]} -eq 0 ]]; then
    echo "No repos registered in project.conf." >&2
    exit 1
  fi
  local entry name role repo_dir
  for entry in "${REPOS[@]}"; do
    name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
    role="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^role=/) print substr($i,6)}')"
    [[ -n "$CLI_REPO" && "$name" != "$CLI_REPO" ]] && continue
    repo_dir="$WB_ROOT/repos/$name"
    if [[ ! -d "$repo_dir" ]]; then
      echo "  skip $name — not cloned at $repo_dir"
      continue
    fi
    echo "  ── $name ($role) ──"
    local cmd=(ralph-plan --engine "$ENGINE" --thinking "$THINKING")
    echo "    > (cd $repo_dir && ${cmd[*]})"
    if [[ "$DRY_RUN" == "true" ]]; then
      continue
    fi
    (cd "$repo_dir" && "${cmd[@]}") || echo "    plan failed for $name" >&2
  done
}

if [[ "$MODE" == "workspace" ]]; then
  _workspace_call
else
  _per_repo_call
fi

echo ""
echo "ralph-plan complete."
