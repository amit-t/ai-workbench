#!/usr/bin/env bash
# test-wtd.sh — Standalone test for scripts/wtd.py (the /wtd skill engine).
#
# Covers the per-epic precondition walk:
#   1. Misconfigured workbench (no EPICS) → priority-5 misconfig recommendation.
#   2. Epic in scope, no epic-context → /epic-intake.
#   3. Epic-context published, not approved → wb.approve.
#   4. Epic-context approved, no PRD → /prd-draft.
#   5. PRD approved, missing eng-spec → /eng-spec.
#   6. PRD + spec + tdd + bdd + test-cases + test-spec approved, no fix_plan
#      → /ralph-workspace-plan.
#   7. Same as 6 but fix_plan exists → wb.ralph-dispatch.
#   8. --json mode emits valid JSON with the expected schema.
#   9. Frontmatter-linked downstream artifact (epic_id + prd_id fields) is
#      recognised against the right PRD.
#
# No network. Self-contained. Bash for portability (matches sibling tests).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WTD="$WB_ROOT/scripts/wtd.py"

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*" >&2; exit 1; }

echo "-- wtd test --"

[[ -f "$WTD" ]] || fail "scripts/wtd.py not found at $WTD"

SCRATCH="$(mktemp -d -t wtd.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

# ── Fixture helpers ──────────────────────────────────────────────────────────
mk_wb() {
  local dir="$SCRATCH/$1"
  mkdir -p "$dir/.workbench-state" \
           "$dir/product/context-library/epics" \
           "$dir/product/outputs/prds" \
           "$dir/engineering/outputs/specs" \
           "$dir/engineering/outputs/tdd" \
           "$dir/qa/outputs/bdd" \
           "$dir/qa/outputs/test-cases" \
           "$dir/qa/outputs/test-spec"
  cat > "$dir/project.conf" <<'EOF'
WORKBENCH_LABEL="wtd-test"
EPICS=(EPIC-001)
REPOS=("name=svc;url=git@example/svc.git;role=service")
EOF
  echo '{"items": []}' > "$dir/.workbench-state/approved.json"
  echo '{"items": []}' > "$dir/.workbench-state/published.json"
  echo '{"items": []}' > "$dir/.workbench-state/rejected.json"
  echo "$dir"
}

write_artifact() {
  # write_artifact <wb> <relpath> <id> <status> [front extra]
  local wb="$1" rel="$2" id="$3" status="$4" extra="${5:-}"
  mkdir -p "$(dirname "$wb/$rel")"
  cat > "$wb/$rel" <<EOF
---
id: $id
status: $status
target_repos: [svc]
$extra
---

# $id

body
EOF
}

ledger_add() {
  # ledger_add <wb> <stage> <id> <type> <relpath>
  local wb="$1" stage="$2" id="$3" type="$4" path="$5"
  python3 - <<PYEOF
import json, pathlib
p = pathlib.Path("$wb/.workbench-state/$stage.json")
data = json.loads(p.read_text()) if p.exists() else {"items": []}
data["items"].append({"id": "$id", "type": "$type", "path": "$path"})
p.write_text(json.dumps(data, indent=2))
PYEOF
}

run_wtd() {
  python3 "$WTD" --root "$1" "${@:2}"
}

# ── 1. No EPICS → misconfig ─────────────────────────────────────────────────
WB="$(mk_wb wb1)"
sed -i.bak 's/^EPICS=.*/EPICS=()/' "$WB/project.conf"; rm -f "$WB/project.conf.bak"
out="$(run_wtd "$WB")"
echo "$out" | grep -q "No epics in scope" || fail "(1) expected misconfig hint, got:\n$out"
pass "(1) empty EPICS surfaces misconfig recommendation"

# ── 2. No epic-context → /epic-intake ────────────────────────────────────────
WB="$(mk_wb wb2)"
out="$(run_wtd "$WB")"
echo "$out" | grep -q "/epic-intake EPIC-001" || fail "(2) expected /epic-intake, got:\n$out"
echo "$out" | grep -q "⛔" || fail "(2) expected blocker marker, got:\n$out"
pass "(2) missing epic-context recommends /epic-intake as blocker"

# ── 3. Epic-context published, not approved → wb.approve ─────────────────────
WB="$(mk_wb wb3)"
write_artifact "$WB" "product/context-library/epics/EPIC-001.md" "epic-EPIC-001" "published"
ledger_add "$WB" "published" "epic-EPIC-001" "epic-context" "product/context-library/epics/EPIC-001.md"
out="$(run_wtd "$WB")"
echo "$out" | grep -q "wb.approve epic-EPIC-001" || fail "(3) expected wb.approve, got:\n$out"
pass "(3) published epic-context recommends wb.approve"

# ── 4. Epic-context approved, no PRD → /prd-draft ────────────────────────────
WB="$(mk_wb wb4)"
write_artifact "$WB" "product/context-library/epics/EPIC-001.md" "epic-EPIC-001" "approved"
ledger_add "$WB" "approved" "epic-EPIC-001" "epic-context" "product/context-library/epics/EPIC-001.md"
out="$(run_wtd "$WB")"
echo "$out" | grep -q "/prd-draft EPIC-001" || fail "(4) expected /prd-draft, got:\n$out"
pass "(4) approved epic with no PRD recommends /prd-draft"

# ── 5. PRD approved, missing eng-spec → /eng-spec ────────────────────────────
WB="$(mk_wb wb5)"
write_artifact "$WB" "product/context-library/epics/EPIC-001.md" "epic-EPIC-001" "approved"
ledger_add "$WB" "approved" "epic-EPIC-001" "epic-context" "product/context-library/epics/EPIC-001.md"
write_artifact "$WB" "product/outputs/prds/EPIC-001-foo.md" "prd-EPIC-001-foo" "approved" "epic_id: EPIC-001"
ledger_add "$WB" "approved" "prd-EPIC-001-foo" "prd" "product/outputs/prds/EPIC-001-foo.md"
out="$(run_wtd "$WB")"
echo "$out" | grep -q "/eng-spec prd-EPIC-001-foo" || fail "(5) expected /eng-spec, got:\n$out"
pass "(5) approved PRD with no eng-spec recommends /eng-spec"

# ── 6. All PRD-scoped artifacts approved, no fix_plan → /ralph-workspace-plan ─
WB="$(mk_wb wb6)"
write_artifact "$WB" "product/context-library/epics/EPIC-001.md" "epic-EPIC-001" "approved"
ledger_add "$WB" "approved" "epic-EPIC-001" "epic-context" "product/context-library/epics/EPIC-001.md"
write_artifact "$WB" "product/outputs/prds/EPIC-001-foo.md" "prd-EPIC-001-foo" "approved" "epic_id: EPIC-001"
ledger_add "$WB" "approved" "prd-EPIC-001-foo" "prd" "product/outputs/prds/EPIC-001-foo.md"
for combo in \
  "engineering/outputs/specs/EPIC-001-foo.md|spec-EPIC-001-foo|eng-spec" \
  "engineering/outputs/tdd/EPIC-001-foo.md|tdd-EPIC-001-foo|tdd" \
  "qa/outputs/bdd/EPIC-001-foo.md|bdd-EPIC-001-foo|bdd" \
  "qa/outputs/test-cases/EPIC-001-foo.md|tcg-EPIC-001-foo|test-cases" \
  "qa/outputs/test-spec/EPIC-001-foo.md|test-spec-EPIC-001-foo|test-spec"
do
  IFS='|' read -r path id type <<< "$combo"
  write_artifact "$WB" "$path" "$id" "approved" "prd_id: prd-EPIC-001-foo"
  ledger_add "$WB" "approved" "$id" "$type" "$path"
done
out="$(run_wtd "$WB")"
echo "$out" | grep -q "/ralph-workspace-plan" || fail "(6) expected /ralph-workspace-plan, got:\n$out"
pass "(6) all artifacts approved + no fix_plan recommends /ralph-workspace-plan"

# ── 7. fix_plan present → wb.ralph-dispatch ──────────────────────────────────
mkdir -p "$WB/repos/.ralph"
echo "# stub fix plan" > "$WB/repos/.ralph/fix_plan.md"
out="$(run_wtd "$WB")"
echo "$out" | grep -q "wb.ralph-dispatch" || fail "(7) expected wb.ralph-dispatch, got:\n$out"
pass "(7) fix_plan present recommends wb.ralph-dispatch"

# ── 8. --json mode produces valid JSON ───────────────────────────────────────
json="$(run_wtd "$WB" --json)"
python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert 'recommendations' in d; assert isinstance(d['recommendations'], list); assert d['recommendations'], 'empty recs'" <<< "$json" \
  || fail "(8) --json produced invalid or empty payload:\n$json"
pass "(8) --json mode emits valid recommendations payload"

# ── 10. Template-dev detection (no project.conf + SESSION-HANDOFF present) ───
TD="$SCRATCH/template-dev"
mkdir -p "$TD/.workbench-state"
touch "$TD/SESSION-HANDOFF.md"
if python3 "$WTD" --root "$TD" 2>/dev/null; then
  fail "(10) expected non-zero exit for template-dev detection"
fi
err="$(python3 "$WTD" --root "$TD" 2>&1 1>/dev/null || true)"
echo "$err" | grep -q "template repo" || fail "(10) expected template-dev hint, got:\n$err"
pass "(10) template-dev repo (no project.conf + SESSION-HANDOFF) exits 2 with hint"

# ── 11. Multi-epic — priorities sort across epics ────────────────────────────
WB="$(mk_wb wb11)"
# Two epics: one missing context (P10 blocker), one approved with PRD (P15).
sed -i.bak 's/^EPICS=.*/EPICS=(EPIC-001 EPIC-002)/' "$WB/project.conf"; rm -f "$WB/project.conf.bak"
write_artifact "$WB" "product/context-library/epics/EPIC-002.md" "epic-EPIC-002" "approved"
ledger_add "$WB" "approved" "epic-EPIC-002" "epic-context" "product/context-library/epics/EPIC-002.md"
out="$(run_wtd "$WB")"
top_cmd="$(echo "$out" | sed -n '5p')"
echo "$top_cmd" | grep -q "/epic-intake EPIC-001" || fail "(11) expected EPIC-001 (P10 blocker) as top, got top line: $top_cmd\nfull:\n$out"
echo "$out" | grep -q "/prd-draft EPIC-002" || fail "(11) expected EPIC-002 in queue, got:\n$out"
pass "(11) multi-epic sort surfaces the highest-priority blocker first"

# ── 9. Frontmatter-linked downstream resolves against right PRD ──────────────
WB="$(mk_wb wb9)"
write_artifact "$WB" "product/context-library/epics/EPIC-001.md" "epic-EPIC-001" "approved"
ledger_add "$WB" "approved" "epic-EPIC-001" "epic-context" "product/context-library/epics/EPIC-001.md"
# Use unconventional ID — only frontmatter prd_id links it back.
write_artifact "$WB" "product/outputs/prds/EPIC-001-foo.md" "prd-EPIC-001-foo" "approved" "epic_id: EPIC-001"
ledger_add "$WB" "approved" "prd-EPIC-001-foo" "prd" "product/outputs/prds/EPIC-001-foo.md"
write_artifact "$WB" "engineering/outputs/specs/EPIC-001-foo.md" "weird-spec-id-xyz" "approved" "prd_id: prd-EPIC-001-foo"
ledger_add "$WB" "approved" "weird-spec-id-xyz" "eng-spec" "engineering/outputs/specs/EPIC-001-foo.md"
out="$(run_wtd "$WB")"
echo "$out" | grep -q "/tdd prd-EPIC-001-foo" || fail "(9) expected /tdd as next after spec (linked via frontmatter), got:\n$out"
pass "(9) frontmatter-linked spec correctly closes the eng-spec gate"

echo
echo "-- all wtd tests passed --"
