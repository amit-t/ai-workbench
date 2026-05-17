#!/usr/bin/env bash
# ralph-dispatch.sh — Thin workbench wrapper for `ralph --workspace [--parallel N [M]]`.
#
# Workbench wraps; ralph owns the core. Parallelism is handled by ralph itself
# via --parallel. Single-repo debugging is a one-liner:
#
#   (cd $WB_ROOT/repos/<name> && ralph --live --monitor)
#
# Parallelism resolution order (first match wins):
#   1. CLI flag:      --parallel N
#   2. Env var:       WB_RALPH_PARALLEL
#   3. project.conf:  WB_RALPH_PARALLEL
#   4. Default:       min(len(REPOS), 4)
#
# Engine resolution order:
#   1. CLI flag:      --engine
#   2. Env var:       WB_RALPH_ENGINE
#   3. project.conf:  WB_RALPH_ENGINE (falls back to RALPH_PLAN_ENGINE, then devin)
#
# Repo-subset filter (forwarded to ralph --workspace --repos / --exclude):
#   1. CLI flag:      --repos a,b   |  --exclude c
#   2. Env var:       WB_RALPH_DISPATCH_REPOS  |  WB_RALPH_DISPATCH_EXCLUDE
#   3. project.conf:  WB_RALPH_DISPATCH_REPOS  |  WB_RALPH_DISPATCH_EXCLUDE
#   4. Default:       unset (run all repos, V1 behavior)
# --repos and --exclude are mutually exclusive.
#
# Continuous mode (opt-in; ralph keeps N workers saturated until M attempts):
#   Engaged by setting M (the total-attempts cap). Two ways:
#     --max-tasks M               named form (preferred; pairs cleanly with project.conf)
#     --parallel N M              positional form (byte-identical to `ralph --parallel N M`)
#   Without M, the wrapper runs ralph in batch mode (V1 behavior).
#
#   Resolution order for M:
#     1. CLI:           --max-tasks M  OR positional second arg to --parallel
#     2. Env:           WB_RALPH_MAX_TASKS
#     3. project.conf:  WB_RALPH_MAX_TASKS
#     4. Default:       unset (batch mode)
#
#   Continuous-mode tuning knobs (only meaningful when M is set):
#     --max-task-attempts K       per-task retry cap (env: WB_RALPH_MAX_TASK_ATTEMPTS)
#     --respawn-delay SEC         cooldown between worker respawns (env: WB_RALPH_RESPAWN_DELAY)
#     --no-tabs                   force single-pane orchestrator (env: WB_RALPH_DISABLE_TABS=true)
#
#   Capability-gated: only forwarded when `ralph --help` advertises the
#   continuous-mode surface. Older ralph silently dropping unknown flags
#   would lead to confusing "batch ran instead of continuous" surprises,
#   so the wrapper fails fast instead.
#
# Usage:
#   ./scripts/ralph-dispatch.sh                     # run workspace mode with resolved N
#   ./scripts/ralph-dispatch.sh --parallel 2
#   ./scripts/ralph-dispatch.sh --engine claude
#   ./scripts/ralph-dispatch.sh --repos api,worker  # subset to two registered repos
#   ./scripts/ralph-dispatch.sh --exclude web       # everything except web
#   ./scripts/ralph-dispatch.sh --parallel 3 --max-tasks 30   # continuous, 30 attempts
#   ./scripts/ralph-dispatch.sh --parallel 3 30               # same, positional form
#   ./scripts/ralph-dispatch.sh --parallel 3 30 --no-tabs --respawn-delay 5
#   ./scripts/ralph-dispatch.sh --status            # show open ralph-authored PRs + tail logs
#   ./scripts/ralph-dispatch.sh --dry-run           # echo the ralph command, do not run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$WB_ROOT/project.conf" ]] || { echo "project.conf not found at $WB_ROOT" >&2; exit 1; }

# Capture env-state BEFORE sourcing project.conf, so per-invocation env vars
# survive the source (project.conf may set its own defaults to empty).
_env_WB_RALPH_PARALLEL="${WB_RALPH_PARALLEL:-}"
_env_WB_RALPH_ENGINE="${WB_RALPH_ENGINE:-}"
_env_WB_RALPH_DISPATCH_REPOS="${WB_RALPH_DISPATCH_REPOS:-}"
_env_WB_RALPH_DISPATCH_EXCLUDE="${WB_RALPH_DISPATCH_EXCLUDE:-}"
_env_WB_RALPH_MAX_TASKS="${WB_RALPH_MAX_TASKS:-}"
_env_WB_RALPH_MAX_TASK_ATTEMPTS="${WB_RALPH_MAX_TASK_ATTEMPTS:-}"
_env_WB_RALPH_RESPAWN_DELAY="${WB_RALPH_RESPAWN_DELAY:-}"
_env_WB_RALPH_DISABLE_TABS="${WB_RALPH_DISABLE_TABS:-}"

# shellcheck disable=SC1091
source "$WB_ROOT/project.conf"

# Restore env-supplied values when user actually exported them.
[[ -n "$_env_WB_RALPH_PARALLEL"          ]] && WB_RALPH_PARALLEL="$_env_WB_RALPH_PARALLEL"
[[ -n "$_env_WB_RALPH_ENGINE"            ]] && WB_RALPH_ENGINE="$_env_WB_RALPH_ENGINE"
[[ -n "$_env_WB_RALPH_DISPATCH_REPOS"    ]] && WB_RALPH_DISPATCH_REPOS="$_env_WB_RALPH_DISPATCH_REPOS"
[[ -n "$_env_WB_RALPH_DISPATCH_EXCLUDE"  ]] && WB_RALPH_DISPATCH_EXCLUDE="$_env_WB_RALPH_DISPATCH_EXCLUDE"
[[ -n "$_env_WB_RALPH_MAX_TASKS"         ]] && WB_RALPH_MAX_TASKS="$_env_WB_RALPH_MAX_TASKS"
[[ -n "$_env_WB_RALPH_MAX_TASK_ATTEMPTS" ]] && WB_RALPH_MAX_TASK_ATTEMPTS="$_env_WB_RALPH_MAX_TASK_ATTEMPTS"
[[ -n "$_env_WB_RALPH_RESPAWN_DELAY"     ]] && WB_RALPH_RESPAWN_DELAY="$_env_WB_RALPH_RESPAWN_DELAY"
[[ -n "$_env_WB_RALPH_DISABLE_TABS"      ]] && WB_RALPH_DISABLE_TABS="$_env_WB_RALPH_DISABLE_TABS"

CLI_PARALLEL=""
CLI_ENGINE=""
CLI_REPOS=""
CLI_EXCLUDE=""
CLI_MAX_TASKS=""
CLI_MAX_TASK_ATTEMPTS=""
CLI_RESPAWN_DELAY=""
CLI_NO_TABS=""
DRY_RUN=false
STATUS_MODE=false
EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --parallel)
      CLI_PARALLEL="${2:-}"
      shift 2
      # Optional positional second arg = M (continuous mode). Mirrors ralph's
      # `--parallel N M` shape; only consumed when it looks like an integer.
      # A non-integer next arg falls through to EXTRA_ARGS (pass-through).
      if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
        if [[ ! "$1" =~ ^[1-9][0-9]*$ ]]; then
          echo "ERROR: continuous-mode M (second --parallel argument) must be a positive integer >= 1 (got: '$1')" >&2
          exit 1
        fi
        CLI_MAX_TASKS="$1"
        shift
      fi
      ;;
    --max-tasks)         CLI_MAX_TASKS="${2:-}"; shift 2 ;;
    --max-task-attempts) CLI_MAX_TASK_ATTEMPTS="${2:-}"; shift 2 ;;
    --respawn-delay)     CLI_RESPAWN_DELAY="${2:-}"; shift 2 ;;
    --no-tabs)           CLI_NO_TABS=true; shift ;;
    --engine)   CLI_ENGINE="${2:-}"; shift 2 ;;
    --repos)    CLI_REPOS="${2:-}"; shift 2 ;;
    --exclude)  CLI_EXCLUDE="${2:-}"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --status)   STATUS_MODE=true; shift ;;
    --help|-h)  sed -n '2,59p' "$0"; exit 0 ;;
    *)          EXTRA_ARGS+=("$1"); shift ;;
  esac
done

if [[ -n "$CLI_REPOS" && -n "$CLI_EXCLUDE" ]]; then
  echo "ERROR: --repos and --exclude cannot be combined" >&2
  exit 1
fi

REPOS_ROOT="$WB_ROOT/repos"

_len_repos() {
  echo "${#REPOS[@]}"
}

_default_parallel() {
  local n cap=4
  n="$(_len_repos)"
  [[ "$n" -le 0 ]] && n=1
  [[ "$n" -gt "$cap" ]] && n="$cap"
  echo "$n"
}

_status() {
  echo "== Open PRs on registered repos =="
  if ! command -v gh >/dev/null 2>&1; then
    echo "  gh not installed; skipping PR listing"
  else
    local entry name url repo_slug
    for entry in "${REPOS[@]}"; do
      name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
      url="$(echo "$entry"  | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^url=/)  print substr($i,5)}')"
      repo_slug="$(echo "$url" | sed -E 's#^https?://[^/]+/##; s#\.git$##')"
      [[ -z "$repo_slug" ]] && continue
      echo "-- $name ($repo_slug) --"
      gh pr list -R "$repo_slug" --state open --search 'head:rp-' \
        --json number,title,headRefName,url,createdAt \
        --template '{{range .}}  #{{.number}} {{.title}} ({{.headRefName}}) -> {{.url}}{{"\n"}}{{end}}' 2>/dev/null \
        || echo "  (gh pr list failed for $repo_slug)"
    done
  fi

  local log_glob="$REPOS_ROOT/.ralph/logs/parallel"
  echo ""
  echo "== Recent ralph worker logs =="
  if [[ -d "$log_glob" ]]; then
    ls -1t "$log_glob"/*.log 2>/dev/null | head -5 | while read -r f; do
      echo "-- $f --"
      tail -n 3 "$f"
    done
  else
    echo "  no logs at $log_glob"
  fi
}

if [[ "$STATUS_MODE" == true ]]; then
  _status
  exit 0
fi

# Preflight: workspace enabled, ralph on PATH.
"$SCRIPT_DIR/ralph-enable-check.sh"

PARALLEL="${CLI_PARALLEL:-${WB_RALPH_PARALLEL:-${RALPH_DISPATCH_PARALLEL:-}}}"
if [[ -z "$PARALLEL" ]]; then
  PARALLEL="$(_default_parallel)"
fi

ENGINE="${CLI_ENGINE:-${WB_RALPH_ENGINE:-${RALPH_PLAN_ENGINE:-devin}}}"

# Resolve repo-subset filter: CLI > env > project.conf. Mutually exclusive.
REPOS_FILTER="${CLI_REPOS:-${WB_RALPH_DISPATCH_REPOS:-}}"
EXCLUDE_FILTER="${CLI_EXCLUDE:-${WB_RALPH_DISPATCH_EXCLUDE:-}}"
if [[ -n "$REPOS_FILTER" && -n "$EXCLUDE_FILTER" ]]; then
  echo "ERROR: --repos / WB_RALPH_DISPATCH_REPOS conflicts with --exclude / WB_RALPH_DISPATCH_EXCLUDE; pick one" >&2
  exit 1
fi

# Validate filter names against project.conf REPOS so a typo fails inside the
# wrapper with the registered-repo list visible. Names are matched as basenames
# of the registered repo entries.
_validate_filter_against_registered() {
  local _list="$1"
  local _label="$2"
  [[ -z "$_list" ]] && return 0
  local registered
  registered=$(printf '%s\n' "${REPOS[@]}" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')
  local IFS_saved="$IFS"
  IFS=','
  read -r -a wanted <<< "$_list"
  IFS="$IFS_saved"
  local n trimmed
  for n in "${wanted[@]}"; do
    trimmed="$(echo "$n" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [[ -z "$trimmed" ]] && continue
    if ! echo "$registered" | grep -qxF "$trimmed"; then
      local reg_csv
      reg_csv="$(echo "$registered" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')"
      echo "ERROR: ${_label} names unknown repo '$trimmed'. Registered: ${reg_csv}" >&2
      exit 1
    fi
  done
}
_validate_filter_against_registered "$REPOS_FILTER"   "--repos / WB_RALPH_DISPATCH_REPOS"
_validate_filter_against_registered "$EXCLUDE_FILTER" "--exclude / WB_RALPH_DISPATCH_EXCLUDE"

# Resolve continuous-mode knobs: CLI > env > project.conf > unset.
# M (max-tasks) is the engagement signal — setting it flips ralph into
# continuous mode. The tuning knobs (K, SEC, --no-tabs) are inert without M.
MAX_TASKS="${CLI_MAX_TASKS:-${WB_RALPH_MAX_TASKS:-}}"
MAX_TASK_ATTEMPTS="${CLI_MAX_TASK_ATTEMPTS:-${WB_RALPH_MAX_TASK_ATTEMPTS:-}}"
RESPAWN_DELAY="${CLI_RESPAWN_DELAY:-${WB_RALPH_RESPAWN_DELAY:-}}"
# --no-tabs is a flag (no value). CLI flag wins; otherwise truthy env value.
if [[ -n "$CLI_NO_TABS" ]]; then
  NO_TABS=true
elif [[ "${WB_RALPH_DISABLE_TABS:-}" == "true" ]]; then
  NO_TABS=true
else
  NO_TABS=false
fi

# Validate continuous-mode knobs (loud failure when set with bad values).
if [[ -n "$MAX_TASKS" ]] && [[ ! "$MAX_TASKS" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: --max-tasks / WB_RALPH_MAX_TASKS must be a positive integer >= 1 (got: '$MAX_TASKS')" >&2
  exit 1
fi
if [[ -n "$MAX_TASK_ATTEMPTS" ]] && [[ ! "$MAX_TASK_ATTEMPTS" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: --max-task-attempts / WB_RALPH_MAX_TASK_ATTEMPTS must be a positive integer >= 1 (got: '$MAX_TASK_ATTEMPTS')" >&2
  exit 1
fi
if [[ -n "$RESPAWN_DELAY" ]] && [[ ! "$RESPAWN_DELAY" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "ERROR: --respawn-delay / WB_RALPH_RESPAWN_DELAY must be a non-negative number (got: '$RESPAWN_DELAY')" >&2
  exit 1
fi

# Mode label for the banner.
if [[ -n "$MAX_TASKS" ]]; then
  MODE="continuous"
else
  MODE="batch"
fi

echo "[wb.ralph-dispatch] mode=$MODE parallel=$PARALLEL max_tasks=${MAX_TASKS:-<unset>} max_task_attempts=${MAX_TASK_ATTEMPTS:-<unset>} respawn_delay=${RESPAWN_DELAY:-<unset>} tabs=$([[ "$NO_TABS" == true ]] && echo off || echo on) engine=$ENGINE repos=${REPOS_FILTER:-<all>} exclude=${EXCLUDE_FILTER:-<none>}"

cmd=(ralph --workspace --parallel "$PARALLEL")
# Continuous mode: forward M as the second positional arg to --parallel and
# any tuning knobs as separate flags. Capability-gated against `ralph --help`
# so older ralph fails loudly instead of running batch-when-you-asked-for-
# continuous. Tuning knobs without M are inert; ralph accepts them but they
# only matter in continuous mode (we still forward them for parity).
_ralph_help=""
_has_continuous=false
if [[ -n "$MAX_TASKS" || -n "$MAX_TASK_ATTEMPTS" || -n "$RESPAWN_DELAY" || "$NO_TABS" == true ]]; then
  _ralph_help="$(ralph --help 2>&1 || true)"
  if echo "$_ralph_help" | grep -Eq -- '--parallel N M|Continuous Parallel Execution|--max-task-attempts'; then
    _has_continuous=true
  fi
fi

if [[ -n "$MAX_TASKS" ]]; then
  if [[ "$_has_continuous" == true ]]; then
    cmd+=("$MAX_TASKS")
  else
    echo "ERROR: installed ralph does not advertise continuous mode (--parallel N M); cannot honor --max-tasks $MAX_TASKS. Upgrade ai-ralph or drop the flag." >&2
    exit 1
  fi
fi
if [[ -n "$MAX_TASK_ATTEMPTS" ]]; then
  if echo "${_ralph_help}" | grep -q -- '--max-task-attempts'; then
    cmd+=(--max-task-attempts "$MAX_TASK_ATTEMPTS")
  else
    echo "WARN: installed ralph does not support --max-task-attempts; ignoring." >&2
  fi
fi
if [[ -n "$RESPAWN_DELAY" ]]; then
  if echo "${_ralph_help}" | grep -q -- '--respawn-delay'; then
    cmd+=(--respawn-delay "$RESPAWN_DELAY")
  else
    echo "WARN: installed ralph does not support --respawn-delay; ignoring." >&2
  fi
fi
if [[ "$NO_TABS" == true ]]; then
  if echo "${_ralph_help}" | grep -q -- '--no-tabs'; then
    cmd+=(--no-tabs)
  else
    echo "WARN: installed ralph does not support --no-tabs; ignoring." >&2
  fi
fi

# Engine flag passthrough: ralph takes --engine for some binaries; for others
# engine selection happens at install time (ralph-devin / ralph-codex). Only
# pass --engine when the flag is recognized.
if ralph --help 2>&1 | grep -q -- '--engine'; then
  cmd+=(--engine "$ENGINE")
fi
# Repo-subset passthrough (only when ralph supports the flags; older ralph
# silently rejects unknown flags so we do not pass through if unsupported).
if [[ -n "$REPOS_FILTER" ]]; then
  if ralph --help 2>&1 | grep -q -- '--repos'; then
    cmd+=(--repos "$REPOS_FILTER")
  else
    echo "WARN: installed ralph does not support --repos; ignoring filter" >&2
  fi
fi
if [[ -n "$EXCLUDE_FILTER" ]]; then
  if ralph --help 2>&1 | grep -q -- '--exclude'; then
    cmd+=(--exclude "$EXCLUDE_FILTER")
  else
    echo "WARN: installed ralph does not support --exclude; ignoring filter" >&2
  fi
fi
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  cmd+=("${EXTRA_ARGS[@]}")
fi

echo "  > (cd $REPOS_ROOT && WORKSPACE_ROOT=$REPOS_ROOT ${cmd[*]})"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[dry-run] not executing"
  exit 0
fi

cd "$REPOS_ROOT"
WORKSPACE_ROOT="$REPOS_ROOT" "${cmd[@]}"
