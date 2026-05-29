#!/usr/bin/env bash
# Verifies scripts/ralph-enable-check.sh's root-.ralph handling:
#   - no root .ralph/                  -> passes (exit 0)
#   - benign empty stub (dirs only)    -> auto-healed (removed) + passes
#   - root .ralph/ with ralph state    -> hard refusal (exit 1), left intact
#
# The benign case exists because older ai-ralph engines scaffolded an empty
# .ralph/{logs,docs/generated} at startup before bailing; the workbench should
# self-heal that rather than block the user. Real state (a .ralphrc, fix_plan,
# etc.) still warrants a human-driven heal.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
CHECK_SRC="${REPO_ROOT}/scripts/ralph-enable-check.sh"

scratch="$(mktemp -d)"
scratch="$(cd "$scratch" && pwd -P)"
# shellcheck disable=SC2064
trap "rm -rf '$scratch'" EXIT

# Mock `ralph` on PATH so the command-exists check passes hermetically.
mkdir -p "$scratch/bin"
cat > "$scratch/bin/ralph" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$scratch/bin/ralph"
export PATH="$scratch/bin:$PATH"

fails=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

# Build a minimal enabled workspace wb at $1.
mkwb() {
  local wb="$1"
  mkdir -p "$wb/scripts" "$wb/repos/.ralph"
  : > "$wb/project.conf"
  echo "WORKSPACE_MODE=true" > "$wb/repos/.ralphrc"
  cp "$CHECK_SRC" "$wb/scripts/ralph-enable-check.sh"
  chmod +x "$wb/scripts/ralph-enable-check.sh"
}

run_check() {                       # run_check <wb> -> sets RC, OUT
  OUT="$(bash "$1/scripts/ralph-enable-check.sh" 2>&1)"; RC=$?
}

# --- Case A: no root .ralph/ -> pass ---------------------------------------
WB_A="$scratch/wb-a"; mkwb "$WB_A"
run_check "$WB_A"
[[ "$RC" -eq 0 ]] && pass "no root .ralph passes (exit 0)" || fail "no root .ralph should pass (rc=$RC: $OUT)"

# --- Case B: benign empty stub -> auto-healed + pass ------------------------
WB_B="$scratch/wb-b"; mkwb "$WB_B"
mkdir -p "$WB_B/.ralph/docs/generated" "$WB_B/.ralph/logs"
run_check "$WB_B"
[[ "$RC" -eq 0 ]] && pass "benign stub passes (exit 0)" || fail "benign stub should pass (rc=$RC: $OUT)"
[[ ! -d "$WB_B/.ralph" ]] && pass "benign stub auto-removed" || fail "benign stub not removed"
echo "$OUT" | grep -q "auto-healed" && pass "benign heal logs a message" || fail "missing auto-heal message"

# --- Case C: root .ralph/ with ralph state -> refuse, keep intact -----------
WB_C="$scratch/wb-c"; mkwb "$WB_C"
mkdir -p "$WB_C/.ralph/logs"
echo "WORKSPACE_MODE=true" > "$WB_C/.ralph/.ralphrc"   # real state file
run_check "$WB_C"
[[ "$RC" -eq 1 ]] && pass "real-state stub refuses (exit 1)" || fail "real-state stub should refuse (rc=$RC)"
[[ -d "$WB_C/.ralph" ]] && pass "real-state stub left intact" || fail "real-state stub wrongly removed"
echo "$OUT" | grep -q "ralph state found" && pass "real-state refusal explains why" || fail "missing real-state message"

# --- Case D: nested file in benign-looking dirs still counts as state -------
WB_D="$scratch/wb-d"; mkwb "$WB_D"
mkdir -p "$WB_D/.ralph/docs/generated"
: > "$WB_D/.ralph/docs/generated/output.md"            # a real generated file
run_check "$WB_D"
[[ "$RC" -eq 1 ]] && pass "nested file counts as state (exit 1)" || fail "nested file should refuse (rc=$RC)"
[[ -d "$WB_D/.ralph" ]] && pass "stub with nested file left intact" || fail "stub with nested file wrongly removed"

echo
if [[ "$fails" -eq 0 ]]; then
  echo "ALL PASS"
  exit 0
else
  echo "$fails FAILURE(S)"
  exit 1
fi
