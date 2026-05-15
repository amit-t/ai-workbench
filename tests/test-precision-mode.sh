#!/usr/bin/env bash
# test-precision-mode.sh — Standalone test for Phase 3 precision plumbing.
#
# Covers:
#   1. project.conf.template carries PRECISION_MODE="on" by default.
#   2. wb.precision resolves env > project.conf > default and prints source.
#   3. precision-mode skill is installed (.agents/.claude/.windsurf + skills-lock).
#   4. validate-artifact.py accepts/rejects precision_mode field shape.
#   5. All 9 host SKILL.md files contain Step 0.5 + precision_mode frontmatter.
#   6. AGENTS.md + CLAUDE.md mention precision plumbing.
#   7. prd-review-panel + design-review carry P3 info hint.
#
# No network. Self-contained.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "-- precision-mode test --"

# 1. project.conf.template default
PCT="$WB_ROOT/project.conf.template"
[[ -f "$PCT" ]] || fail "project.conf.template missing"
grep -q 'PRECISION_MODE="on"' "$PCT" || fail "project.conf.template missing PRECISION_MODE=\"on\""
grep -q 'WB_PRECISION_MODE'    "$PCT" || fail "project.conf.template missing WB_PRECISION_MODE env note"
pass "project.conf.template carries PRECISION_MODE=\"on\" with env-var note"

# 2. wb.precision alias resolution order
# Stage a minimal stamped wb in a temp dir; source aliases and exercise.
SCRATCH="$(mktemp -d -t precision.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

mkdir -p "$SCRATCH/wb/scripts" "$SCRATCH/wb/.workbench-state"
cp "$WB_ROOT/aliases.sh" "$SCRATCH/wb/"
# Minimal project.conf — only the key under test
cat > "$SCRATCH/wb/project.conf" <<'EOF'
LABEL="precision-test"
REPOS=()
PRECISION_MODE="off"
EOF

run_alias() {
  # bash + zsh both work; pick bash for portability
  bash -c "cd '$SCRATCH/wb' && source ./aliases.sh && $1"
}

# 2a. project.conf value picked up
out=$(run_alias 'wb.precision')
echo "$out" | grep -q 'PRECISION_MODE=off'         || fail "wb.precision did not read project.conf value; got: $out"
echo "$out" | grep -q '(project.conf)'             || fail "wb.precision did not label project.conf source; got: $out"
pass "wb.precision reads project.conf PRECISION_MODE"

# 2b. env overrides project.conf
out=$(run_alias 'WB_PRECISION_MODE=on wb.precision')
echo "$out" | grep -q 'PRECISION_MODE=on'          || fail "wb.precision did not honor env override; got: $out"
echo "$out" | grep -q 'env (WB_PRECISION_MODE)'    || fail "wb.precision did not label env source; got: $out"
pass "wb.precision env WB_PRECISION_MODE overrides project.conf"

# 2c. Default when neither set
cat > "$SCRATCH/wb/project.conf" <<'EOF'
LABEL="precision-test-default"
REPOS=()
EOF
out=$(run_alias 'wb.precision')
echo "$out" | grep -q 'PRECISION_MODE=on'          || fail "wb.precision default not 'on'; got: $out"
echo "$out" | grep -q '(default)'                  || fail "wb.precision did not label default source; got: $out"
pass "wb.precision defaults to 'on' when neither env nor project.conf set"

# 3. precision-mode skill installed
[[ -f "$WB_ROOT/.agents/skills/precision-mode/SKILL.md" ]] || fail ".agents/skills/precision-mode/SKILL.md missing"
[[ -L "$WB_ROOT/.claude/skills/precision-mode" ]]          || fail ".claude/skills/precision-mode symlink missing"
[[ -L "$WB_ROOT/.windsurf/skills/precision-mode" ]]        || fail ".windsurf/skills/precision-mode symlink missing"
grep -q '"precision-mode"' "$WB_ROOT/skills-lock.json"     || fail "skills-lock.json missing precision-mode entry"
pass "precision-mode skill installed in .agents + .claude + .windsurf + skills-lock"

# 4. validate-artifact.py precision_mode shape
mkdir -p "$SCRATCH/wb/scripts" "$SCRATCH/wb/product/outputs/prds"
cp "$WB_ROOT/scripts/validate-artifact.py" "$SCRATCH/wb/scripts/"
cp "$WB_ROOT/scripts/artifact-schema.json" "$SCRATCH/wb/scripts/"
cat > "$SCRATCH/wb/project.conf" <<'EOF'
LABEL="precision-test"
REPOS=(
  "name=svc-a;url=https://example.invalid/svc-a;role=service;stack=node"
)
EOF

run_validate() {
  ( cd "$SCRATCH/wb" && WB_ROOT="$SCRATCH/wb" python3 scripts/validate-artifact.py "$1" "$2" )
}

# 4a. precision_mode: on → pass
cat > "$SCRATCH/wb/product/outputs/prds/PRD-100-on.md" <<'EOF'
---
id: PRD-100
status: draft
target_repos: [svc-a]
precision_mode: on
---
# PRD-100
EOF
run_validate product/outputs/prds/PRD-100-on.md prd >/dev/null 2>&1 \
  || fail "validator should accept precision_mode: on"
pass "validator accepts precision_mode: on"

# 4b. precision_mode: off → pass
cat > "$SCRATCH/wb/product/outputs/prds/PRD-101-off.md" <<'EOF'
---
id: PRD-101
status: draft
target_repos: [svc-a]
precision_mode: off
---
# PRD-101
EOF
run_validate product/outputs/prds/PRD-101-off.md prd >/dev/null 2>&1 \
  || fail "validator should accept precision_mode: off"
pass "validator accepts precision_mode: off"

# 4c. precision_mode absent → pass (legacy)
cat > "$SCRATCH/wb/product/outputs/prds/PRD-102-absent.md" <<'EOF'
---
id: PRD-102
status: draft
target_repos: [svc-a]
---
# PRD-102
EOF
run_validate product/outputs/prds/PRD-102-absent.md prd >/dev/null 2>&1 \
  || fail "validator should accept artifact without precision_mode (legacy)"
pass "validator accepts artifact without precision_mode (legacy)"

# 4d. precision_mode: maybe → fail
cat > "$SCRATCH/wb/product/outputs/prds/PRD-103-bad.md" <<'EOF'
---
id: PRD-103
status: draft
target_repos: [svc-a]
precision_mode: maybe
---
# PRD-103
EOF
if run_validate product/outputs/prds/PRD-103-bad.md prd 2>/dev/null; then
  fail "validator should reject precision_mode: maybe"
fi
pass "validator rejects invalid precision_mode value"

# 5. Host lint — 9 SKILL.md files contain Step 0.5 + precision_mode frontmatter
HOSTS=(prd-draft design-draft eng-spec tdd erd adr bdd-gen test-cases-gen test-spec)
for h in "${HOSTS[@]}"; do
  F="$WB_ROOT/skills/$h/SKILL.md"
  [[ -f "$F" ]] || fail "skills/$h/SKILL.md missing"
  grep -q 'Precision check'                "$F" || fail "$h: missing Step 0.5 'Precision check' heading"
  grep -q 'PRECISION_MODE'                 "$F" || fail "$h: missing PRECISION_MODE resolution prose"
  grep -q 'Skill("precision-mode")'        "$F" || fail "$h: missing Skill(\"precision-mode\") invocation"
  grep -q 'precision_mode:'                "$F" || fail "$h: missing precision_mode: frontmatter line"
done
pass "9 host SKILL.md files all carry Step 0.5 + precision_mode frontmatter"

# 5b. Step 0.5 must precede artifact write (positioning sanity)
# For prd-draft: "Precision check" line < "Write `product/outputs/prds" line
F="$WB_ROOT/skills/prd-draft/SKILL.md"
prec_ln=$(grep -n 'Precision check' "$F" | head -1 | cut -d: -f1)
write_ln=$(grep -n 'Write .product/outputs/prds' "$F" | head -1 | cut -d: -f1)
[[ -n "$prec_ln" && -n "$write_ln" ]] || fail "prd-draft: could not find both lines for positioning check"
(( prec_ln < write_ln )) || fail "prd-draft: Step 0.5 ($prec_ln) must precede artifact write ($write_ln)"
pass "Step 0.5 precedes artifact write in prd-draft (positioning sanity)"

# 6. AGENTS.md + CLAUDE.md mention precision plumbing
AGENTS="$WB_ROOT/AGENTS.md"
CLAUDEMD="$WB_ROOT/CLAUDE.md"
grep -q 'precision check'      "$AGENTS"   || fail "AGENTS.md missing precision check paragraph"
grep -q 'precision_mode'       "$AGENTS"   || fail "AGENTS.md missing precision_mode reference"
grep -q 'wb.precision'         "$AGENTS"   || fail "AGENTS.md missing wb.precision reference"
grep -q 'Precision mode'       "$CLAUDEMD" || fail "CLAUDE.md missing 'Precision mode' paragraph"
grep -q 'PRECISION_MODE'       "$CLAUDEMD" || fail "CLAUDE.md missing PRECISION_MODE resolution prose"
grep -q 'wb.precision'         "$CLAUDEMD" || fail "CLAUDE.md missing wb.precision reference"
pass "AGENTS.md + CLAUDE.md document precision plumbing"

# 7. review panels carry the P3 info hint
PRP="$WB_ROOT/skills/prd-review-panel/SKILL.md"
DR="$WB_ROOT/skills/design-review/SKILL.md"
grep -q 'Precision receipt'             "$PRP" || fail "prd-review-panel missing Precision receipt step"
grep -q 'P3 — Authored with'            "$PRP" || fail "prd-review-panel missing P3 hint format"
grep -q 'precision_mode:'               "$PRP" || fail "prd-review-panel missing precision_mode frontmatter read"
grep -q 'Precision receipt'             "$DR"  || fail "design-review missing Precision receipt step"
grep -q 'P3 — Authored with'            "$DR"  || fail "design-review missing P3 hint format"
grep -q 'precision_mode:'               "$DR"  || fail "design-review missing precision_mode frontmatter read"
pass "prd-review-panel + design-review carry P3 precision info hint"

echo ""
echo "-- precision-mode test PASSED --"
