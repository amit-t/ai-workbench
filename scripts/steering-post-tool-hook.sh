#!/usr/bin/env bash
# scripts/steering-post-tool-hook.sh
#
# PostToolUse hook wired from .claude/settings.json.
# Receives a JSON payload on stdin describing the tool invocation that just
# completed (see https://docs.claude.com/en/docs/claude-code/hooks for the
# schema). When the invocation touched update.wb, a git pull/merge, or any
# file under steering/ or steering.local/, this hook re-emits the merged
# Layer 0 steering to stderr so the agent re-reads it mid-session.
#
# Non-zero exit would cancel the triggering tool, which we never want here —
# always exit 0.

set -u

WB_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

payload=""
if [[ -t 0 ]]; then
  :
else
  payload="$(cat || true)"
fi

should_reload=false

# Lightweight match: we do not parse JSON strictly. Look for the substrings
# that indicate relevant activity.
if [[ "$payload" == *"update.wb"*       ]] \
|| [[ "$payload" == *"git pull"*        ]] \
|| [[ "$payload" == *"git merge"*       ]] \
|| [[ "$payload" == *'"steering/'*      ]] \
|| [[ "$payload" == *'"steering.local/'* ]]; then
  should_reload=true
fi

if [[ "$should_reload" == "true" ]]; then
  if [[ -f "$WB_ROOT/scripts/steering-load.py" ]]; then
    echo "[steering] Reloading Layer 0 (golden) after tool use." >&2
    WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/steering-load.py" golden >&2 || true
  fi
fi

exit 0
