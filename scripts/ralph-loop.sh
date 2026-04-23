#!/usr/bin/env bash
# ralph-loop.sh — Run a ralph loop in one repo.
#
# Usage:
#   ./scripts/ralph-loop.sh <repo-name> [--agent claude|devin|codex]
#   ./scripts/ralph-loop.sh payments-svc
#   ./scripts/ralph-loop.sh payments-svc --agent devin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[[ -f "$WB_ROOT/project.conf" ]] || { echo "project.conf not found" >&2; exit 1; }
source "$WB_ROOT/project.conf"

REPO_NAME="${1:-}"
[[ -z "$REPO_NAME" ]] && { echo "Usage: ralph-loop.sh <repo-name> [--agent claude|devin|codex]" >&2; exit 1; }
shift

AGENT_NAME="claude"
[[ "${DEVIN_DEFAULT:-true}" == "true" ]] && AGENT_NAME="devin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT_NAME="${2:-claude}"; shift 2 ;;
    *)       echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

REPO_DIR="$WB_ROOT/repos/$REPO_NAME"
[[ -d "$REPO_DIR" ]] || { echo "Repo not cloned: $REPO_DIR" >&2; exit 1; }

echo "Launching ralph loop: repo=$REPO_NAME agent=$AGENT_NAME"
cd "$REPO_DIR"

case "$AGENT_NAME" in
  claude) command -v rpc.int >/dev/null 2>&1 && rpc.int || ralph --live --monitor ;;
  devin)  command -v rpd.int >/dev/null 2>&1 && rpd.int || ralph-devin --live --monitor ;;
  codex)  command -v rpx.int >/dev/null 2>&1 && rpx.int || ralph-codex --live --monitor ;;
  *)      echo "Unknown agent: $AGENT_NAME" >&2; exit 1 ;;
esac
