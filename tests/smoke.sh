#!/usr/bin/env bash
# smoke.sh — Local end-to-end smoke of a stamped workbench, three-stage lifecycle.
#
# Flow:
#   1. Stamp template into temp dir.
#   2. Render project.conf + EPIC-PIPELINE.md + CODEOWNERS from templates.
#   3. Create two synthetic code repos under repos/.
#   4. register-repo idempotency check.
#   5. Seed a draft PRD, SPEC, test-cases. Verify sync-context fails (no approved.json present
#      initially) or copies nothing (if approved.json is present but empty).
#   6. wb.publish each artifact; verify published.json grows and frontmatter flips.
#   7. Attempt wb.approve of a non-existent id; expect failure.
#   8. wb.approve each; verify approved.json grows and published.json drains.
#   9. Run sync-context; verify role-filtered routing into repos/*/ai/.
#  10. wb.reject a fresh artifact; verify it returns to draft.
#
# No network. No GitHub.
#
# Usage:
#   ./tests/smoke.sh            # run all
#   ./tests/smoke.sh --keep     # keep tmp dir on success for inspection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

KEEP=false
for a in "$@"; do [[ "$a" == "--keep" ]] && KEEP=true; done

TMP="$(mktemp -d -t wb-smoke.XXXXXX)"
cleanup() { [[ "$KEEP" == "false" ]] && rm -rf "$TMP" || echo "kept: $TMP"; }
trap cleanup EXIT

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "-- smoke test at $TMP --"

# 1. Stamp template
rsync -a --exclude 'tests' --exclude '.git' --exclude 'node_modules' \
  "$TEMPLATE_ROOT/" "$TMP/wb-smoke/"
cd "$TMP/wb-smoke"

# 2. Render templates
python3 - <<'PYEOF'
import pathlib
root = pathlib.Path(".")
tmpl = root / "project.conf.template"
out  = root / "project.conf"
content = tmpl.read_text()
subs = {
    "{{LABEL}}": "smoke",
    "{{REPO_URL}}": "https://example.invalid/org/wb-smoke",
    "{{TEMPLATE_UPSTREAM_URL}}": "https://example.invalid/org/ai-workbench",
    "{{CREATED_BY}}": "smoke-user",
    "{{CREATED_AT}}": "2026-04-23",
    "{{ORG}}": "smoke-org",
    "{{EPICS_BASH_ARRAY}}": '"EPIC-TEST-001"',
    "{{REPOS_BASH_ENTRIES}}":
        '  "name=svc-a;url=https://example.invalid/org/svc-a;role=service;stack=node;added_by=smoke-user"\n'
        '  "name=automation-tests;url=https://example.invalid/org/automation-tests;role=automation-tests;stack=playwright;added_by=smoke-user"',
}
for k, v in subs.items(): content = content.replace(k, v)
out.write_text(content)

pipe_tmpl = (root / "EPIC-PIPELINE.md.template").read_text()
pipe = pipe_tmpl
for k,v in [("{{LABEL}}","smoke"),("{{CREATED_AT}}","2026-04-23"),("{{CREATED_BY}}","smoke-user")]:
    pipe = pipe.replace(k, v)
pipe = pipe.replace("{{EPIC_SECTIONS}}",
    "## EPIC EPIC-TEST-001 — Smoke\nStatus: draft\nJira: https://example.invalid/browse/EPIC-TEST-001\nContext: product/context-library/epics/EPIC-TEST-001.md\n\n### PRDs\n| PRD | Status |\n|-----|--------|\n\n### Notes\n-\n")
(root / "EPIC-PIPELINE.md").write_text(pipe)

co = (root / ".github" / "CODEOWNERS").read_text()
co = co.replace("{{INITIATOR_GH_USER}}", "smoke-user").replace("{{ORG}}", "smoke-org")
(root / ".github" / "CODEOWNERS").write_text(co)
PYEOF
pass "templates rendered"

# 3. Synthetic code repos
for r in svc-a automation-tests; do
  mkdir -p "repos/$r"
  (cd "repos/$r" && git init -q && echo "repo:$r" > README.md && git add . && git commit -q -m "init")
done
pass "synthetic repos created"

# 4. register-repo idempotent
out=$(./scripts/register-repo.sh svc-a https://example.invalid/org/svc-a service node 2>&1 || true)
echo "$out" | grep -q "Already registered" || fail "register-repo not idempotent (got: $out)"
pass "register-repo idempotent"

# 5. Seed drafts (with target_repos — validator requires it at publish/approve)
mkdir -p product/outputs/prds engineering/outputs/specs

cat > product/outputs/prds/PRD-001-smoke.md <<'EOF'
---
id: PRD-001
status: draft
target_repos: [svc-a, automation-tests]
---
# PRD-001 Smoke
EOF

cat > engineering/outputs/specs/SPEC-001-smoke.md <<'EOF'
---
id: SPEC-001
status: draft
target_repos: [svc-a]
---
# SPEC-001 Smoke
EOF

mkdir -p qa/outputs/test-cases qa/outputs/bdd
cat > qa/outputs/test-cases/PRD-001-smoke-cases.md <<'EOF'
---
id: TC-set-001
status: draft
target_repos: [automation-tests]
---
# Test cases for PRD-001 (smoke)

| TC ID | Title | Priority |
|-------|-------|----------|
| TC-001 | smoke happy path | P0 |
EOF

cat > qa/outputs/bdd/PRD-001-smoke.feature <<'EOF'
# id: BDD-001
# status: draft
# epic: EPIC-TEST-001
# prd: PRD-001
# target_repos: [automation-tests]

@epic-EPIC-TEST-001 @prd-PRD-001
Feature: Smoke
  Scenario: happy path
    Given a smoke test
    When it runs
    Then it passes
EOF

# Ensure state files exist (empty) — the template ships them empty
cat > .workbench-state/approved.json <<'EOF'
{ "items": [] }
EOF
cat > .workbench-state/published.json <<'EOF'
{ "items": [] }
EOF
cat > .workbench-state/rejected.json <<'EOF'
{ "items": [] }
EOF

# Run sync-context — nothing should copy (empty approved.json)
./scripts/sync-context.sh >/dev/null
[[ ! -e repos/svc-a/ai/outputs/prds/PRD-001-smoke.md ]] || fail "sync-context leaked an unapproved artifact"
pass "sync-context with empty approved.json leaks nothing"

# 6. wb.publish each artifact
source aliases.sh
wb.publish PRD-001    product/outputs/prds/PRD-001-smoke.md         prd        >/dev/null
wb.publish SPEC-001   engineering/outputs/specs/SPEC-001-smoke.md   eng-spec   >/dev/null
wb.publish TC-set-001 qa/outputs/test-cases/PRD-001-smoke-cases.md  test-cases >/dev/null
wb.publish BDD-001    qa/outputs/bdd/PRD-001-smoke.feature          bdd        >/dev/null

pub_count=$(python3 -c "import json; print(len(json.load(open('.workbench-state/published.json'))['items']))")
[[ "$pub_count" == "4" ]] || fail "expected 4 published, got $pub_count"
grep -q '^status: published' product/outputs/prds/PRD-001-smoke.md || fail "PRD frontmatter not flipped"
grep -q '^# status: published' qa/outputs/bdd/PRD-001-smoke.feature || fail "BDD feature header not flipped"
pass "four artifacts published (incl. BDD .feature)"

# 7. Attempting wb.approve of non-existent id fails
if wb.approve NOPE 2>/dev/null; then fail "wb.approve of unknown id should fail"; fi
pass "wb.approve refuses unknown id"

# 8. Approve all four
wb.approve PRD-001    >/dev/null
wb.approve SPEC-001   >/dev/null
wb.approve TC-set-001 >/dev/null
wb.approve BDD-001    >/dev/null

app_count=$(python3 -c "import json; print(len(json.load(open('.workbench-state/approved.json'))['items']))")
pub_count=$(python3 -c "import json; print(len(json.load(open('.workbench-state/published.json'))['items']))")
[[ "$app_count" == "4" ]] || fail "expected 4 approved, got $app_count"
[[ "$pub_count" == "0" ]] || fail "expected 0 published after approval, got $pub_count"
grep -q '^status: approved'   product/outputs/prds/PRD-001-smoke.md || fail "PRD frontmatter not approved"
grep -q '^# status: approved' qa/outputs/bdd/PRD-001-smoke.feature  || fail "BDD feature header not approved"
pass "all four approved; published drained"

# 9. sync-context routes correctly
./scripts/sync-context.sh >/dev/null
[[ -f repos/svc-a/ai/outputs/prds/PRD-001-smoke.md ]]                            || fail "svc-a missing PRD"
[[ -f repos/svc-a/ai/outputs/specs/SPEC-001-smoke.md ]]                          || fail "svc-a missing SPEC"
[[ ! -f repos/svc-a/ai/outputs/test-cases/PRD-001-smoke-cases.md ]]              || fail "svc-a should not have test-cases"
[[ -f repos/automation-tests/ai/outputs/prds/PRD-001-smoke.md ]]                 || fail "automation missing PRD"
[[ -f repos/automation-tests/ai/outputs/test-cases/PRD-001-smoke-cases.md ]]     || fail "automation missing test-cases"
[[ -f repos/automation-tests/ai/outputs/bdd/PRD-001-smoke.feature ]]             || fail "automation missing BDD feature"
[[ ! -f repos/automation-tests/ai/outputs/specs/SPEC-001-smoke.md ]]             || fail "automation should not have SPEC"
[[ ! -f repos/svc-a/ai/outputs/bdd/PRD-001-smoke.feature ]]                      || fail "svc-a should not have BDD"
pass "sync-context routes by role correctly (incl. BDD)"

# 9b. sync-context copies steering/ and steering.local/ to every repo
[[ -f repos/svc-a/ai/steering/golden-principles/GP-001-artifacts-start-draft.md ]]            || fail "svc-a missing steering/"
[[ -f repos/automation-tests/ai/steering/golden-principles/GP-001-artifacts-start-draft.md ]] || fail "automation missing steering/"
pass "sync-context copies steering to every repo"

# 9c. Steering loader: golden scope emits non-empty merged output
golden_out=$(python3 ./scripts/steering-load.py golden)
[[ -n "$golden_out" ]] || fail "steering-load.py golden emitted nothing"
echo "$golden_out" | grep -q '^## GP-001' || fail "golden output missing GP-001"
pass "steering loader golden scope emits merged rules"

# 9d. Steering loader: overlay round-trip (add, supersede, remove)
mkdir -p steering.local/golden-principles
cat > steering.local/golden-principles/GP-LOCAL-01-smoke-add.md <<'EOF'
---
id: GP-LOCAL-01
title: Smoke-test local addition
scope: golden
owner: smoke-user
created: 2026-04-23
---
**Rule:** Smoke-test local rule body.
EOF
cat > steering.local/golden-principles/GP-LOCAL-02-smoke-super.md <<'EOF'
---
id: GP-LOCAL-02
title: Smoke-test supersede of GP-003
scope: golden
owner: smoke-user
created: 2026-04-23
supersedes: [GP-003]
---
**Rule:** Smoke-test supersede body.
EOF
cat > steering.local/golden-principles/GP-004.removed.md <<'EOF'
---
id: GP-004.removed
removes: [GP-004]
owner: smoke-user
created: 2026-04-23
---
Removed for smoke test.
EOF
overlay_out=$(python3 ./scripts/steering-load.py golden)
echo "$overlay_out" | grep -q '^## GP-LOCAL-01'          || fail "overlay add missing"
echo "$overlay_out" | grep -q '^## GP-LOCAL-02'          || fail "overlay supersede missing"
echo "$overlay_out" | grep -q '^## GP-003'               && fail "GP-003 should be superseded out"
echo "$overlay_out" | grep -q '^## GP-004'               && fail "GP-004 should be removed"
pass "overlay round-trip: add + supersede + remove all apply"

# 9e. Steering linter accepts the stamped tree
./scripts/steering-lint.py >/dev/null || fail "steering-lint.py failed on stamped tree"
pass "steering-lint clean on stamped tree"

# 9f. validate-artifact blocks missing target_repos on a routed type
cat > product/outputs/prds/PRD-missing-tr.md <<'EOF'
---
id: PRD-MISSING
status: draft
---
# PRD missing target_repos
EOF
if wb.publish PRD-MISSING product/outputs/prds/PRD-missing-tr.md prd 2>/dev/null; then
  fail "validator should block publish of PRD with no target_repos"
fi
pass "validator blocks missing target_repos at publish"

# 9g. validate-artifact blocks unregistered repo name
cat > product/outputs/prds/PRD-bad-tr.md <<'EOF'
---
id: PRD-BADTR
status: draft
target_repos: [does-not-exist]
---
# PRD with unregistered target_repo
EOF
if wb.publish PRD-BADTR product/outputs/prds/PRD-bad-tr.md prd 2>/dev/null; then
  fail "validator should block publish of PRD with unknown target_repos"
fi
pass "validator blocks unknown target_repos at publish"

# 9h. target_repos filter: sync-context routes PRD-001 only to its listed repos
# (PRD-001 targets both svc-a and automation-tests — already verified in 9).
# SPEC-001 targets only svc-a: must NOT land in shared-lib/infra if ever added.
# TC-set-001 + BDD-001 target only automation-tests — must NOT land in svc-a.
[[ ! -f repos/svc-a/ai/outputs/test-cases/PRD-001-smoke-cases.md ]]  || fail "svc-a got automation-only test-cases (target_repos filter broken)"
[[ ! -f repos/svc-a/ai/outputs/bdd/PRD-001-smoke.feature ]]          || fail "svc-a got automation-only BDD (target_repos filter broken)"
pass "target_repos filter drops artifacts from non-target repos"

# 9i. steering-overlays footer generator emits markdown when overlays present
footer_out=$(python3 ./scripts/steering-overlays.py --footer)
[[ -n "$footer_out" ]]                                       || fail "steering-overlays --footer emitted nothing"
echo "$footer_out" | grep -q "### Steering drift"            || fail "footer missing drift header"
echo "$footer_out" | grep -q "GP-LOCAL-01"                   || fail "footer missing GP-LOCAL-01 ADD entry"
echo "$footer_out" | grep -q "GP-003.*GP-LOCAL-02"           || fail "footer missing supersede entry"
echo "$footer_out" | grep -q "GP-004.*REMOVE"                || fail "footer missing remove entry"
pass "steering-overlays --footer renders add/supersede/remove"

# 9j. sync-context writes pr_footer.md when ralph workspace exists
mkdir -p repos/.ralph
./scripts/sync-context.sh >/dev/null
[[ -s repos/.ralph/pr_footer.md ]]                           || fail "pr_footer.md not written by sync-context"
grep -q "### Steering drift" repos/.ralph/pr_footer.md       || fail "pr_footer.md missing drift header"
pass "sync-context writes pr_footer.md when repos/.ralph/ exists"

# 9k. wb.ralph-plan --dry-run with workspace mode reports the workspace command
# Mock ralph-plan so --help reports --workspace support. Also mock ralph itself.
MOCK_BIN="$TMP/mockbin"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/ralph-plan" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--help" ]]; then
  echo "usage: ralph-plan [--workspace] [--engine ENG] [--thinking T]"
  exit 0
fi
echo "mock ralph-plan called with: $*"
exit 0
EOF
cat > "$MOCK_BIN/ralph" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--help" ]]; then
  echo "usage: ralph [--workspace] [--parallel N] [--live] [--monitor] [--engine ENG]"
  exit 0
fi
echo "mock ralph called with: $*"
exit 0
EOF
chmod +x "$MOCK_BIN/ralph-plan" "$MOCK_BIN/ralph"
export PATH="$MOCK_BIN:$PATH"

mkdir -p repos/.ralph
touch repos/.ralphrc
echo "WORKSPACE_MODE=true" > repos/.ralphrc

plan_out=$(./scripts/ralph-plan.sh --dry-run 2>&1)
echo "$plan_out" | grep -q 'mode=workspace'                                   || fail "ralph-plan did not default to workspace: $plan_out"
echo "$plan_out" | grep -q 'ralph-plan --workspace --engine devin'            || fail "ralph-plan dry-run missing expected command: $plan_out"
pass "wb.ralph-plan --dry-run picks workspace mode by default"

# 9l. --mode per-repo override respected
plan_out=$(./scripts/ralph-plan.sh --dry-run --mode per-repo 2>&1)
echo "$plan_out" | grep -q 'mode=per-repo'                                    || fail "ralph-plan --mode per-repo not honored"
pass "wb.ralph-plan --mode per-repo override works"

# 9m. wb.ralph-dispatch --dry-run invokes ralph --workspace --parallel N
dispatch_out=$(./scripts/ralph-dispatch.sh --dry-run 2>&1)
echo "$dispatch_out" | grep -q 'ralph --workspace --parallel'                 || fail "dispatch dry-run missing --workspace --parallel: $dispatch_out"
echo "$dispatch_out" | grep -q "WORKSPACE_ROOT=$(pwd)/repos"                  || fail "dispatch dry-run missing WORKSPACE_ROOT export: $dispatch_out"
pass "wb.ralph-dispatch --dry-run invokes workspace with parallel and WORKSPACE_ROOT"

# 9n. ralph-enable-check preflight refuses when .ralph missing
rm -rf repos/.ralph repos/.ralphrc
if ./scripts/ralph-plan.sh --dry-run 2>/dev/null; then
  fail "ralph-plan should refuse when ralph workspace is not enabled"
fi
pass "ralph-enable-check blocks ralph-plan when workspace not enabled"

# 10. wb.reject round-trip
cat > product/outputs/prds/PRD-002-reject.md <<'EOF'
---
id: PRD-002
status: draft
target_repos: [svc-a]
---
# PRD-002 to be rejected
EOF
wb.publish PRD-002 product/outputs/prds/PRD-002-reject.md prd >/dev/null
wb.reject PRD-002 "test reason" >/dev/null
rej_count=$(python3 -c "import json; print(len(json.load(open('.workbench-state/rejected.json'))['items']))")
[[ "$rej_count" == "1" ]] || fail "expected 1 rejected, got $rej_count"
grep -q '^status: draft' product/outputs/prds/PRD-002-reject.md || fail "rejected artifact not back to draft"
pass "reject round-trip works"

echo ""
echo "-- smoke test PASSED --"
