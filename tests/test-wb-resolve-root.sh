#!/usr/bin/env bash
# Verifies _wb_resolve_root + wb.switch / wb.unswitch / wb.where behave
# per docs/superpowers/specs/2026-05-13-wb-multi-workbench-resolution-design.md.
#
# Pin (WB_PIN) > cwd walk-up > source-baked default > error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

scratch="$(mktemp -d)"
scratch="$(cd "$scratch" && pwd -P)"  # canonicalise; macOS /var → /private/var
# shellcheck disable=SC2064 # expand $scratch now: the canonical path is captured at trap-install time and must not depend on runtime state.
trap "rm -rf '$scratch'" EXIT

# Helpers --------------------------------------------------------------
mkwb() {                           # mkwb <path>
  local p="$1"
  mkdir -p "$p/scripts" "$p/.workbench-state"
  : > "$p/project.conf"
  # Stub a sentinel script reachable through the resolver.
  cat > "$p/scripts/sync-context.sh" <<'SH'
#!/usr/bin/env bash
echo "SENTINEL_RAN wb=$WB_ROOT args=$*"
SH
  chmod +x "$p/scripts/sync-context.sh"
}

# A canonical wb at /scratch/wb-a, B at /scratch/wb-b, plus a deep subdir under A.
WB_A="$scratch/wb-a"
WB_B="$scratch/wb-b"
mkwb "$WB_A"
mkwb "$WB_B"
mkdir -p "$WB_A/repos/svc/src"

# Nested wb-inside-wb (pathological): wb-inner under wb-a/sub.
WB_INNER="$WB_A/sub/wb-inner"
mkwb "$WB_INNER"

# Symlink pointing at WB_A.
ln -s "$WB_A" "$scratch/wb-a-symlink"

# Empty dir for "outside any wb" case.
OUTSIDE="$scratch/outside"
mkdir -p "$OUTSIDE"

# Run a snippet inside a sourced aliases.sh shell.
# Args: <pre-source env vars> <body>
# Note: we deliberately use bash -c rather than subshell `(...)` because
# _wb_resolve_root sets _WB_RESOLVED_VIA in its caller's scope and we want
# a clean shell per case.
run_case() {
  local label="$1"; shift
  local body="$*"
  local out rc
  set +e
  out=$(bash -c "
    set -uo pipefail
    source '$REPO_ROOT/aliases.sh'
    $body
  " 2>&1)
  rc=$?
  set -e
  printf '%s' "$out"
  return $rc
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  case "$haystack" in
    *"$needle"*) echo "  ✓ $label" ;;
    *) echo "  ✗ $label"; echo "    expected substring: $needle"; echo "    got: $haystack"; exit 1 ;;
  esac
}

assert_eq() {
  local label="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "  ✓ $label"
  else
    echo "  ✗ $label"; echo "    want: $want"; echo "    got:  $got"; exit 1
  fi
}

assert_fails() {
  local label="$1" body="$2" needle="$3"
  local out rc
  out=$(bash -c "
    set -uo pipefail
    source '$REPO_ROOT/aliases.sh'
    $body
  " 2>&1) && rc=0 || rc=$?
  if (( rc == 0 )); then
    echo "  ✗ $label (expected non-zero exit, got 0)"; echo "    out: $out"; exit 1
  fi
  case "$out" in
    *"$needle"*) echo "  ✓ $label" ;;
    *) echo "  ✗ $label"; echo "    expected substring: $needle"; echo "    got: $out"; exit 1 ;;
  esac
}

echo "-- test-wb-resolve-root.sh --"

# 1. WB_PIN valid → resolves to pin path, via=pin
out=$(run_case pin-valid "
  export WB_PIN='$WB_A'
  _wb_resolve_root
  echo \"path=\$__WB_ROOT_OUT via=\$_WB_RESOLVED_VIA\"
")
assert_contains "pin valid resolves to pin" "$out" "path=$WB_A via=pin"

# 2. WB_PIN invalid → loud error, exit 1, no fallback
assert_fails "pin invalid errors loudly" "
  export WB_PIN='$scratch/no-such-wb'
  _wb_resolve_root
" "is not a workbench"

# 3. cwd inside wb → resolves via cwd
out=$(run_case cwd-direct "
  cd '$WB_A'
  _wb_resolve_root
  echo \"path=\$__WB_ROOT_OUT via=\$_WB_RESOLVED_VIA\"
")
assert_contains "cwd at wb root resolves via cwd" "$out" "path=$WB_A via=cwd"

# 4. cwd deep inside wb subtree → walks up
out=$(run_case cwd-deep "
  cd '$WB_A/repos/svc/src'
  _wb_resolve_root
  echo \"path=\$__WB_ROOT_OUT via=\$_WB_RESOLVED_VIA\"
")
assert_contains "cwd deep walks up to wb root" "$out" "path=$WB_A via=cwd"

# 5. Nested wb-inside-wb → innermost wins
out=$(run_case cwd-nested "
  cd '$WB_INNER'
  _wb_resolve_root
  echo \"path=\$__WB_ROOT_OUT via=\$_WB_RESOLVED_VIA\"
")
assert_contains "nested wb: innermost wins" "$out" "path=$WB_INNER via=cwd"

# 6. cwd outside any wb, source default points at template-dev clone with no
#    project.conf → falls through to error case 7. So we copy the resolver
#    into a fake wb dir and source it from there to simulate single-wb users
#    whose aliases.sh sits next to a project.conf.
FAKE_DEFAULT_WB="$scratch/default-wb"
mkwb "$FAKE_DEFAULT_WB"
cp "$REPO_ROOT/aliases.sh" "$FAKE_DEFAULT_WB/aliases.sh"

out=$(bash -c "
  set -uo pipefail
  source '$FAKE_DEFAULT_WB/aliases.sh'
  cd '$OUTSIDE'
  _wb_resolve_root
  echo \"path=\$__WB_ROOT_OUT via=\$_WB_RESOLVED_VIA\"
" 2>&1) || true
assert_contains "outside wb, default valid → via=default" "$out" "path=$FAKE_DEFAULT_WB via=default"

# 7. cwd outside any wb, default invalid (template-dev clone) → error w/ hint
assert_fails "no pin, no cwd-wb, no valid default → error" "
  cd '$OUTSIDE'
  _wb_resolve_root
" "not inside a workbench tree"

# 8. Symlinked wb path canonicalises via pwd -P
out=$(run_case cwd-symlink "
  cd '$scratch/wb-a-symlink'
  _wb_resolve_root
  echo \"path=\$__WB_ROOT_OUT via=\$_WB_RESOLVED_VIA\"
")
assert_contains "symlinked path canonicalises" "$out" "path=$WB_A via=cwd"

# 9. wb.switch <good-path> exports WB_PIN, wb.where reports pin
out=$(run_case switch-good "
  cd '$OUTSIDE'
  wb.switch '$WB_B' >/dev/null
  wb.where
")
assert_contains "wb.switch good path then wb.where prints pin" "$out" "$WB_B"
assert_contains "wb.where reports via=pin" "$out" "via pin"

# 10. wb.switch <dir-but-no-project.conf> fails, leaves WB_PIN unset
NOT_WB="$scratch/not-a-wb"
mkdir -p "$NOT_WB"
assert_fails "wb.switch on directory without project.conf errors" "
  cd '$OUTSIDE'
  wb.switch '$NOT_WB'
" "is not a workbench"

assert_fails "wb.switch on missing path errors" "
  cd '$OUTSIDE'
  wb.switch '$scratch/no-such-wb'
" "is not a directory"

out=$(run_case switch-bad-leaves-unpinned "
  cd '$OUTSIDE'
  wb.switch '$NOT_WB' 2>/dev/null || true
  echo \"pin=[\${WB_PIN:-}]\"
")
assert_contains "failed wb.switch leaves WB_PIN unset" "$out" "pin=[]"

# 11. wb.unswitch clears WB_PIN
out=$(run_case unswitch "
  export WB_PIN='$WB_A'
  wb.unswitch >/dev/null
  echo \"pin=[\${WB_PIN:-}]\"
")
assert_contains "wb.unswitch clears WB_PIN" "$out" "pin=[]"

# 12. Pin beats cwd: cwd is wb-a, pin is wb-b → resolver picks wb-b
out=$(run_case pin-beats-cwd "
  export WB_PIN='$WB_B'
  cd '$WB_A'
  _wb_resolve_root
  echo \"path=\$__WB_ROOT_OUT via=\$_WB_RESOLVED_VIA\"
")
assert_contains "pin overrides cwd" "$out" "path=$WB_B via=pin"

# 13. End-to-end via wrapped fn: cwd=wb-b, call wb.sync-context, sentinel sees wb-b
out=$(run_case e2e-cwd "
  cd '$WB_B'
  wb.sync-context probe
")
assert_contains "wrapped wb.sync-context targets cwd-resolved wb" "$out" "SENTINEL_RAN wb=$WB_B args=probe"

# 14. End-to-end via pin: cwd=outside, pin=wb-a, sentinel sees wb-a
out=$(run_case e2e-pin "
  cd '$OUTSIDE'
  export WB_PIN='$WB_A'
  wb.sync-context probe
")
assert_contains "wrapped wb.sync-context targets WB_PIN-resolved wb" "$out" "SENTINEL_RAN wb=$WB_A args=probe"

echo "PASS: test-wb-resolve-root.sh"
