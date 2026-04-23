#!/usr/bin/env bash
# ralph-context.sh — alias for sync-context.sh (ralph-plan.sh calls this name).
#
# Kept separate so the adapter contract is explicit:
#   sync-context.sh  — user-facing context push
#   ralph-context.sh — internal pre-plan context push
# Both currently do the same thing. Once workspace-mode ralph ships and expects
# context at a different layout, only ralph-context.sh changes.

exec "$(dirname "$0")/sync-context.sh" "$@"
