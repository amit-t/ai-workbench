#!/usr/bin/env bash
# ralph-dispatch.sh — Launch ralph loops across multiple repos in parallel.
#
# Uses background processes with nohup. Each loop's stdout/err goes to
# ralph/logs/<repo>.log. PIDs recorded in ralph/<repo>.pid.
#
# Usage:
#   ./scripts/ralph-dispatch.sh                          # all repos in project.conf
#   ./scripts/ralph-dispatch.sh --repos svc-a,svc-b      # subset
#   ./scripts/ralph-dispatch.sh --agent devin            # override agent for all
#   ./scripts/ralph-dispatch.sh --status                 # show running loops

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$WB_ROOT/project.conf" ]] || { echo "project.conf not found" >&2; exit 1; }
source "$WB_ROOT/project.conf"

LOGS_DIR="$WB_ROOT/ralph/logs"
mkdir -p "$LOGS_DIR"

REPOS_FILTER=""
AGENT_NAME=""
STATUS_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repos)  REPOS_FILTER="$2"; shift 2 ;;
    --agent)  AGENT_NAME="$2"; shift 2 ;;
    --status) STATUS_MODE=true; shift ;;
    *)        echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ "$STATUS_MODE" == true ]]; then
  echo "Running ralph loops:"
  for pidfile in "$WB_ROOT/ralph"/*.pid; do
    [[ -f "$pidfile" ]] || continue
    local_name="$(basename "$pidfile" .pid)"
    local_pid="$(cat "$pidfile")"
    if ps -p "$local_pid" >/dev/null 2>&1; then
      echo "  $local_name  PID=$local_pid  (running)"
    else
      echo "  $local_name  PID=$local_pid  (not running — stale pidfile)"
    fi
  done
  exit 0
fi

_should_run() {
  local name="$1"
  [[ -z "$REPOS_FILTER" ]] && return 0
  IFS=',' read -ra WANT <<< "$REPOS_FILTER"
  for w in "${WANT[@]}"; do
    [[ "$w" == "$name" ]] && return 0
  done
  return 1
}

echo "Dispatching ralph loops..."
for entry in "${REPOS[@]}"; do
  name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
  _should_run "$name" || continue

  log="$LOGS_DIR/$name.log"
  pidfile="$WB_ROOT/ralph/$name.pid"

  if [[ -f "$pidfile" ]] && ps -p "$(cat "$pidfile")" >/dev/null 2>&1; then
    echo "  $name — already running (PID $(cat "$pidfile")); skipping"
    continue
  fi

  echo "  $name → $log"
  nohup "$SCRIPT_DIR/ralph-loop.sh" "$name" ${AGENT_NAME:+--agent $AGENT_NAME} \
    > "$log" 2>&1 &
  echo $! > "$pidfile"
done

echo ""
echo "All dispatched. Monitor:"
echo "  tail -f $LOGS_DIR/*.log"
echo "  ./scripts/ralph-dispatch.sh --status"
