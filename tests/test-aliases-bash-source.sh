#!/usr/bin/env bash
# Verifies aliases.sh is sourceable from both bash and zsh, and that
# _wb_check degrades to a silent no-op when the version-check lib is missing.
#
# Wave 3 PR 3b of the WSL2 port (notes/wsl-port-plan.md). ubuntu-latest in CI
# acts as the WSL proxy; macos-latest must stay green per the hard rule.
set -euo pipefail

WB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

# 1. bash source + function visibility
if bash -c "source '$WB_DIR/aliases.sh' && type wb.publish >/dev/null && type wb.approve >/dev/null && type wb.ralph-plan >/dev/null"; then
  echo "[ok] bash source: aliases visible"
else
  echo "[FAIL] bash source: aliases not visible after source"
  fail=1
fi

# 2. zsh source + function visibility (skip if zsh missing)
if command -v zsh >/dev/null 2>&1; then
  if zsh -c "source '$WB_DIR/aliases.sh' && type wb.publish >/dev/null && type wb.approve >/dev/null && type wb.ralph-plan >/dev/null"; then
    echo "[ok] zsh source: aliases visible"
  else
    echo "[FAIL] zsh source: aliases not visible after source"
    fail=1
  fi
else
  echo "[skip] zsh not installed; skipping zsh source check"
fi

# 3. _wb_check is a silent no-op when the version-check lib is absent.
# HOME=/nonexistent forces the lib-path check inside _wb_check to fail
# (the lib lives at ${HOME}/.local/share/wb-versioncheck/version-check.sh).
# We assert: exit 0 AND no 'error' token in combined stdout/stderr.
rc=0
out="$(HOME=/nonexistent bash -c "source '$WB_DIR/aliases.sh' && _wb_check" 2>&1)" || rc=$?
if [[ $rc -eq 0 ]] && ! printf '%s' "$out" | grep -qi 'error'; then
  echo "[ok] _wb_check: graceful no-op when version-check missing"
else
  echo "[FAIL] _wb_check: rc=$rc out=${out}"
  fail=1
fi

exit "$fail"
