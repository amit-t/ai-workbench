#!/usr/bin/env python3
"""Validate an artifact file against scripts/artifact-schema.json.

Usage:
  validate-artifact.py <path> <type>

Checks the artifact's frontmatter (YAML) or Gherkin header (# key: value) against
the schema for the given type:
  - Every `required` field must be present and non-empty.
  - If `allowed_targets: from_project_conf`, `target_repos` must be a non-empty
    list whose members are all registered repos in project.conf REPOS[].name.
  - If `allowed_targets: none`, `target_repos` must be absent.

Exits 0 on pass, non-zero with an actionable message on fail. Called from
scripts/lifecycle.py at publish and approve.
"""
from __future__ import annotations

import json
import os
import pathlib
import re
import sys

WB_ROOT = pathlib.Path(os.environ.get('WB_ROOT',
    pathlib.Path(__file__).resolve().parent.parent))

SCHEMA_PATH = WB_ROOT / 'scripts' / 'artifact-schema.json'
PROJECT_CONF = WB_ROOT / 'project.conf'

FM_FENCE = re.compile(r'(?s)^---\n(.*?)\n---')
REPOS_LINE_RE = re.compile(r'^\s*"name=([^;]+);')

VALID_DEPTHS = {'deep', 'standard', 'quick', 'null', ''}
VALID_MODES = {'grill-me', 'domain-grill', 'skipped'}
RESULT_RE = re.compile(r'^(resolved|skipped|aborted|aborted-cascade|parked-\d+)$')
PASS_LEAD_RE = re.compile(r'^\s*-\s*(?:\{?\s*)?mode\s*:')
KEY_DEPTH_RE = re.compile(r'^\s*depth\s*:')
KEY_PASSES_RE = re.compile(r'^\s*passes\s*:')
KEY_DATE_RE = re.compile(r'^\s*date\s*:')


def _parse_yaml_frontmatter(text: str) -> dict:
    m = FM_FENCE.match(text)
    if not m:
        return {}
    raw = m.group(1)
    return _parse_kv_block(raw)


def _parse_gherkin_header(text: str) -> dict:
    fields: dict[str, object] = {}
    for line in text.splitlines():
        s = line.rstrip()
        if not s.strip():
            if fields:
                break
            continue
        if not s.lstrip().startswith('#'):
            if fields:
                break
            continue
        body = s.lstrip()[1:].strip()
        if ':' not in body:
            continue
        k, _, v = body.partition(':')
        k = k.strip()
        v = v.strip()
        fields[k] = _coerce(v)
    return fields


def _parse_kv_block(raw: str) -> dict:
    fields: dict[str, object] = {}
    for line in raw.splitlines():
        line = line.rstrip()
        if not line.strip() or ':' not in line:
            continue
        key, _, value = line.partition(':')
        fields[key.strip()] = _coerce(value.strip())
    return fields


def _coerce(value: str) -> object:
    if value.startswith('[') and value.endswith(']'):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [p.strip().strip('"').strip("'") for p in inner.split(',') if p.strip()]
    return value.strip('"').strip("'")


def _extract_grilled_block(text: str, header_kind: str) -> str | None:
    """Return the raw `grilled:` subtree lines (without the `grilled:` key line itself),
    or None if absent. Stops at the next top-level frontmatter key or the closing fence.

    Handles both YAML frontmatter and Gherkin `# grilled:` header comments.
    """
    if header_kind == 'gherkin':
        body_lines: list[str] = []
        in_block = False
        for raw_line in text.splitlines():
            s = raw_line.rstrip()
            stripped = s.lstrip()
            if not stripped.startswith('#'):
                if in_block and stripped:
                    break
                if in_block:
                    continue
                if stripped:
                    break
                continue
            inner = stripped[1:]
            if inner.lstrip().startswith('grilled:'):
                in_block = True
                continue
            if in_block:
                if not inner.strip():
                    break
                first_char = inner.lstrip()[:1]
                lead_spaces = len(inner) - len(inner.lstrip())
                if lead_spaces == 0 and first_char and first_char not in {'-', '#'}:
                    break
                body_lines.append(inner)
        if not in_block and not body_lines:
            return None
        return '\n'.join(body_lines)

    m = FM_FENCE.match(text)
    if not m:
        return None
    fm = m.group(1)
    body_lines = []
    in_block = False
    for line in fm.splitlines():
        if not in_block:
            if line.startswith('grilled:'):
                in_block = True
            continue
        if line and not line.startswith((' ', '\t', '-')):
            break
        body_lines.append(line)
    if not in_block:
        return None
    return '\n'.join(body_lines)


def _parse_grilled(block: str) -> tuple[dict, list[dict]]:
    """Parse the indented YAML subtree under `grilled:` into (top_keys, passes_list)."""
    top: dict[str, str] = {}
    passes: list[dict] = []
    current: dict | None = None
    in_passes = False
    for raw in block.splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        stripped = line.lstrip()
        indent = len(line) - len(stripped)
        if KEY_DATE_RE.match(line):
            top['date'] = stripped.split(':', 1)[1].strip()
            in_passes = False
            continue
        if KEY_DEPTH_RE.match(line):
            top['depth'] = stripped.split(':', 1)[1].strip().strip("'\"")
            in_passes = False
            continue
        if KEY_PASSES_RE.match(line):
            in_passes = True
            continue
        if not in_passes:
            continue
        if PASS_LEAD_RE.match(line):
            current = {}
            passes.append(current)
            inner = stripped[1:].strip()
            if inner.startswith('{') and inner.endswith('}'):
                _parse_inline_obj(inner, current)
                current = None
                continue
            k, _, v = inner.partition(':')
            current[k.strip()] = v.strip().strip("'\"")
            continue
        if current is not None and indent > 0 and ':' in stripped and not stripped.startswith('-'):
            k, _, v = stripped.partition(':')
            current[k.strip()] = v.strip().strip("'\"")
    return top, passes


def _parse_inline_obj(inline: str, into: dict) -> None:
    """Parse `{ mode: x, repo: y, result: z, open: 0, parked: 0 }` into `into`."""
    inner = inline.strip().lstrip('{').rstrip('}').strip()
    if not inner:
        return
    for part in inner.split(','):
        if ':' not in part:
            continue
        k, _, v = part.partition(':')
        into[k.strip()] = v.strip().strip("'\"")


def _validate_grilled(rel_path: str, block: str) -> None:
    top, passes = _parse_grilled(block)
    if 'date' not in top:
        die(f"{rel_path}: grilled.date is required when grilled: block is present.")
    depth = (top.get('depth') or '').strip().strip("'\"")
    if depth not in VALID_DEPTHS:
        die(f"{rel_path}: grilled.depth must be one of {sorted(VALID_DEPTHS - {''})}; got '{depth}'.")
    if not passes:
        die(f"{rel_path}: grilled.passes must be a non-empty list.")
    required_pass_keys = {'mode', 'repo', 'result', 'open', 'parked'}
    for i, p in enumerate(passes):
        missing = required_pass_keys - set(p.keys())
        if missing:
            die(f"{rel_path}: grilled.passes[{i}] missing keys: {sorted(missing)}.")
        if p['mode'] not in VALID_MODES:
            die(f"{rel_path}: grilled.passes[{i}].mode must be one of {sorted(VALID_MODES)}; got '{p['mode']}'.")
        if not RESULT_RE.match(p['result']):
            die(f"{rel_path}: grilled.passes[{i}].result must match resolved|parked-N|skipped|aborted|aborted-cascade; got '{p['result']}'.")
        for numk in ('open', 'parked'):
            try:
                int(p[numk])
            except (TypeError, ValueError):
                die(f"{rel_path}: grilled.passes[{i}].{numk} must be an integer; got '{p[numk]}'.")


def _load_schema() -> dict:
    if not SCHEMA_PATH.is_file():
        die(f"schema file missing at {SCHEMA_PATH}")
    return json.loads(SCHEMA_PATH.read_text()).get('types', {})


def _registered_repos() -> list[str]:
    if not PROJECT_CONF.is_file():
        return []
    names: list[str] = []
    inside = False
    for line in PROJECT_CONF.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith('REPOS=('):
            inside = True
            continue
        if inside and stripped == ')':
            break
        if not inside:
            continue
        m = REPOS_LINE_RE.match(line)
        if m:
            names.append(m.group(1))
    return names


def die(msg: str) -> None:
    print(f"validate-artifact: {msg}", file=sys.stderr)
    sys.exit(1)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    rel_path, atype = argv

    schema = _load_schema()
    rule = schema.get(atype)
    if rule is None:
        die(f"unknown artifact type '{atype}'. Update scripts/artifact-schema.json.")

    full = (WB_ROOT / rel_path).resolve()
    try:
        full.relative_to(WB_ROOT.resolve())
    except ValueError:
        die(f"path '{rel_path}' escapes workbench root.")
    if not full.is_file():
        die(f"file not found: {rel_path}")

    text = full.read_text()
    header_kind = rule.get('header', 'yaml')
    fields = (_parse_gherkin_header(text) if header_kind == 'gherkin'
              else _parse_yaml_frontmatter(text))

    missing = [k for k in rule.get('required', []) if not fields.get(k)]
    if missing:
        die(
            f"{rel_path}: missing required field(s): {', '.join(missing)}. "
            f"Type '{atype}' requires: {rule['required']}."
        )

    allowed = rule.get('allowed_targets', 'none')
    tr = fields.get('target_repos')

    if allowed == 'none':
        if tr:
            die(
                f"{rel_path}: type '{atype}' must not set 'target_repos' "
                f"(it does not route to code repos)."
            )
    elif allowed == 'from_project_conf':
        if not isinstance(tr, list) or not tr:
            die(
                f"{rel_path}: 'target_repos' must be a non-empty list for type '{atype}'. "
                f"Example: target_repos: [payments-svc, payments-web]"
            )
        registered = _registered_repos()
        if not registered:
            die(
                "project.conf has no REPOS registered. "
                "Register repos first with wb.register-repo <name> <url> <role>."
            )
        unknown = [r for r in tr if r not in registered]
        if unknown:
            die(
                f"{rel_path}: target_repos includes unregistered repo(s): {unknown}. "
                f"Registered: {registered}."
            )
    else:
        die(f"schema error: unknown allowed_targets '{allowed}' for type '{atype}'.")

    grilled_block = _extract_grilled_block(text, header_kind)
    if grilled_block is not None:
        _validate_grilled(rel_path, grilled_block)

    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
