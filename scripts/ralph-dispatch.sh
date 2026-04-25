#!/usr/bin/env bash
# ralph-dispatch.sh — Thin workbench wrapper for `ralph --workspace [--parallel N]`.
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
# Usage:
#   ./scripts/ralph-dispatch.sh                     # run workspace mode with resolved N
#   ./scripts/ralph-dispatch.sh --parallel 2
#   ./scripts/ralph-dispatch.sh --engine claude
#   ./scripts/ralph-dispatch.sh --status            # show open ralph-authored PRs + tail logs
#   ./scripts/ralph-dispatch.sh --dry-run           # echo the ralph command, do not run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$WB_ROOT/project.conf" ]] || { echo "project.conf not found at $WB_ROOT" >&2; exit 1; }
# shellcheck disable=SC1091
source "$WB_ROOT/project.conf"

CLI_PARALLEL=""
CLI_ENGINE=""
DRY_RUN=false
STATUS_MODE=false
EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --parallel) CLI_PARALLEL="${2:-}"; shift 2 ;;
    --engine)   CLI_ENGINE="${2:-}"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --status)   STATUS_MODE=true; shift ;;
    --help|-h)  sed -n '2,24p' "$0"; exit 0 ;;
    *)          EXTRA_ARGS+=("$1"); shift ;;
  esac
done

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

echo "[wb.ralph-dispatch] parallel=$PARALLEL engine=$ENGINE"

cmd=(ralph --workspace --parallel "$PARALLEL")
# Engine flag passthrough: ralph takes --engine for some binaries; for others
# engine selection happens at install time (ralph-devin / ralph-codex). Only
# pass --engine when the flag is recognized.
if ralph --help 2>&1 | grep -q -- '--engine'; then
  cmd+=(--engine "$ENGINE")
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
