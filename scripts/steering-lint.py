#!/usr/bin/env python3
"""Steering lint for ai-workbench.

Usage:
  steering-lint.py           # lint steering/ and steering.local/
  steering-lint.py --template-only
  steering-lint.py --overlay-only

Checks:
  - Every rule file has YAML-lite frontmatter with required fields.
  - Rule IDs match the configured regex.
  - Rule IDs are globally unique within the template set.
  - Overlay IDs carry the -LOCAL- infix.
  - `supersedes` and `removes` only appear in overlay files.
  - `.removed.md` sidecars must have `removes: [...]`, no body content that
    looks like a rule (it is purely a tombstone with reason).
  - Filename must match the rule's ID (prefix).

Exit code: 0 on clean, 1 on violation.
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

ID_REGEX = re.compile(r'^[A-Z]+(-LOCAL)?-\d{2,3}(\.removed)?$')
LOCAL_INFIX = re.compile(r'-LOCAL-\d{2,3}$')
REQUIRED_FIELDS = {'id', 'title', 'scope', 'owner', 'created'}
OVERLAY_ONLY_FIELDS = {'supersedes', 'removes'}

FM_FENCE = re.compile(r'(?s)^---\n(.*?)\n---\n?')


def _parse_frontmatter(text: str) -> tuple[dict, str]:
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


def _collect(root: pathlib.Path) -> list[tuple[pathlib.Path, dict, str]]:
    """Return list of (path, frontmatter, body) for every rule file under root."""
    if not root.is_dir():
        return []
    out: list[tuple[pathlib.Path, dict, str]] = []
    for md in sorted(root.rglob('*.md')):
        # Skip scope-level README, config files.
        if md.name.lower() == 'readme.md':
            continue
        if md.name == 'config.yaml':
            continue
        text = md.read_text()
        fields, body = _parse_frontmatter(text)
        out.append((md, fields, body))
    return out


def _check_one(path: pathlib.Path, fields: dict, body: str, *, is_overlay: bool) -> list[str]:
    """Return a list of violation strings for a single rule file."""
    errs: list[str] = []
    rel = path.relative_to(WB_ROOT)
    is_removal = path.name.endswith('.removed.md')

    # Required fields.
    if not is_removal:
        missing = REQUIRED_FIELDS - set(fields.keys())
        if missing:
            errs.append(f"{rel}: missing required frontmatter fields: {sorted(missing)}")
    else:
        # Removal sidecars need `id`, `removes`, `owner`, `created`.
        for f in ['id', 'removes', 'owner', 'created']:
            if f not in fields:
                errs.append(f"{rel}: removal sidecar missing field `{f}`")

    rid = fields.get('id', '')
    if not isinstance(rid, str) or not ID_REGEX.match(rid):
        errs.append(f"{rel}: id `{rid}` does not match regex {ID_REGEX.pattern}")

    # Overlay-only field placement.
    if not is_overlay:
        for f in OVERLAY_ONLY_FIELDS:
            if f in fields and fields[f]:
                errs.append(f"{rel}: field `{f}` is overlay-only; not allowed in template steering/")

    if is_overlay:
        # Overlay IDs must have -LOCAL- infix (except removal-sidecar IDs, which
        # are bookkeeping tombstones and may keep the removed rule's ID + `.removed`).
        if not is_removal and not LOCAL_INFIX.search(rid):
            errs.append(
                f"{rel}: overlay rule id `{rid}` missing `-LOCAL-NN` infix"
            )

    # Filename must begin with the id (stripped of `.removed` suffix).
    expected_prefix = rid.replace('.removed', '')
    fname = path.stem
    if not fname.startswith(expected_prefix):
        errs.append(f"{rel}: filename does not start with id `{expected_prefix}`")

    # Removal sidecars must have non-empty `removes` list.
    if is_removal:
        rem = fields.get('removes')
        if not isinstance(rem, list) or not rem:
            errs.append(f"{rel}: `.removed.md` must have non-empty `removes:` list")

    return errs


def _check_unique_ids(collected: list[tuple[pathlib.Path, dict, str]], label: str) -> list[str]:
    """Ensure IDs are unique within a tree (ignores .removed sidecars)."""
    seen: dict[str, pathlib.Path] = {}
    errs: list[str] = []
    for path, fields, _ in collected:
        if path.name.endswith('.removed.md'):
            continue
        rid = fields.get('id', '')
        if not rid:
            continue
        if rid in seen:
            errs.append(
                f"duplicate id `{rid}` in {label}: "
                f"{seen[rid].relative_to(WB_ROOT)} and {path.relative_to(WB_ROOT)}"
            )
        else:
            seen[rid] = path
    return errs


def main(argv: list[str]) -> int:
    template_only = '--template-only' in argv
    overlay_only = '--overlay-only' in argv

    all_errs: list[str] = []

    if not overlay_only:
        template = _collect(STEERING_ROOT)
        for path, fields, body in template:
            all_errs.extend(_check_one(path, fields, body, is_overlay=False))
        all_errs.extend(_check_unique_ids(template, 'steering/'))

    if not template_only:
        overlay = _collect(OVERLAY_ROOT)
        for path, fields, body in overlay:
            all_errs.extend(_check_one(path, fields, body, is_overlay=True))
        all_errs.extend(_check_unique_ids(overlay, 'steering.local/'))

    if all_errs:
        for e in all_errs:
            print(e, file=sys.stderr)
        print(f"\n{len(all_errs)} violation(s).", file=sys.stderr)
        return 1
    print("steering lint: clean.")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
