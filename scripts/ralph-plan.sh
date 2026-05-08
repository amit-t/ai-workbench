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
# Parallel-plan resolution order (workspace mode only; forwarded to ralph-plan
# --parallel-plan N):
#   1. CLI flag:      --parallel-plan N
#   2. Env var:       WB_RALPH_PLAN_PARALLEL
#   3. project.conf:  RALPH_PLAN_PARALLEL
#   4. Default:       unset (let ralph pick its own default — sequential V1)
#
# Usage:
#   ./scripts/ralph-plan.sh                         # all repos, resolved mode
#   ./scripts/ralph-plan.sh --mode per-repo
#   ./scripts/ralph-plan.sh <repo>                  # only meaningful in per-repo mode
#   ./scripts/ralph-plan.sh --engine claude --thinking hard
#   ./scripts/ralph-plan.sh --dry-run               # echo the ralph command, do not run
#   ./scripts/ralph-plan.sh --replan <repo>         # regen one repo's plan section
#                                                   # and splice into repos/.ralph/fix_plan.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$WB_ROOT/project.conf" ]] || { echo "project.conf not found at $WB_ROOT" >&2; exit 1; }

# Capture env-state BEFORE sourcing project.conf so per-invocation env vars
# survive (project.conf often sets its own knobs to empty defaults).
_env_RALPH_PLAN_MODE="${RALPH_PLAN_MODE:-}"
_env_WB_RALPH_PLAN_MODE="${WB_RALPH_PLAN_MODE:-}"
_env_RALPH_PLAN_ENGINE="${RALPH_PLAN_ENGINE:-}"
_env_RALPH_PLAN_THINKING="${RALPH_PLAN_THINKING:-}"
_env_RALPH_PLAN_PARALLEL="${RALPH_PLAN_PARALLEL:-}"
_env_WB_RALPH_PLAN_PARALLEL="${WB_RALPH_PLAN_PARALLEL:-}"

# shellcheck disable=SC1091
source "$WB_ROOT/project.conf"

[[ -n "$_env_RALPH_PLAN_MODE"          ]] && RALPH_PLAN_MODE="$_env_RALPH_PLAN_MODE"
[[ -n "$_env_WB_RALPH_PLAN_MODE"       ]] && WB_RALPH_PLAN_MODE="$_env_WB_RALPH_PLAN_MODE"
[[ -n "$_env_RALPH_PLAN_ENGINE"        ]] && RALPH_PLAN_ENGINE="$_env_RALPH_PLAN_ENGINE"
[[ -n "$_env_RALPH_PLAN_THINKING"      ]] && RALPH_PLAN_THINKING="$_env_RALPH_PLAN_THINKING"
[[ -n "$_env_RALPH_PLAN_PARALLEL"      ]] && RALPH_PLAN_PARALLEL="$_env_RALPH_PLAN_PARALLEL"
[[ -n "$_env_WB_RALPH_PLAN_PARALLEL"   ]] && WB_RALPH_PLAN_PARALLEL="$_env_WB_RALPH_PLAN_PARALLEL"

CLI_MODE=""
CLI_ENGINE=""
CLI_THINKING=""
CLI_REPO=""
CLI_REPLAN=""
CLI_PARALLEL_PLAN=""
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)          CLI_MODE="${2:-}"; shift 2 ;;
    --engine)        CLI_ENGINE="${2:-}"; shift 2 ;;
    --thinking)      CLI_THINKING="${2:-}"; shift 2 ;;
    --replan)        CLI_REPLAN="${2:-}"; shift 2 ;;
    --parallel-plan) CLI_PARALLEL_PLAN="${2:-}"; shift 2 ;;
    --dry-run)       DRY_RUN=true; shift ;;
    --help|-h)       sed -n '2,42p' "$0"; exit 0 ;;
    -*)              echo "Unknown flag: $1" >&2; exit 2 ;;
    *)               CLI_REPO="$1"; shift ;;
  esac
done

# --parallel-plan only applies to workspace mode (planner-side concept).
if [[ -n "$CLI_PARALLEL_PLAN" ]]; then
  if [[ -n "$CLI_REPLAN" ]]; then
    echo "[wb.ralph-plan] --parallel-plan and --replan are mutually exclusive (replan is per-repo)." >&2
    exit 2
  fi
  if [[ -n "$CLI_REPO" ]]; then
    echo "[wb.ralph-plan] --parallel-plan and a positional repo are mutually exclusive (parallel-plan is workspace mode)." >&2
    exit 2
  fi
fi

if [[ -n "$CLI_REPLAN" && -n "$CLI_MODE" ]]; then
  echo "[wb.ralph-plan] --replan and --mode are mutually exclusive (replan is always per-repo)." >&2
  exit 2
fi
if [[ -n "$CLI_REPLAN" && -n "$CLI_REPO" ]]; then
  echo "[wb.ralph-plan] --replan and a positional repo are mutually exclusive." >&2
  exit 2
fi

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
PARALLEL_PLAN="${CLI_PARALLEL_PLAN:-${WB_RALPH_PLAN_PARALLEL:-${RALPH_PLAN_PARALLEL:-}}}"

# Validate parallel-plan if set: must be a positive integer.
if [[ -n "$PARALLEL_PLAN" ]]; then
  if ! [[ "$PARALLEL_PLAN" =~ ^[1-9][0-9]*$ ]]; then
    echo "[wb.ralph-plan] --parallel-plan must be a positive integer (got: $PARALLEL_PLAN)" >&2
    exit 2
  fi
fi

_repo_registered() {
  local target="$1"
  local entry name
  for entry in "${REPOS[@]}"; do
    name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
    [[ "$name" == "$target" ]] && return 0
  done
  return 1
}

if [[ -n "$CLI_REPLAN" ]]; then
  if ! _repo_registered "$CLI_REPLAN"; then
    echo "[wb.ralph-plan] --replan: repo '$CLI_REPLAN' is not registered in project.conf REPOS." >&2
    exit 2
  fi
  MODE="replan"
else
  MODE="$(_resolve_mode)"
fi

echo "[wb.ralph-plan] mode=$MODE engine=$ENGINE thinking=$THINKING parallel-plan=${PARALLEL_PLAN:-<unset>}"

# Step 1: sync approved workbench context into repos/<name>/ai/.
echo "[1/2] Syncing approved context..."
if [[ -n "$CLI_REPLAN" ]]; then
  "$SCRIPT_DIR/sync-context.sh" "$CLI_REPLAN"
elif [[ -n "$CLI_REPO" && "$MODE" == "per-repo" ]]; then
  "$SCRIPT_DIR/sync-context.sh" "$CLI_REPO"
else
  "$SCRIPT_DIR/sync-context.sh"
fi

# Step 2: call ralph-plan.
echo "[2/2] Running ralph-plan ($MODE)..."

_workspace_call() {
  local cmd=(ralph-plan --workspace --engine "$ENGINE" --thinking "$THINKING")
  if [[ -n "$PARALLEL_PLAN" ]]; then
    if ralph-plan --help 2>&1 | grep -q -- '--parallel-plan'; then
      cmd+=(--parallel-plan "$PARALLEL_PLAN")
    else
      echo "WARN: installed ralph-plan does not support --parallel-plan; ignoring" >&2
    fi
  fi
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

_replan_call() {
  local target="$1"
  local repo_dir="$WB_ROOT/repos/$target"
  if [[ ! -d "$repo_dir" ]]; then
    echo "[wb.ralph-plan] --replan: repo dir not cloned at $repo_dir" >&2
    exit 1
  fi

  local cmd=(ralph-plan --engine "$ENGINE" --thinking "$THINKING")
  echo "  ── $target (replan) ──"
  echo "    > (cd $repo_dir && ${cmd[*]})"

  local workspace_plan="$WB_ROOT/repos/.ralph/fix_plan.md"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "    [dry-run] would splice into $workspace_plan under flock on .workbench-state/.lock"
    return 0
  fi

  (cd "$repo_dir" && "${cmd[@]}") || {
    echo "[wb.ralph-plan] --replan: ralph-plan failed for $target" >&2
    exit 1
  }

  local per_repo_plan="$repo_dir/.ralph/fix_plan.md"
  if [[ ! -f "$per_repo_plan" ]]; then
    echo "[wb.ralph-plan] --replan: ralph-plan did not produce $per_repo_plan" >&2
    exit 1
  fi

  local tmp_plan
  tmp_plan="$(mktemp -t fix_plan.repo.XXXXXX)"
  trap 'rm -f "$tmp_plan"' EXIT
  cp "$per_repo_plan" "$tmp_plan"

  local lock_file="$WB_ROOT/.workbench-state/.lock"
  mkdir -p "$WB_ROOT/.workbench-state" "$WB_ROOT/repos/.ralph"
  [[ -e "$lock_file" ]] || : > "$lock_file"

  WB_REPLAN_REPO="$target" \
  WB_REPLAN_SECTION="$tmp_plan" \
  WB_REPLAN_WORKSPACE="$workspace_plan" \
  WB_REPLAN_LOCK="$lock_file" \
  python3 - <<'PYEOF'
import fcntl, os, re, sys
from pathlib import Path

repo = os.environ["WB_REPLAN_REPO"]
section_path = Path(os.environ["WB_REPLAN_SECTION"])
workspace = Path(os.environ["WB_REPLAN_WORKSPACE"])
lock_path = os.environ["WB_REPLAN_LOCK"]

raw = section_path.read_text().strip("\n")
header_re = re.compile(rf"^## +{re.escape(repo)}\b", re.MULTILINE)
if not header_re.match(raw):
    raw = f"## {repo}\n\n{raw}"
section = raw.rstrip() + "\n"

with open(lock_path, "a+") as fh:
    fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
    try:
        current = workspace.read_text() if workspace.exists() else ""
        repo_section = re.compile(
            rf"(?ms)^## +{re.escape(repo)}\b.*?(?=^## +\S|\Z)"
        )
        if repo_section.search(current):
            new = repo_section.sub(section + "\n", current, count=1)
        else:
            sep = "" if (not current or current.endswith("\n\n")) else (
                "\n" if current.endswith("\n") else "\n\n"
            )
            new = current + sep + section
        workspace.parent.mkdir(parents=True, exist_ok=True)
        workspace.write_text(new)
    finally:
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
PYEOF

  rm -f "$tmp_plan"
  trap - EXIT
  echo "[wb.ralph-plan] --replan: spliced '$target' into $workspace_plan"
}

if [[ "$MODE" == "replan" ]]; then
  _replan_call "$CLI_REPLAN"
elif [[ "$MODE" == "workspace" ]]; then
  _workspace_call
else
  _per_repo_call
fi

echo ""
echo "ralph-plan complete."
