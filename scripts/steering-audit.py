#!/usr/bin/env python3
"""Steering audit for ai-workbench.

Surfaces team-local steering drift in a single workbench:

  - Which template rules have been overridden (add / supersede / remove).
  - Age of each overlay in days (from `created:`, falling back to file mtime).
  - Last-updated dates (from `updated:` field, falling back to file mtime).
  - Promote-suggest heuristic: an override is suggested for upstream promotion
    when artifacts under its scope span more than one epic in this workbench.

Usage:
  steering-audit.py            # human-readable markdown report (default)
  steering-audit.py --json     # structured JSON
  steering-audit.py --list     # terse one-line-per-override

Exit code: 0 always. Empty workbench (no overlays) renders a one-line note.

This script is read-only. It walks `steering.local/`, classifies entries via
the same parser used by `scripts/steering-load.py` and `scripts/steering-overlays.py`,
then walks the workbench artifact directories to compute the per-override
"epics touched" count.
"""
from __future__ import annotations

import datetime as _dt
import importlib.util
import json
import os
import pathlib
import re
import sys

SELF_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SELF_DIR))

# Reuse the parser in steering-load.py without invoking its main().
_spec = importlib.util.spec_from_file_location('steering_load', SELF_DIR / 'steering-load.py')
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)  # type: ignore[union-attr]

WB_ROOT = pathlib.Path(os.environ.get('WB_ROOT',
    pathlib.Path(__file__).resolve().parent.parent))

# Map a steering scope to the workbench artifact directories whose contents
# the overlay would actually affect at runtime. `golden` is cross-cutting.
# Topics are not modelled (their applicability depends on per-skill frontmatter).
SCOPE_TO_ARTIFACT_DIRS: dict[str, list[str]] = {
    'golden': [
        'product/outputs/prds',
        'engineering/outputs/specs',
        'engineering/outputs/tdd',
        'engineering/outputs/erd',
        'engineering/outputs/adrs',
        'qa/outputs/bdd',
        'qa/outputs/test-cases',
        'qa/outputs/test-spec',
        'qa/outputs/test-erd',
        'design/outputs/screens',
        'design/outputs/handoffs',
        'design/outputs/wireframes',
    ],
    'role:dev': [
        'engineering/outputs/specs',
        'engineering/outputs/tdd',
        'engineering/outputs/erd',
        'engineering/outputs/adrs',
    ],
    'role:qa': [
        'qa/outputs/bdd',
        'qa/outputs/test-cases',
        'qa/outputs/test-spec',
        'qa/outputs/test-erd',
    ],
    'role:po': [
        'product/outputs/prds',
    ],
    'role:uxd': [
        'design/outputs/screens',
        'design/outputs/handoffs',
        'design/outputs/wireframes',
    ],
    'artifact:prd':        ['product/outputs/prds'],
    'artifact:eng-spec':   ['engineering/outputs/specs'],
    'artifact:tdd':        ['engineering/outputs/tdd'],
    'artifact:erd':        ['engineering/outputs/erd'],
    'artifact:bdd':        ['qa/outputs/bdd'],
    'artifact:test-cases': ['qa/outputs/test-cases'],
    'artifact:test-spec':  ['qa/outputs/test-spec'],
}

GHERKIN_KV = re.compile(r'^\s*#\s*([A-Za-z0-9_-]+)\s*:\s*(.*)$')
FM_FENCE   = _mod.FM_FENCE


def _parse_date(value: str) -> _dt.date | None:
    """Accept YYYY-MM-DD; return None on anything else."""
    if not isinstance(value, str):
        return None
    try:
        return _dt.date.fromisoformat(value.strip())
    except ValueError:
        return None


def _file_mtime(path: pathlib.Path) -> _dt.date | None:
    try:
        return _dt.date.fromtimestamp(path.stat().st_mtime)
    except OSError:
        return None


def _extract_epic_from_artifact(path: pathlib.Path) -> str | None:
    """Read a single artifact file and return its `epic:` value if present.

    Supports both YAML frontmatter (markdown artifacts) and Gherkin comment
    headers in `.feature` files.
    """
    try:
        text = path.read_text(errors='replace')
    except OSError:
        return None

    if path.suffix == '.feature':
        for line in text.splitlines():
            s = line.strip()
            if not s:
                # End of header block on first blank after we have started reading.
                continue
            if not s.startswith('#'):
                # First non-comment line — Gherkin body. Header is over.
                break
            m = GHERKIN_KV.match(line)
            if m and m.group(1).strip() == 'epic':
                v = m.group(2).strip().strip('"').strip("'")
                return v or None
        return None

    m = FM_FENCE.match(text)
    if not m:
        return None
    for line in m.group(1).splitlines():
        if ':' not in line:
            continue
        k, _, v = line.partition(':')
        if k.strip() == 'epic':
            v = v.strip().strip('"').strip("'")
            return v or None
    return None


def _epics_touched_for_scope(scope: str) -> set[str]:
    """Walk artifact dirs implied by the overlay scope and collect distinct epics."""
    dirs = SCOPE_TO_ARTIFACT_DIRS.get(scope, [])
    epics: set[str] = set()
    for rel in dirs:
        d = WB_ROOT / rel
        if not d.is_dir():
            continue
        for f in d.rglob('*'):
            if not f.is_file():
                continue
            if f.suffix not in ('.md', '.feature'):
                continue
            epic = _extract_epic_from_artifact(f)
            if epic:
                epics.add(epic)
    return epics


def _workbench_epics() -> list[str]:
    """Read EPICS=(...) array from project.conf if present."""
    conf = WB_ROOT / 'project.conf'
    if not conf.is_file():
        return []
    text = conf.read_text(errors='replace')
    m = re.search(r'^\s*EPICS=\(([^)]*)\)', text, re.MULTILINE)
    if not m:
        return []
    raw = m.group(1)
    items = re.findall(r'"([^"]+)"|\'([^\']+)\'|(\S+)', raw)
    out: list[str] = []
    for a, b, c in items:
        v = a or b or c
        if v:
            out.append(v)
    return out


def _classify_overlay(r: dict) -> tuple[str, list[str]]:
    """Return (kind, targets) for an overlay rule.

    kind is one of: add | supersede | remove.
    targets is the list of template rule IDs the override touches; for adds,
    it is the overlay rule's own ID (since there is no template target).
    """
    if r['is_removal']:
        return 'remove', list(r['removes'])
    if r['supersedes']:
        return 'supersede', list(r['supersedes'])
    return 'add', [r['id']]


def _scope_from_rule(r: dict) -> str:
    """Recover the scope string for an overlay rule from its on-disk path.

    The frontmatter `scope:` field reports the scope name; we cross-check by
    walking the path under steering.local/.
    """
    fm_scope = r['raw_fields'].get('scope', '')
    if isinstance(fm_scope, str) and fm_scope:
        return fm_scope.strip()
    src = pathlib.Path(r['source'])
    parts = src.parts
    try:
        i = parts.index('steering.local')
    except ValueError:
        return ''
    rest = parts[i + 1:]
    if not rest:
        return ''
    head = rest[0]
    if head == 'golden-principles':
        return 'golden'
    if head == 'roles' and len(rest) >= 2:
        return f'role:{rest[1]}'
    if head == 'artifacts' and len(rest) >= 2:
        return f'artifact:{rest[1]}'
    if head == 'topics' and len(rest) >= 2:
        return f'topic:{rest[1]}'
    return ''


def _collect_overrides() -> list[dict]:
    """Return one dict per overlay entry with audit-relevant fields."""
    today = _dt.date.today()
    overrides: list[dict] = []
    for scope in _mod._iter_all_scopes():  # noqa: SLF001
        rel = _mod._load_scope_path(scope)  # noqa: SLF001
        overlay = _mod._collect_rules(_mod.OVERLAY_ROOT, rel)  # noqa: SLF001
        if not overlay:
            continue
        epics = _epics_touched_for_scope(scope)
        for r in overlay:
            kind, targets = _classify_overlay(r)
            fields = r['raw_fields']
            created = _parse_date(fields.get('created', ''))
            updated = _parse_date(fields.get('updated', ''))
            src_path = WB_ROOT / r['source']
            mtime    = _file_mtime(src_path)
            # `last_updated` is the best signal we have for "when was this last touched".
            last_updated = updated or mtime
            age_days: int | None = (today - created).days if created else None
            promote = (len(epics) >= 2) and kind != 'remove'
            overrides.append({
                'scope':         scope,
                'kind':          kind,
                'targets':       targets,
                'overlay_id':    r['id'],
                'title':         fields.get('title', '') or '',
                'owner':         fields.get('owner', '') or '',
                'created':       created.isoformat() if created else None,
                'updated':       updated.isoformat() if updated else None,
                'mtime':         mtime.isoformat() if mtime else None,
                'last_updated':  last_updated.isoformat() if last_updated else None,
                'age_days':      age_days,
                'epics_touched': sorted(epics),
                'promote_suggest': promote,
                'source':        r['source'],
            })
    return overrides


def _render_markdown(overrides: list[dict], wb_epics: list[str]) -> str:
    today = _dt.date.today().isoformat()
    template_count = sum(1 for _ in (WB_ROOT / 'steering').rglob('*.md')
                         if (WB_ROOT / 'steering') in _.parents
                         and _.name.lower() != 'readme.md'
                         and not _.name.endswith('.removed.md'))
    out: list[str] = []
    out.append(f'# Steering audit')
    out.append('')
    out.append(f'_Generated: {today}_')
    out.append('')
    if not overrides:
        out.append('No overrides under `steering.local/`. Nothing to audit.')
        out.append('')
        return '\n'.join(out)

    promote_count = sum(1 for o in overrides if o['promote_suggest'])
    out.append('## Summary')
    out.append('')
    out.append(f'- Template rule files (approx): {template_count}')
    out.append(f'- Overlay entries: {len(overrides)}')
    if wb_epics:
        out.append(f'- Workbench epics in scope: {len(wb_epics)} ({", ".join(wb_epics)})')
    else:
        out.append('- Workbench epics in scope: 0 (project.conf missing or empty)')
    out.append(f'- Promote-suggest count: {promote_count}')
    out.append('')

    out.append('## Overrides')
    out.append('')
    out.append('| Overlay ID | Kind | Targets | Scope | Owner | Created | Last updated | Age (d) | Epics touched | Promote? |')
    out.append('|------------|------|---------|-------|-------|---------|--------------|---------|---------------|----------|')
    for o in overrides:
        targets = ', '.join(o['targets']) if o['targets'] else '-'
        epics   = ', '.join(o['epics_touched']) if o['epics_touched'] else '-'
        age     = str(o['age_days']) if o['age_days'] is not None else '?'
        created = o['created'] or '?'
        last_up = o['last_updated'] or '?'
        promote = 'yes' if o['promote_suggest'] else 'no'
        out.append(
            f"| `{o['overlay_id']}` | {o['kind'].upper()} | {targets} | {o['scope']} "
            f"| {o['owner']} | {created} | {last_up} | {age} | {epics} | {promote} |"
        )
    out.append('')

    if promote_count:
        out.append('## Promotion candidates')
        out.append('')
        out.append(
            f'{promote_count} override(s) apply across more than one epic in this '
            'workbench. Consider promoting them to the upstream `ai-workbench` '
            'template repo so other teams pick them up via `update.wb`.'
        )
        out.append('')
        for o in overrides:
            if not o['promote_suggest']:
                continue
            out.append(
                f"- `{o['overlay_id']}` ({o['kind']}, {o['scope']}) — "
                f"epics: {', '.join(o['epics_touched'])}"
            )
        out.append('')
        out.append(
            'Promote: open a PR on `ai-workbench` moving the file from '
            '`steering.local/<path>/<ID>.md` to `steering/<path>/<ID>.md` '
            'with the `-LOCAL` infix stripped.'
        )
        out.append('')

    return '\n'.join(out)


def _render_list(overrides: list[dict]) -> str:
    if not overrides:
        return '(no steering overrides in this workbench)\n'
    lines = [f'{len(overrides)} steering override(s):']
    for o in overrides:
        targets = ','.join(o['targets']) if o['targets'] else '-'
        epics   = len(o['epics_touched'])
        age     = o['age_days'] if o['age_days'] is not None else '?'
        promote = '*' if o['promote_suggest'] else ' '
        lines.append(
            f"  {promote} {o['kind'].upper():<9} {o['scope']:<22} "
            f"{o['overlay_id']:<14} targets={targets:<14} age={age!s:>3}d epics={epics}"
        )
    lines.append('')
    lines.append('(* = promote-suggest: applies to artifacts spanning more than one epic)')
    return '\n'.join(lines) + '\n'


def main(argv: list[str]) -> int:
    fmt = 'markdown'
    for a in argv:
        if a == '--json':
            fmt = 'json'
        elif a == '--list':
            fmt = 'list'
        elif a in ('-h', '--help'):
            print(__doc__)
            return 0
        else:
            print(__doc__, file=sys.stderr)
            return 2

    overrides = _collect_overrides()

    if fmt == 'json':
        wb_epics = _workbench_epics()
        sys.stdout.write(json.dumps({
            'generated_at': _dt.date.today().isoformat(),
            'workbench_epics': wb_epics,
            'overrides': overrides,
        }, indent=2) + '\n')
    elif fmt == 'list':
        sys.stdout.write(_render_list(overrides))
    else:
        sys.stdout.write(_render_markdown(overrides, _workbench_epics()))

    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
