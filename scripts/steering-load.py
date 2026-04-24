#!/usr/bin/env python3
"""Steering loader for ai-workbench.

Usage:
  steering-load.py <scope>

  <scope> is one of:
    golden
    role:<dev|qa|po|uxd>
    artifact:<prd|eng-spec|tdd|bdd|test-cases|test-spec|...>
    topic:<slug>
    all

The loader walks `steering/<path>/` for template rules and `steering.local/<path>/`
for overlay entries, applies overlay semantics (add, supersede via explicit
`supersedes:` field, remove via `.removed.md` sidecar), and emits a single
merged markdown blob ordered by rule ID. A footer summarises which overlays
were applied.

Agents are expected to invoke this loader at the invocation points listed in
`steering/config.yaml`. Do not try to merge overlays in your head.
"""
from __future__ import annotations

import os
import pathlib
import re
import sys

WB_ROOT = pathlib.Path(os.environ.get('WB_ROOT',
    pathlib.Path(__file__).resolve().parent.parent))
STEERING_ROOT = WB_ROOT / 'steering'
OVERLAY_ROOT  = WB_ROOT / 'steering.local'
CONFIG_PATH   = STEERING_ROOT / 'config.yaml'

FM_FENCE = re.compile(r'(?s)^---\n(.*?)\n---\n?')


def _parse_frontmatter(text: str) -> tuple[dict, str]:
    """Parse the YAML-lite frontmatter block at the top of a rule file.

    Supports the subset we actually use:
      - key: scalar
      - key: [v1, v2, v3]
      - Blank lines inside the block are ignored.

    Returns (fields_dict, body_text).
    """
    m = FM_FENCE.match(text)
    if not m:
        return {}, text
    raw = m.group(1)
    body = text[m.end():]
    fields: dict[str, object] = {}
    for line in raw.splitlines():
        line = line.rstrip()
        if not line.strip():
            continue
        if ':' not in line:
            continue
        key, _, value = line.partition(':')
        key = key.strip()
        value = value.strip()
        if value.startswith('[') and value.endswith(']'):
            inner = value[1:-1].strip()
            items = [item.strip().strip('"').strip("'") for item in inner.split(',') if item.strip()]
            fields[key] = items
        else:
            fields[key] = value.strip().strip('"').strip("'")
    return fields, body.lstrip('\n')


def _load_scope_path(scope: str) -> pathlib.Path:
    """Map a scope string to its directory under steering/."""
    if scope == 'golden':
        return pathlib.Path('golden-principles')
    if ':' in scope:
        kind, slug = scope.split(':', 1)
        if kind == 'role':
            return pathlib.Path('roles') / slug
        if kind == 'artifact':
            return pathlib.Path('artifacts') / slug
        if kind == 'topic':
            return pathlib.Path('topics') / slug
    raise SystemExit(
        f"Error: unknown scope '{scope}'. Use: golden | role:<x> | artifact:<x> | topic:<x> | all."
    )


def _collect_rules(root: pathlib.Path, rel: pathlib.Path) -> list[dict]:
    """Collect rule records from one directory. Returns ordered list."""
    d = root / rel
    if not d.is_dir():
        return []
    rules: list[dict] = []
    for md in sorted(d.glob('*.md')):
        text = md.read_text()
        fields, body = _parse_frontmatter(text)
        if 'id' not in fields:
            continue
        rules.append({
            'id': fields['id'],
            'title': fields.get('title', ''),
            'owner': fields.get('owner', ''),
            'supersedes': fields.get('supersedes', []) or [],
            'removes': fields.get('removes', []) or [],
            'is_removal': md.name.endswith('.removed.md'),
            'source': str(md.relative_to(WB_ROOT)),
            'body': body,
            'raw_fields': fields,
        })
    return rules


def _apply_overlay(template: list[dict], overlay: list[dict]) -> tuple[list[dict], dict]:
    """Merge overlay rules into template set.

    Returns (merged_rules, applied_summary).
    """
    applied: dict[str, list[str]] = {'added': [], 'superseded': [], 'removed': []}

    # First pass: collect removals.
    to_remove: set[str] = set()
    for r in overlay:
        if r['is_removal']:
            for target in r['removes']:
                to_remove.add(target)
                applied['removed'].append(f"{target} (by {r['id']} at {r['source']})")

    # Second pass: collect supersede replacements.
    supersede_map: dict[str, dict] = {}
    for r in overlay:
        if r['is_removal']:
            continue
        if r['supersedes']:
            for target in r['supersedes']:
                supersede_map[target] = r
                applied['superseded'].append(f"{target} (by {r['id']} at {r['source']})")

    # Third pass: apply remove + supersede to template.
    merged: list[dict] = []
    for r in template:
        if r['id'] in to_remove:
            continue
        if r['id'] in supersede_map:
            merged.append(supersede_map[r['id']])
        else:
            merged.append(r)

    # Fourth pass: add overlay rules that are not removals and not supersedes
    # of any template rule.
    superseded_ids = set(supersede_map.keys())
    merged_ids = {r['id'] for r in merged}
    for r in overlay:
        if r['is_removal']:
            continue
        if r['supersedes']:
            # If it superseded something, it is already in merged above.
            # Skip here to avoid duplicates.
            continue
        if r['id'] in merged_ids:
            continue
        merged.append(r)
        applied['added'].append(f"{r['id']} ({r['source']})")

    # Sort merged by ID for determinism.
    merged.sort(key=lambda r: r['id'])
    return merged, applied


def _render(scope: str, merged: list[dict], applied: dict, template_count: int, overlay_count: int) -> str:
    """Produce the final markdown blob for the agent to consume."""
    out: list[str] = []
    out.append(f"# Steering rules — scope `{scope}`\n")
    out.append(
        f"_Template rules: {template_count}. Overlay rules: {overlay_count}. "
        f"Applied — added: {len(applied['added'])}, "
        f"superseded: {len(applied['superseded'])}, "
        f"removed: {len(applied['removed'])}._\n"
    )
    out.append("---\n")
    for r in merged:
        out.append(f"## {r['id']} — {r['title']}\n")
        out.append(f"_Owner: {r['owner']}. Source: `{r['source']}`._\n")
        out.append(r['body'].rstrip() + "\n")
        out.append("---\n")

    if applied['added'] or applied['superseded'] or applied['removed']:
        out.append("### Overlay details\n")
        if applied['added']:
            out.append("**Added by overlay:**\n")
            for item in applied['added']:
                out.append(f"- {item}")
            out.append("")
        if applied['superseded']:
            out.append("**Superseded by overlay:**\n")
            for item in applied['superseded']:
                out.append(f"- {item}")
            out.append("")
        if applied['removed']:
            out.append("**Removed by overlay:**\n")
            for item in applied['removed']:
                out.append(f"- {item}")
            out.append("")
    return "\n".join(out)


def _iter_all_scopes() -> list[str]:
    """Enumerate every scope present on disk (template). Used by `all`."""
    scopes: list[str] = []
    if (STEERING_ROOT / 'golden-principles').is_dir():
        scopes.append('golden')
    roles_root = STEERING_ROOT / 'roles'
    if roles_root.is_dir():
        for p in sorted(roles_root.iterdir()):
            if p.is_dir():
                scopes.append(f"role:{p.name}")
    artifacts_root = STEERING_ROOT / 'artifacts'
    if artifacts_root.is_dir():
        for p in sorted(artifacts_root.iterdir()):
            if p.is_dir():
                scopes.append(f"artifact:{p.name}")
    topics_root = STEERING_ROOT / 'topics'
    if topics_root.is_dir():
        for p in sorted(topics_root.iterdir()):
            if p.is_dir():
                scopes.append(f"topic:{p.name}")
    return scopes


def load_one(scope: str) -> str:
    rel = _load_scope_path(scope)
    template = _collect_rules(STEERING_ROOT, rel)
    overlay  = _collect_rules(OVERLAY_ROOT, rel)
    merged, applied = _apply_overlay(template, overlay)
    return _render(scope, merged, applied, len(template), len(overlay))


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    scope = argv[0]
    if scope == 'all':
        out: list[str] = []
        for s in _iter_all_scopes():
            out.append(load_one(s))
            out.append("\n")
        sys.stdout.write("\n".join(out))
        return 0
    sys.stdout.write(load_one(scope))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
