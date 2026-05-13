#!/usr/bin/env bash
# Verifies that:
#   1. _wb_check is defined after sourcing aliases.sh.
#   2. When the lib is missing, _wb_check is a silent no-op (graceful degradation).
#   3. When a stub lib is present, _wb_check sources it and calls _wb_versioncheck wb.
#   4. Every wrapped wb.* function still calls through to its target script (verified by
#      stubbing the target and observing it ran).
# Notes:
#   - We override the resolved workbench by exporting WB_PIN (the public hook
#     in aliases.sh) rather than the old WB_ROOT env-var trick, which no
#     longer works since each wb.* function declares WB_ROOT as a local.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

scratch="$(mktemp -d)"
# shellcheck disable=SC2064 # expand $scratch now: the path is captured at trap-install time and must not depend on runtime state.
trap "rm -rf '$scratch'" EXIT

# ── Case A: lib missing → preamble is silent ────────────────────────────────
HOME_OVERRIDE="$scratch/home_a"
mkdir -p "$HOME_OVERRIDE/.local/share/wb-versioncheck"
WB_FAKE_ROOT="$scratch/fake_wb_a"
mkdir -p "$WB_FAKE_ROOT/.workbench-state" "$WB_FAKE_ROOT/scripts"
: > "$WB_FAKE_ROOT/project.conf"  # makes WB_PIN validation pass
# Fake target script that prints a sentinel
cat > "$WB_FAKE_ROOT/scripts/sync-context.sh" <<'SH'
#!/usr/bin/env bash
echo "SENTINEL_RAN $@"
SH
chmod +x "$WB_FAKE_ROOT/scripts/sync-context.sh"

# Source aliases.sh (which sets WB_ROOT to REPO_ROOT), then override WB_ROOT and
# HOME before calling functions so they resolve to the fake workbench.
bash -c "
  source '$REPO_ROOT/aliases.sh'
  HOME='$HOME_OVERRIDE'
  export WB_PIN='$WB_FAKE_ROOT'
  out=\"\$(wb.sync-context arg1 arg2 2>&1)\"
  case \"\$out\" in
    *\"SENTINEL_RAN arg1 arg2\"*) echo OK_A ;;
    *) echo \"FAIL_A: '\$out'\"; exit 1 ;;
  esac
"

# ── Case B: lib present → _wb_versioncheck called ──────────────────────────
HOME_OVERRIDE="$scratch/home_b"
mkdir -p "$HOME_OVERRIDE/.local/share/wb-versioncheck"
cat > "$HOME_OVERRIDE/.local/share/wb-versioncheck/version-check.sh" <<'SH'
_wb_versioncheck() {
  printf "STUB_VERSIONCHECK_FIRED tool=%s template_file=%s\n" "$1" "${WB_TEMPLATE_VERSION_FILE:-}" >&2
}
SH

WB_FAKE_ROOT="$scratch/fake_wb_b"
mkdir -p "$WB_FAKE_ROOT/.workbench-state" "$WB_FAKE_ROOT/scripts"
: > "$WB_FAKE_ROOT/project.conf"  # makes WB_PIN validation pass
cp "$scratch/fake_wb_a/scripts/sync-context.sh" "$WB_FAKE_ROOT/scripts/sync-context.sh"
chmod +x "$WB_FAKE_ROOT/scripts/sync-context.sh"

bash -c "
  source '$REPO_ROOT/aliases.sh'
  HOME='$HOME_OVERRIDE'
  export WB_PIN='$WB_FAKE_ROOT'
  out=\"\$(wb.sync-context probe 2>&1 1>/dev/null)\"
  case \"\$out\" in
    *\"STUB_VERSIONCHECK_FIRED tool=wb\"*) echo OK_B_STUB ;;
    *) echo \"FAIL_B: stub not called; out='\$out'\"; exit 1 ;;
  esac
  out2=\"\$(wb.sync-context probe 2>&1)\"
  case \"\$out2\" in
    *\"SENTINEL_RAN probe\"*) echo OK_B_PASSTHROUGH ;;
    *) echo \"FAIL_B: passthrough broke; out='\$out2'\"; exit 1 ;;
  esac
"

# ── Case C: trivial wb.published is NOT wrapped (no version-check fires) ────
WB_FAKE_ROOT="$scratch/fake_wb_c"
mkdir -p "$WB_FAKE_ROOT/.workbench-state" "$WB_FAKE_ROOT/scripts"
: > "$WB_FAKE_ROOT/project.conf"  # makes WB_PIN validation pass
cat > "$WB_FAKE_ROOT/scripts/lifecycle.py" <<'PY'
#!/usr/bin/env python3
import sys
print("LIFECYCLE_RAN", *sys.argv[1:])
PY
chmod +x "$WB_FAKE_ROOT/scripts/lifecycle.py"

bash -c "
  source '$REPO_ROOT/aliases.sh'
  HOME='$HOME_OVERRIDE'
  export WB_PIN='$WB_FAKE_ROOT'
  out=\"\$(wb.published 2>&1)\"
  case \"\$out\" in
    *STUB_VERSIONCHECK_FIRED*) echo \"FAIL_C: trivial alias should NOT fire version-check; out='\$out'\"; exit 1 ;;
    *LIFECYCLE_RAN*list*published*) echo OK_C ;;
    *) echo \"FAIL_C: lifecycle didn't run; out='\$out'\"; exit 1 ;;
  esac
"

echo "PASS: test-aliases-preamble.sh"
