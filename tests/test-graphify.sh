#!/usr/bin/env bash
# test-graphify.sh — Standalone test for graphify integration.
#
# Covers:
#   1. project.conf.template carries GRAPHIFY_MODE="auto" by default + env note.
#   2. aliases.sh exposes wb.graphify wired to scripts/graphify-repos.sh.
#   3. wb.graphify --check reads project.conf REPOS + reports per-repo status.
#   4. wb.graphify <repo> with WB_GRAPHIFY_CMD mock succeeds → REPOS flag flips.
#   5. wb.graphify <repo> idempotent on already-graphified repo (no-op + msg).
#   6. wb.graphify --all walks every non-graphified repo.
#   7. Missing CLI + no mock → error with pip install hint, exit nonzero.
#   8. wb.graphify --install-skill invokes `graphify install` and writes
#      .agents/skills/graphify/SKILL.md when source SKILL.md available.
#   9. scripts/register-repo.sh appends graphified=false to new entry.
#  10. scripts/register-repo.sh auto-fires wb.graphify when GRAPHIFY_MODE=auto.
#  11. scripts/register-repo.sh recommends only when GRAPHIFY_MODE=manual.
#  12. wb.info reports non-graphified count + names.
#  13. Mode resolution: env > project.conf > default.
#  14. CLAUDE.md + README.md document the integration.
#
# No network. Self-contained. Mocks CLI via WB_GRAPHIFY_CMD test hook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT_TPL="$(cd "$SCRIPT_DIR/.." && pwd)"

# Silence the wb upgrade-notification shim during tests by pointing HOME at a
# scratch path where the shim does not exist (the lib lives under HOME).
export HOME_ORIG="${HOME}"
HOME="$(mktemp -d -t graphify-home.XXXXXX)"
export HOME

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "-- graphify test --"

# 1. project.conf.template default
PCT="$WB_ROOT_TPL/project.conf.template"
[[ -f "$PCT" ]] || fail "project.conf.template missing"
grep -q 'GRAPHIFY_MODE="auto"' "$PCT" || fail "project.conf.template missing GRAPHIFY_MODE=\"auto\""
grep -q 'WB_GRAPHIFY_MODE'      "$PCT" || fail "project.conf.template missing WB_GRAPHIFY_MODE env note"
pass "project.conf.template carries GRAPHIFY_MODE=\"auto\" with env-var note"

# 2. aliases.sh exposes wb.graphify
grep -q '^wb.graphify()' "$WB_ROOT_TPL/aliases.sh" || fail "aliases.sh missing wb.graphify() function"
grep -q 'graphify-repos.sh' "$WB_ROOT_TPL/aliases.sh" || fail "wb.graphify not wired to scripts/graphify-repos.sh"
pass "aliases.sh exposes wb.graphify -> scripts/graphify-repos.sh"

# 3-7,12,13. Stage a minimal stamped wb in a scratch dir for behavioral tests.
SCRATCH="$(mktemp -d -t graphify.XXXXXX)"
trap 'rm -rf "$SCRATCH" "$HOME"' EXIT

stage_wb() {
  local wb="$1"
  local mode="${2:-auto}"
  rm -rf "$wb"
  mkdir -p "$wb/scripts" "$wb/.workbench-state" "$wb/repos" "$wb/.agents/skills" "$wb/.claude/skills"
  cp "$WB_ROOT_TPL/aliases.sh"               "$wb/"
  cp "$WB_ROOT_TPL/scripts/graphify-repos.sh" "$wb/scripts/"
  cp "$WB_ROOT_TPL/scripts/register-repo.sh"  "$wb/scripts/"
  chmod +x "$wb/scripts/"*.sh
  cat > "$wb/project.conf" <<EOF
WORKBENCH_LABEL="graphify-test"
EPICS=()
REPOS=(
  "name=svc-a;url=https://example.invalid/svc-a;role=service;stack=node;added_by=tester;graphified=false"
  "name=svc-b;url=https://example.invalid/svc-b;role=service;stack=node;added_by=tester;graphified=true"
)
GRAPHIFY_MODE="$mode"
EOF
}

run_in_wb() {
  local wb="$1"; shift
  bash -c "cd '$wb' && source ./aliases.sh && $*"
}

WB="$SCRATCH/wb"
stage_wb "$WB"

# 3. --check output
out=$(WB_GRAPHIFY_CMD='echo "mock-ok"' run_in_wb "$WB" 'wb.graphify --check') || fail "--check exited nonzero: $out"
echo "$out" | grep -q 'svc-a'      || fail "--check missing svc-a in output: $out"
echo "$out" | grep -q 'svc-b'      || fail "--check missing svc-b in output: $out"
echo "$out" | grep -qE 'svc-a.*(missing|not graphified|false)' || fail "--check did not flag svc-a non-graphified: $out"
echo "$out" | grep -qE 'svc-b.*(graphified|ok|true)'           || fail "--check did not flag svc-b graphified: $out"
echo "$out" | grep -qE 'GRAPHIFY_MODE.*auto'                   || fail "--check did not show GRAPHIFY_MODE=auto: $out"
pass "wb.graphify --check reports per-repo status + mode"

# 4. Single-repo run with mock CLI flips REPOS entry to graphified=true.
stage_wb "$WB"
mkdir -p "$WB/repos/svc-a"
( cd "$WB/repos/svc-a" && git init -q && git commit -q --allow-empty -m init 2>/dev/null || true )
out=$(WB_GRAPHIFY_CMD='mkdir -p graphify-out && echo "{}" > graphify-out/graph.json && echo "mock done"' \
      run_in_wb "$WB" 'wb.graphify svc-a' 2>&1) \
   || fail "wb.graphify svc-a (mock) failed: $out"
echo "$out" | grep -qE '(svc-a|done|ok|success)' || fail "wb.graphify svc-a produced no progress output: $out"
grep -q 'graphified=true' "$WB/project.conf" || fail "REPOS entry not flipped to graphified=true after success"
grep -E 'name=svc-a' "$WB/project.conf" | grep -q 'graphified=true' || fail "svc-a entry not flipped to graphified=true"
grep -E 'name=svc-b' "$WB/project.conf" | grep -q 'graphified=true' || fail "svc-b entry must remain graphified=true"
pass "wb.graphify <repo> flips REPOS entry to graphified=true on success"

# 5. Idempotence on already-graphified repo.
out=$(WB_GRAPHIFY_CMD='echo "should-not-run"' run_in_wb "$WB" 'wb.graphify svc-a' 2>&1) \
   || fail "wb.graphify svc-a (idempotent) failed: $out"
echo "$out" | grep -qE 'already graphified|skip' || fail "no idempotent message on already-graphified repo: $out"
echo "$out" | grep -q 'should-not-run' && fail "mock CLI ran on already-graphified repo (should skip): $out"
pass "wb.graphify <repo> idempotent on already-graphified repo"

# 6. --all walks non-graphified repos.
stage_wb "$WB"
mkdir -p "$WB/repos/svc-a" "$WB/repos/svc-b"
out=$(WB_GRAPHIFY_CMD='mkdir -p graphify-out && echo "{}" > graphify-out/graph.json && echo "mock"' \
      run_in_wb "$WB" 'wb.graphify --all' 2>&1) \
   || fail "wb.graphify --all failed: $out"
echo "$out" | grep -q 'svc-a' || fail "--all did not process svc-a: $out"
echo "$out" | grep -q 'svc-b' && {
  # svc-b was already graphified — must be skipped or labelled
  echo "$out" | grep -qE 'svc-b.*(already|skip)' || fail "--all did not skip already-graphified svc-b: $out"
}
grep -E 'name=svc-a' "$WB/project.conf" | grep -q 'graphified=true' || fail "svc-a not flipped after --all"
pass "wb.graphify --all processes non-graphified, skips already-graphified"

# 7. Missing CLI + --no-install → error with pip install hint, no auto-pip.
stage_wb "$WB"
mkdir -p "$WB/repos/svc-a"
# Sanitize PATH to strip any installed graphify; --no-install prevents pip
# auto-install from kicking in (and timing out / hitting PyPI in CI).
out=$(bash -c "cd '$WB' && source ./aliases.sh && unset WB_GRAPHIFY_CMD && \
              PATH='/usr/bin:/bin' wb.graphify --no-install svc-a" 2>&1) && {
  fail "wb.graphify with no CLI should exit nonzero; got: $out"
} || true
echo "$out" | grep -qE 'pip install graphifyy|graphify install' \
  || fail "missing-CLI error lacks pip install hint: $out"
pass "wb.graphify --no-install errors with pip install hint when CLI absent"

# 8. --install-skill writes .agents/skills/graphify/SKILL.md when SKILL.md available.
stage_wb "$WB"
# Mock graphify install: write SKILL.md to a temp path then echo path
MOCK_SKILL="$SCRATCH/mock-skill.md"
echo "# graphify SKILL (mock)" > "$MOCK_SKILL"
out=$(WB_GRAPHIFY_CMD="cat '$MOCK_SKILL' > .agents/skills/graphify/SKILL.md; echo installed" \
      run_in_wb "$WB" 'wb.graphify --install-skill' 2>&1) \
   || fail "--install-skill failed: $out"
# Either the mock wrote the file directly or the script copies SKILL.md it sees.
# Acceptance: .agents/skills/graphify/SKILL.md exists post-run.
[[ -f "$WB/.agents/skills/graphify/SKILL.md" ]] \
  || fail "--install-skill did not produce .agents/skills/graphify/SKILL.md"
pass "wb.graphify --install-skill writes .agents/skills/graphify/SKILL.md"

# 9. register-repo.sh appends graphified=false to new entry.
stage_wb "$WB"
# Stub gh so register-repo doesn't fail on `gh api user`.
mkdir -p "$WB/bin"
cat > "$WB/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "api user -q .login" ]] && { echo "tester"; exit 0; }
exit 0
EOF
chmod +x "$WB/bin/gh"
# Use file:// URL pointing at an empty bare repo so `git clone` works offline.
BARE="$SCRATCH/svc-c.git"
git init -q --bare "$BARE"
PATH="$WB/bin:$PATH" WB_GRAPHIFY_MODE=manual \
  bash "$WB/scripts/register-repo.sh" svc-c "file://$BARE" service node >/dev/null \
  || fail "register-repo.sh svc-c (manual) failed"
grep -E 'name=svc-c' "$WB/project.conf" | grep -q 'graphified=false' \
  || fail "register-repo.sh svc-c did not append graphified=false: $(grep svc-c "$WB/project.conf")"
pass "register-repo.sh appends graphified=false to new REPOS entry"

# 10. register-repo.sh auto-fires wb.graphify when GRAPHIFY_MODE=auto.
stage_wb "$WB" auto
mkdir -p "$WB/bin"
cat > "$WB/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "api user -q .login" ]] && { echo "tester"; exit 0; }
exit 0
EOF
chmod +x "$WB/bin/gh"
BARE="$SCRATCH/svc-d.git"
git init -q --bare "$BARE"
# Mock graphify CLI so the auto-fire actually succeeds.
out=$(PATH="$WB/bin:$PATH" \
      WB_GRAPHIFY_CMD='mkdir -p graphify-out && echo "{}" > graphify-out/graph.json && echo mock' \
      bash "$WB/scripts/register-repo.sh" svc-d "file://$BARE" service node 2>&1) \
   || fail "register-repo.sh svc-d (auto) failed: $out"
echo "$out" | grep -qE '(graphify|/graphify)' \
  || fail "register-repo.sh auto did not invoke graphify: $out"
grep -E 'name=svc-d' "$WB/project.conf" | grep -q 'graphified=true' \
  || fail "register-repo.sh auto did not flip svc-d to graphified=true: $(grep svc-d "$WB/project.conf")"
pass "register-repo.sh GRAPHIFY_MODE=auto fires wb.graphify on new repo"

# 11. register-repo.sh recommends only when GRAPHIFY_MODE=manual.
stage_wb "$WB" manual
mkdir -p "$WB/bin"
cat > "$WB/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "api user -q .login" ]] && { echo "tester"; exit 0; }
exit 0
EOF
chmod +x "$WB/bin/gh"
BARE="$SCRATCH/svc-e.git"
git init -q --bare "$BARE"
out=$(PATH="$WB/bin:$PATH" \
      WB_GRAPHIFY_CMD='echo "should-not-run"' \
      bash "$WB/scripts/register-repo.sh" svc-e "file://$BARE" service node 2>&1) \
   || fail "register-repo.sh svc-e (manual) failed: $out"
echo "$out" | grep -q 'should-not-run' && fail "register-repo.sh manual unexpectedly fired wb.graphify: $out"
echo "$out" | grep -qE '(wb\.graphify svc-e|manual|run when ready)' \
  || fail "register-repo.sh manual did not print recommendation: $out"
grep -E 'name=svc-e' "$WB/project.conf" | grep -q 'graphified=false' \
  || fail "svc-e should remain graphified=false under manual mode"
pass "register-repo.sh GRAPHIFY_MODE=manual recommends but does not fire"

# 12. wb.info reports non-graphified count + names.
stage_wb "$WB"
out=$(run_in_wb "$WB" 'wb.info' 2>&1)
echo "$out" | grep -qE 'graphif' || fail "wb.info missing graphify info: $out"
echo "$out" | grep -q 'svc-a'   || fail "wb.info did not list non-graphified svc-a: $out"
pass "wb.info lists non-graphified repos"

# 13. Mode resolution: env > project.conf > default.
stage_wb "$WB" manual
out=$(WB_GRAPHIFY_MODE=auto run_in_wb "$WB" 'wb.graphify --check' 2>&1)
echo "$out" | grep -qE 'GRAPHIFY_MODE.*auto' \
  || fail "env WB_GRAPHIFY_MODE did not override project.conf manual: $out"
echo "$out" | grep -qiE '(env|WB_GRAPHIFY_MODE)' \
  || fail "--check did not annotate env source: $out"
pass "wb.graphify mode resolution honors env > project.conf"

# 14. CLAUDE.md + README.md document the integration.
CLAUDEMD="$WB_ROOT_TPL/CLAUDE.md"
READMEMD="$WB_ROOT_TPL/README.md"
grep -q 'wb.graphify'    "$CLAUDEMD" || fail "CLAUDE.md missing wb.graphify reference"
grep -q 'GRAPHIFY_MODE'  "$CLAUDEMD" || fail "CLAUDE.md missing GRAPHIFY_MODE doc"
grep -q 'wb.graphify'    "$READMEMD" || fail "README.md missing wb.graphify reference"
grep -qE 'graphify|Graphify' "$READMEMD" || fail "README.md missing graphify section heading"
pass "CLAUDE.md + README.md document graphify integration"

echo ""
echo "-- graphify test PASSED --"
