#!/usr/bin/env bash
# ai-workbench CLI aliases
# Source from a workbench instance:
#   source /path/to/wb-<label>/aliases.sh

WB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# ── Context sync ──────────────────────────────────────────────────────────────
wb.sync-context() { "$WB_ROOT/scripts/sync-context.sh" "$@"; }

# ── Ralph ─────────────────────────────────────────────────────────────────────
wb.ralph-plan()     { "$WB_ROOT/scripts/ralph-plan.sh" "$@"; }
wb.ralph-loop()     { "$WB_ROOT/scripts/ralph-loop.sh" "$@"; }
wb.ralph-dispatch() { "$WB_ROOT/scripts/ralph-dispatch.sh" "$@"; }

# ── Repo management ───────────────────────────────────────────────────────────
wb.register-repo()  { "$WB_ROOT/scripts/register-repo.sh" "$@"; }

# ── Artifact lifecycle ────────────────────────────────────────────────────────
# NOTE: These commands are not concurrency-safe. If two collaborators run
# wb.publish / wb.approve / wb.reject simultaneously on the same workbench,
# last-writer-wins on .workbench-state/*.json. Pull before and push after
# lifecycle transitions. Plan D tracks a proper lock.
#
# Three states: draft → published → approved. Each transition updates YAML
# frontmatter AND the corresponding .workbench-state/*.json file. Only these
# three aliases should ever touch state files.

# wb.publish <artifact-id> <path> <type>
# Moves an artifact from draft to published.
wb.publish() {
  local id="${1:?Usage: wb.publish <artifact-id> <path> <type>}"
  local path="${2:?Usage: wb.publish <artifact-id> <path> <type>}"
  local type="${3:?Usage: wb.publish <artifact-id> <path> <type>}"
  WB_ROOT="$WB_ROOT" AID="$id" APATH="$path" ATYPE="$type" python3 - <<'PYEOF'
import json, os, sys, datetime, re, pathlib
root = os.environ['WB_ROOT']
aid, apath, atype = os.environ['AID'], os.environ['APATH'], os.environ['ATYPE']
state_dir = pathlib.Path(root) / '.workbench-state'
published = state_dir / 'published.json'
approved  = state_dir / 'approved.json'

ALLOWED_TYPES = {"prd","eng-spec","tdd","erd","adr","bdd","test-cases","test-spec","test-erd","epic-context"}
if atype not in ALLOWED_TYPES:
    print(f"Error: unknown type '{atype}'. Must be one of: {sorted(ALLOWED_TYPES)}.", file=sys.stderr)
    sys.exit(1)

def load(p):
    try: return json.loads(p.read_text())
    except FileNotFoundError: return {"items": []}

pub = load(published)
app = load(approved)

if any(i.get('id') == aid for i in app['items']):
    print(f"Error: {aid} is already approved. Nothing to publish.", file=sys.stderr)
    sys.exit(1)

existing = next((i for i in pub['items'] if i.get('id') == aid), None)
if existing and not apath:
    apath = existing.get('path', '')

full = (pathlib.Path(root) / apath).resolve()
root_resolved = pathlib.Path(root).resolve()
try:
    full.relative_to(root_resolved)
except ValueError:
    print(f"Error: path {apath} escapes workbench root.", file=sys.stderr)
    sys.exit(1)
if not full.is_file():
    print(f"Error: artifact file not found. Pass <path> on first publish.", file=sys.stderr)
    sys.exit(1)

text = full.read_text()
new  = re.sub(r'^(status:\s*)(draft|published)\s*$', r'\1published', text, count=1, flags=re.M)
if new == text:
    injected = re.sub(r'(?s)(^---\n)(.*?)(\n---)',
                 lambda m: f"{m.group(1)}{m.group(2)}\nstatus: published{m.group(3)}",
                 text, count=1)
    if injected == text:
        print(f"Error: {apath} has no YAML frontmatter block. Add one with 'status: draft' and retry.", file=sys.stderr)
        sys.exit(1)
    new = injected
full.write_text(new)

if existing:
    existing['path'] = apath
    existing['type'] = atype
    existing['updated_at'] = datetime.datetime.now(datetime.UTC).isoformat()
else:
    pub['items'].append({
        "id": aid, "type": atype, "path": apath,
        "published_by": os.environ.get('USER', 'unknown'),
        "published_at": datetime.datetime.now(datetime.UTC).isoformat(),
    })
published.write_text(json.dumps(pub, indent=2))
print(f"Published: {aid}  ({apath})")
PYEOF
}

# wb.approve <artifact-id>
wb.approve() {
  local id="${1:?Usage: wb.approve <artifact-id>}"
  WB_ROOT="$WB_ROOT" AID="$id" python3 - <<'PYEOF'
import json, os, sys, datetime, re, pathlib
root = os.environ['WB_ROOT']
aid  = os.environ['AID']
state_dir = pathlib.Path(root) / '.workbench-state'
published = state_dir / 'published.json'
approved  = state_dir / 'approved.json'

def load(p):
    try: return json.loads(p.read_text())
    except FileNotFoundError: return {"items": []}

pub = load(published)
app = load(approved)

if any(i.get('id') == aid for i in app['items']):
    print(f"Already approved: {aid}"); sys.exit(0)

entry = next((i for i in pub['items'] if i.get('id') == aid), None)
if not entry:
    print(f"Error: {aid} is not in published state. Run: wb.publish {aid} <path> <type>", file=sys.stderr)
    sys.exit(1)

full = pathlib.Path(root, entry['path'])
text = full.read_text()
new  = re.sub(r'^(status:\s*)(draft|published)\s*$', r'\1approved', text, count=1, flags=re.M)
if new == text:
    print(f"Warning: could not flip frontmatter in {entry['path']} (no 'status: draft|published' line). JSON state updated; file status may be stale.", file=sys.stderr)
full.write_text(new)

entry['approved_by'] = os.environ.get('USER', 'unknown')
entry['approved_at'] = datetime.datetime.now(datetime.UTC).isoformat()
app['items'].append(entry)
pub['items'] = [i for i in pub['items'] if i.get('id') != aid]
published.write_text(json.dumps(pub, indent=2))
approved.write_text(json.dumps(app, indent=2))
print(f"Approved: {aid}  ({entry['path']})")
PYEOF
}

# wb.reject <artifact-id> "<reason>"
wb.reject() {
  local id="${1:?Usage: wb.reject <id> \"<reason>\"}"
  local reason="${2:-no reason given}"
  WB_ROOT="$WB_ROOT" AID="$id" REASON="$reason" python3 - <<'PYEOF'
import json, os, sys, datetime, re, pathlib
root = os.environ['WB_ROOT']
aid, reason = os.environ['AID'], os.environ['REASON']
state_dir = pathlib.Path(root) / '.workbench-state'
published = state_dir / 'published.json'
approved  = state_dir / 'approved.json'
rejected  = state_dir / 'rejected.json'

def load(p):
    try: return json.loads(p.read_text())
    except FileNotFoundError: return {"items": []}

pub = load(published)
app = load(approved)
rej = load(rejected)

entry = next((i for i in pub['items'] if i.get('id') == aid), None)
if entry is None:
    entry = next((i for i in app['items'] if i.get('id') == aid), None)
if entry:
    full = pathlib.Path(root, entry['path'])
    text = full.read_text()
    new  = re.sub(r'^(status:\s*)(draft|published|approved)\s*$', r'\1draft', text, count=1, flags=re.M)
    full.write_text(new)
    pub['items'] = [i for i in pub['items'] if i.get('id') != aid]
    app['items'] = [i for i in app['items'] if i.get('id') != aid]
    published.write_text(json.dumps(pub, indent=2))
    approved.write_text(json.dumps(app, indent=2))

rej['items'].append({
    "id": aid, "reason": reason,
    "rejected_by": os.environ.get('USER', 'unknown'),
    "rejected_at": datetime.datetime.now(datetime.UTC).isoformat(),
})
rejected.write_text(json.dumps(rej, indent=2))
print(f"Rejected: {aid} — {reason}")
PYEOF
}

# wb.published — list published artifacts awaiting approval
wb.published() {
  python3 - "$WB_ROOT" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
try:
    with open(os.path.join(root, '.workbench-state', 'published.json')) as f:
        state = json.load(f)
except FileNotFoundError:
    print("No published.json yet."); sys.exit(0)
items = state.get('items', [])
if not items:
    print("Nothing published awaiting approval."); sys.exit(0)
print(f"Published ({len(items)}):")
for i in items:
    print(f"  [{i.get('id','?')}]  {i.get('type','?'):15s}  {i.get('path','?')}")
PYEOF
}

# wb.approved — list approved artifacts (ralph-ingestable)
wb.approved() {
  python3 - "$WB_ROOT" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
try:
    with open(os.path.join(root, '.workbench-state', 'approved.json')) as f:
        state = json.load(f)
except FileNotFoundError:
    print("No approved.json yet."); sys.exit(0)
items = state.get('items', [])
if not items:
    print("Nothing approved yet."); sys.exit(0)
print(f"Approved ({len(items)}):")
for i in items:
    print(f"  [{i.get('id','?')}]  {i.get('type','?'):15s}  {i.get('path','?')}")
PYEOF
}

# wb.rejected — list rejected artifacts with reasons (symmetry with wb.published / wb.approved)
wb.rejected() {
  python3 - "$WB_ROOT" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
try:
    with open(os.path.join(root, '.workbench-state', 'rejected.json')) as f:
        state = json.load(f)
except FileNotFoundError:
    print("No rejected.json yet."); sys.exit(0)
items = state.get('items', [])
if not items:
    print("Nothing rejected."); sys.exit(0)
print(f"Rejected ({len(items)}):")
for i in items:
    print(f"  [{i.get('id','?')}]  {i.get('rejected_at','?')[:10]}  by {i.get('rejected_by','?')}  — {i.get('reason','?')}")
PYEOF
}

# ── Git helpers ───────────────────────────────────────────────────────────────
wb.pull()   { (cd "$WB_ROOT" && git pull --rebase); }
wb.status() { (cd "$WB_ROOT" && git status --short); }
wb.log()    { (cd "$WB_ROOT" && git log --oneline -20); }

# ── Info ──────────────────────────────────────────────────────────────────────
wb.info() {
  echo "Workbench: $WB_ROOT"
  [[ -f "$WB_ROOT/project.conf" ]] && source "$WB_ROOT/project.conf" && {
    echo "  Label:    ${WORKBENCH_LABEL:-?}"
    echo "  Repo:     ${WORKBENCH_REPO:-?}"
    echo "  Epics:    ${EPICS[*]:-?}"
    echo "  Repos:    ${#REPOS[@]} registered"
  }
}
