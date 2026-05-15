#!/usr/bin/env bash
# test-grill-substrate.sh — Standalone test for the implicit grill plumbing.
#
# Covers:
#   1. skills/grill-substrate.md is present and has the §1 stance table, §2 scratch-block
#      format, §3 frontmatter schema, §4 host cheat-sheet, §5 lifecycle interaction.
#   2. All 9 host SKILL.md files contain a "Grill pass" step that references
#      `skills/grill-substrate.md` and the Option-B prompt skeleton.
#   3. Host grill step is positioned post-write, pre-"Tell the user"/"Publish prompts"
#      (i.e. Point 2 insertion).
#   4. validate-artifact.py shape-validates the `grilled:` block — accepts well-formed
#      blocks, rejects malformed ones; never rejects on result=skipped/aborted.
#   5. lifecycle.py emits a stderr warning when grilled: is missing or non-resolved;
#      stays silent on all-resolved; never blocks publish.
#   6. prd-review-panel and design-review reference the grill receipt as a P2 finding.
#   7. AGENTS.md + CLAUDE.md mention the grill step + substrate file.
#
# No network. Pure unit-style assertions; uses validate-artifact.py and lifecycle.py
# in temp scratch dirs so the live workbench state is untouched.
#
# Usage:
#   ./tests/test-grill-substrate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "-- grill-substrate test --"

# 1. substrate file present and complete
[[ -f "$WB_ROOT/skills/grill-substrate.md" ]] || fail "skills/grill-substrate.md missing"
SUB="$WB_ROOT/skills/grill-substrate.md"
grep -q '^## 1\. Per-artifact stance'           "$SUB" || fail "substrate missing §1 stance table"
grep -q '^## 2\. Scratch-block format'          "$SUB" || fail "substrate missing §2 scratch-block"
grep -q '^## 3\. .grilled:. frontmatter schema' "$SUB" || fail "substrate missing §3 schema"
grep -q '^## 4\. Host responsibilities'         "$SUB" || fail "substrate missing §4 cheat-sheet"
grep -q '^## 5\. Lifecycle interaction'         "$SUB" || fail "substrate missing §5 lifecycle"
grep -qE '`prd` *\|.*/grill-me'                 "$SUB" || fail "substrate stance row missing prd → grill-me"
grep -qE '`eng-spec` *\|.*/domain-grill'        "$SUB" || fail "substrate stance row missing eng-spec → domain-grill"
pass "skills/grill-substrate.md present with all 5 required sections"

# 2. all 9 host SKILL.md files reference the substrate
HOSTS=(prd-draft design-draft eng-spec tdd erd adr bdd-gen test-cases-gen test-spec)
for h in "${HOSTS[@]}"; do
  F="$WB_ROOT/skills/$h/SKILL.md"
  [[ -f "$F" ]] || fail "skills/$h/SKILL.md missing"
  grep -q 'skills/grill-substrate\.md'    "$F" || fail "$h: missing substrate reference"
  grep -q 'Grill pass'                    "$F" || fail "$h: missing 'Grill pass' step heading"
  grep -q 'Option-B with teeth'           "$F" || fail "$h: missing Option-B prompt label"
  grep -q '\[Y/n/skip-this-session\]'     "$F" || fail "$h: missing [Y/n/skip-this-session] prompt"
  grep -q 'deep|standard|quick'           "$F" || fail "$h: missing depth selector"
done
pass "9 host SKILL.md files all reference grill-substrate.md + Option-B prompt"

# 3. host grill step is positioned before "Tell the user" / "Publish prompts" (Point 2)
# Heuristic: line number of "Grill pass" must be less than line number of "Tell the user" /
# "Publish prompts". Exception for prd-draft / design-draft which use different next-step labels.
for h in prd-draft eng-spec tdd erd adr bdd-gen test-cases-gen test-spec; do
  F="$WB_ROOT/skills/$h/SKILL.md"
  grill_ln=$(grep -n 'Grill pass'   "$F" | head -1 | cut -d: -f1)
  tail_ln=$(grep -n 'Tell the user' "$F" | head -1 | cut -d: -f1)
  [[ -n "$grill_ln" && -n "$tail_ln" ]] || fail "$h: could not find both Grill pass and Tell the user lines"
  (( grill_ln < tail_ln )) || fail "$h: Grill pass at line $grill_ln must precede Tell the user at $tail_ln"
done
F="$WB_ROOT/skills/design-draft/SKILL.md"
grill_ln=$(grep -n 'Grill pass'      "$F" | head -1 | cut -d: -f1)
tail_ln=$(grep -n 'Publish prompts'  "$F" | head -1 | cut -d: -f1)
[[ -n "$grill_ln" && -n "$tail_ln" ]] || fail "design-draft: could not find both Grill pass and Publish prompts lines"
(( grill_ln < tail_ln )) || fail "design-draft: Grill pass at $grill_ln must precede Publish prompts at $tail_ln"
pass "grill step is positioned post-write, pre-next-steps (Point 2 insertion) in all 9 hosts"

# 4. validate-artifact.py shape validation
SCRATCH="$(mktemp -d -t grill-sub.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

# Minimal stamped workbench layout so the validator can read project.conf REPOS.
mkdir -p "$SCRATCH/wb/scripts" "$SCRATCH/wb/product/outputs/prds"
cp "$WB_ROOT/scripts/validate-artifact.py" "$SCRATCH/wb/scripts/"
cp "$WB_ROOT/scripts/artifact-schema.json" "$SCRATCH/wb/scripts/"
cat > "$SCRATCH/wb/project.conf" <<'EOF'
LABEL="grill-test"
REPOS=(
  "name=svc-a;url=https://example.invalid/svc-a;role=service;stack=node"
  "name=automation-tests;url=https://example.invalid/automation-tests;role=automation-tests;stack=playwright"
)
EOF

run_validate() {
  # Args: <relative path inside wb> <type>. Returns the validator's exit code; emits stderr.
  ( cd "$SCRATCH/wb" && WB_ROOT="$SCRATCH/wb" python3 scripts/validate-artifact.py "$1" "$2" )
}

# 4a. Clean grilled block (all resolved) — should pass
cat > "$SCRATCH/wb/product/outputs/prds/PRD-001-ok.md" <<'EOF'
---
id: PRD-001
status: draft
target_repos: [svc-a]
grilled:
  date: 2026-05-14
  depth: standard
  passes:
    - { mode: grill-me, repo: null, result: resolved, open: 0, parked: 0 }
---
# PRD-001
EOF
run_validate product/outputs/prds/PRD-001-ok.md prd >/dev/null 2>&1 \
  || fail "valid grilled block should pass validator"
pass "validator accepts a well-formed grilled: block"

# 4b. Skipped pass — should still pass (B with teeth, never blocks)
cat > "$SCRATCH/wb/product/outputs/prds/PRD-002-skip.md" <<'EOF'
---
id: PRD-002
status: draft
target_repos: [svc-a]
grilled:
  date: 2026-05-14
  depth: null
  passes:
    - { mode: skipped, repo: null, result: skipped, open: 0, parked: 0 }
---
# PRD-002
EOF
run_validate product/outputs/prds/PRD-002-skip.md prd >/dev/null 2>&1 \
  || fail "skipped grilled block must not be rejected"
pass "validator does not reject a skipped grill (B with teeth)"

# 4c. Aborted + parked + multi-pass — should pass
cat > "$SCRATCH/wb/product/outputs/prds/PRD-003-multi.md" <<'EOF'
---
id: PRD-003
status: draft
target_repos: [svc-a, automation-tests]
grilled:
  date: 2026-05-14
  depth: deep
  passes:
    - { mode: domain-grill, repo: svc-a,            result: resolved,        open: 0, parked: 0 }
    - { mode: domain-grill, repo: automation-tests, result: parked-2,        open: 0, parked: 2 }
    - { mode: grill-me,     repo: svc-a,            result: aborted-cascade, open: 0, parked: 0 }
---
# PRD-003
EOF
run_validate product/outputs/prds/PRD-003-multi.md prd >/dev/null 2>&1 \
  || fail "multi-pass grilled block must pass"
pass "validator accepts multi-pass grilled block with parked-N + aborted-cascade"

# 4d. Bad depth — should fail
cat > "$SCRATCH/wb/product/outputs/prds/PRD-004-baddepth.md" <<'EOF'
---
id: PRD-004
status: draft
target_repos: [svc-a]
grilled:
  date: 2026-05-14
  depth: extreme
  passes:
    - { mode: grill-me, repo: null, result: resolved, open: 0, parked: 0 }
---
# PRD-004
EOF
if run_validate product/outputs/prds/PRD-004-baddepth.md prd 2>/dev/null; then
  fail "validator should reject depth='extreme'"
fi
pass "validator rejects invalid grilled.depth"

# 4e. Bad mode — should fail
cat > "$SCRATCH/wb/product/outputs/prds/PRD-005-badmode.md" <<'EOF'
---
id: PRD-005
status: draft
target_repos: [svc-a]
grilled:
  date: 2026-05-14
  depth: standard
  passes:
    - { mode: vibes-check, repo: null, result: resolved, open: 0, parked: 0 }
---
# PRD-005
EOF
if run_validate product/outputs/prds/PRD-005-badmode.md prd 2>/dev/null; then
  fail "validator should reject mode='vibes-check'"
fi
pass "validator rejects invalid grilled.passes[].mode"

# 4f. Bad result — should fail
cat > "$SCRATCH/wb/product/outputs/prds/PRD-006-badres.md" <<'EOF'
---
id: PRD-006
status: draft
target_repos: [svc-a]
grilled:
  date: 2026-05-14
  depth: standard
  passes:
    - { mode: grill-me, repo: null, result: nope, open: 0, parked: 0 }
---
# PRD-006
EOF
if run_validate product/outputs/prds/PRD-006-badres.md prd 2>/dev/null; then
  fail "validator should reject result='nope'"
fi
pass "validator rejects invalid grilled.passes[].result"

# 4g. Missing required pass key — should fail
cat > "$SCRATCH/wb/product/outputs/prds/PRD-007-missingkey.md" <<'EOF'
---
id: PRD-007
status: draft
target_repos: [svc-a]
grilled:
  date: 2026-05-14
  depth: standard
  passes:
    - { mode: grill-me, repo: null, result: resolved, open: 0 }
---
# PRD-007
EOF
if run_validate product/outputs/prds/PRD-007-missingkey.md prd 2>/dev/null; then
  fail "validator should reject missing 'parked' key"
fi
pass "validator rejects pass missing required key"

# 4h. No grilled block at all — should pass (block is optional; warning lives in lifecycle.py)
cat > "$SCRATCH/wb/product/outputs/prds/PRD-008-nogrill.md" <<'EOF'
---
id: PRD-008
status: draft
target_repos: [svc-a]
---
# PRD-008
EOF
run_validate product/outputs/prds/PRD-008-nogrill.md prd >/dev/null 2>&1 \
  || fail "validator must accept artifacts with no grilled: block"
pass "validator accepts artifact without grilled: block (lifecycle warns separately)"

# 5. lifecycle.py grill-warning behaviour
cp "$WB_ROOT/scripts/lifecycle.py" "$SCRATCH/wb/scripts/"
mkdir -p "$SCRATCH/wb/.workbench-state"
cat > "$SCRATCH/wb/.workbench-state/published.json" <<'EOF'
{ "items": [] }
EOF
cat > "$SCRATCH/wb/.workbench-state/approved.json" <<'EOF'
{ "items": [] }
EOF
cat > "$SCRATCH/wb/.workbench-state/rejected.json" <<'EOF'
{ "items": [] }
EOF

run_publish() {
  # Args: <id> <relpath> <type>. Captures both stdout + stderr (cheap, the success
  # line on stdout is harmless and the warning we grep for lives on stderr).
  ( cd "$SCRATCH/wb" && WB_ROOT="$SCRATCH/wb" \
    python3 scripts/lifecycle.py publish "$1" "$2" "$3" 2>&1 )
}

# 5a. Missing grilled: → warning on publish
# Re-seed PRD-008 (already at status: draft above).
warn=$(run_publish PRD-008 product/outputs/prds/PRD-008-nogrill.md prd || true)
echo "$warn" | grep -qE 'no .grilled.* block' \
  || fail "expected 'no grilled block' warning; got: $warn"
pass "wb.publish emits warning when grilled: block is absent"

# Reset state for next test
cat > "$SCRATCH/wb/.workbench-state/published.json" <<'EOF'
{ "items": [] }
EOF
# Flip status back to draft (lifecycle changed it)
python3 -c "
import re, pathlib
p = pathlib.Path('$SCRATCH/wb/product/outputs/prds/PRD-008-nogrill.md')
p.write_text(re.sub(r'^status: \w+', 'status: draft', p.read_text(), count=1, flags=re.M))
"

# 5b. All-resolved grilled: → no warning
warn=$(run_publish PRD-001 product/outputs/prds/PRD-001-ok.md prd || true)
if echo "$warn" | grep -q 'warning:'; then
  fail "expected no warning for all-resolved grill; got: $warn"
fi
pass "wb.publish stays silent when every pass is resolved"

# Reset and flip PRD-003 back to draft
cat > "$SCRATCH/wb/.workbench-state/published.json" <<'EOF'
{ "items": [] }
EOF
python3 -c "
import re, pathlib
p = pathlib.Path('$SCRATCH/wb/product/outputs/prds/PRD-003-multi.md')
p.write_text(re.sub(r'^status: \w+', 'status: draft', p.read_text(), count=1, flags=re.M))
"

# 5c. Multi-pass with non-resolved → warning on publish, publish still succeeds
warn=$(run_publish PRD-003 product/outputs/prds/PRD-003-multi.md prd 2>&1 || true)
echo "$warn" | grep -q 'non-resolved grill passes' \
  || fail "expected 'non-resolved grill passes' warning; got: $warn"
echo "$warn" | grep -qE '(parked-2|aborted-cascade)' \
  || fail "expected warning to mention the offending result(s); got: $warn"
pass "wb.publish emits warning + still succeeds when passes are non-resolved"

# 6. Review panels carry the P2 finding
PRP="$WB_ROOT/skills/prd-review-panel/SKILL.md"
DR="$WB_ROOT/skills/design-review/SKILL.md"
grep -q 'Ungrilled artifact'                "$PRP" || fail "prd-review-panel missing P2 ungrilled finding"
grep -q 'grill_status:'                     "$PRP" || fail "prd-review-panel missing grill_status logic"
grep -q 'Ungrilled artifact'                "$DR"  || fail "design-review missing P2 ungrilled finding"
grep -q 'grill_status:'                     "$DR"  || fail "design-review missing grill_status logic"
pass "prd-review-panel + design-review carry P2 ungrilled finding"

# 7. AGENTS.md + CLAUDE.md reference the grill step + substrate
AGENTS="$WB_ROOT/AGENTS.md"
CLAUDEMD="$WB_ROOT/CLAUDE.md"
grep -q 'grill-substrate'                   "$AGENTS"  || fail "AGENTS.md missing grill-substrate reference"
grep -q 'grilled:'                          "$AGENTS"  || fail "AGENTS.md missing grilled: frontmatter mention"
grep -q 'Grill default'                     "$CLAUDEMD" || fail "CLAUDE.md missing 'Grill default' column"
grep -q 'grill-substrate'                   "$CLAUDEMD" || fail "CLAUDE.md missing grill-substrate reference"
pass "AGENTS.md + CLAUDE.md updated with grill plumbing"

echo ""
echo "-- grill-substrate test PASSED --"
