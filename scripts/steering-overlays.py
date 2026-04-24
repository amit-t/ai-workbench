#!/usr/bin/env python3
"""Emit a summary of steering.local/ overlays applied to the template.

Usage:
  steering-overlays.py --footer      # markdown block for PR bodies (silent if empty)
  steering-overlays.py --json        # structured list of overrides
  steering-overlays.py --list        # human-readable table

Reuses the parser in scripts/steering-load.py — walks every scope defined in
steering/config.yaml, classifies each overlay entry as add / supersede / remove,
and renders a compact listing suitable for embedding in ralph-authored PR bodies.

The --footer output is written verbatim into
$WB_ROOT/repos/.ralph/pr_footer.md by sync-context.sh. When the overlay set is
empty, the footer is empty (no file content) so ralph emits the default PR body
unchanged.
"""
from __future__ import annotations

import json
import os
import pathlib
import sys

SELF_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SELF_DIR))

# Import reusable pieces of steering-load.py without invoking its main().
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location('steering_load', SELF_DIR / 'steering-load.py')
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)  # type: ignore[union-attr]

WB_ROOT = pathlib.Path(os.environ.get('WB_ROOT',
    pathlib.Path(__file__).resolve().parent.parent))


def _collect_all_overrides() -> list[dict]:
    """Walk every scope, classify every overlay entry. Returns ordered list."""
    overrides: list[dict] = []
    for scope in _mod._iter_all_scopes():  # noqa: SLF001
        rel = _mod._load_scope_path(scope)  # noqa: SLF001
        overlay = _mod._collect_rules(_mod.OVERLAY_ROOT, rel)  # noqa: SLF001
        for r in overlay:
            if r['is_removal']:
                for target in r['removes']:
                    overrides.append({
                        'scope': scope,
                        'kind': 'remove',
                        'target': target,
                        'by': r['id'],
                        'title': r.get('title', ''),
                        'source': r['source'],
                    })
            elif r['supersedes']:
                for target in r['supersedes']:
                    overrides.append({
                        'scope': scope,
                        'kind': 'supersede',
                        'target': target,
                        'by': r['id'],
                        'title': r.get('title', ''),
                        'source': r['source'],
                    })
            else:
                overrides.append({
                    'scope': scope,
                    'kind': 'add',
                    'target': None,
                    'by': r['id'],
                    'title': r.get('title', ''),
                    'source': r['source'],
                })
    return overrides


def _render_footer(overrides: list[dict]) -> str:
    if not overrides:
        return ''
    lines = []
    lines.append('---')
    lines.append('### Steering drift for this workspace')
    lines.append('')
    n = len(overrides)
    noun = 'override' if n == 1 else 'overrides'
    lines.append(f'This workspace has {n} local steering {noun}:')
    lines.append('')
    for o in overrides:
        title = f' — {o["title"]}' if o.get('title') else ''
        if o['kind'] == 'add':
            lines.append(f'- `{o["by"]}` (ADD, {o["scope"]}){title}')
        elif o['kind'] == 'supersede':
            lines.append(f'- `{o["target"]}` → `{o["by"]}` (SUPERSEDE, {o["scope"]}){title}')
        elif o['kind'] == 'remove':
            lines.append(f'- `{o["target"]}` (REMOVE by `{o["by"]}`, {o["scope"]}){title}')
    lines.append('')
    lines.append('Promote an override to the template: open a PR on the '
                 'ai-workbench template repo moving the file from '
                 '`steering.local/` to `steering/`.')
    return '\n'.join(lines) + '\n'


def _render_list(overrides: list[dict]) -> str:
    if not overrides:
        return '(no steering overrides in this workbench)\n'
    lines = [f'{len(overrides)} steering override(s):']
    for o in overrides:
        label = o['kind'].upper()
        target = o['target'] if o.get('target') else '-'
        lines.append(f"  [{label:<9}] scope={o['scope']:<20} target={target:<15} by={o['by']}")
    return '\n'.join(lines) + '\n'


def main(argv: list[str]) -> int:
    if len(argv) != 1 or argv[0] not in ('--footer', '--json', '--list'):
        print(__doc__, file=sys.stderr)
        return 2

    overrides = _collect_all_overrides()

    if argv[0] == '--footer':
        sys.stdout.write(_render_footer(overrides))
    elif argv[0] == '--json':
        sys.stdout.write(json.dumps(overrides, indent=2) + '\n')
    else:
        sys.stdout.write(_render_list(overrides))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
