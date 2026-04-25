#!/usr/bin/env python3
"""Artifact lifecycle CLI for ai-workbench.

Usage:
  lifecycle.py publish <id> <path> <type>
  lifecycle.py approve <id>
  lifecycle.py reject  <id> <reason>
  lifecycle.py list    {published|approved|rejected}

All write operations take an advisory lock on .workbench-state/.lock so
concurrent collaborators on the same workbench do not trample each other's
state files. Read-only `list` does not lock.

Status is tracked in two places:
  1. Inside the artifact file. For YAML-frontmatter files (.md etc.) the
     `status:` line is rewritten. For Gherkin files (.feature) a header
     comment `# status: ...` is rewritten.
  2. In .workbench-state/{published,approved,rejected}.json ledgers.

Agents must only write `status: draft`. Transitions to published/approved
happen exclusively through this CLI, invoked by a human via wb.* aliases.
"""
from __future__ import annotations

import argparse
import datetime
import fcntl
import json
import os
import pathlib
import re
import subprocess
import sys
from contextlib import contextmanager

ALLOWED_TYPES = {
    "prd", "eng-spec", "tdd", "erd", "adr",
    "bdd", "test-cases", "test-spec", "test-erd",
    "epic-context",
}

YAML_STATUS_RE   = re.compile(r'^(status:\s*)(draft|published|approved)\s*$', re.M)
YAML_FRONT_RE    = re.compile(r'(?s)(^---\n)(.*?)(\n---)')
GHERKIN_HEADER_RE = re.compile(r'^(\s*#\s*status:\s*)(draft|published|approved)\s*$', re.M)


def _state_paths(root: pathlib.Path):
    state_dir = root / '.workbench-state'
    return {
        'dir':       state_dir,
        'lock':      state_dir / '.lock',
        'published': state_dir / 'published.json',
        'approved':  state_dir / 'approved.json',
        'rejected':  state_dir / 'rejected.json',
    }


def _load(p: pathlib.Path) -> dict:
    try:
        return json.loads(p.read_text())
    except FileNotFoundError:
        return {"items": []}


def _now() -> str:
    return datetime.datetime.now(datetime.UTC).isoformat()


def _user() -> str:
    return os.environ.get('USER', 'unknown')


@contextmanager
def _locked(paths: dict):
    """Acquire an exclusive advisory lock on .workbench-state/.lock."""
    paths['dir'].mkdir(parents=True, exist_ok=True)
    lock_fh = open(paths['lock'], 'a+')
    try:
        fcntl.flock(lock_fh.fileno(), fcntl.LOCK_EX)
        yield
    finally:
        fcntl.flock(lock_fh.fileno(), fcntl.LOCK_UN)
        lock_fh.close()


def _is_gherkin(path: pathlib.Path) -> bool:
    return path.suffix == '.feature'


def _flip_status(full: pathlib.Path, new_status: str) -> None:
    """Rewrite the status line inside the artifact file. Format-aware."""
    text = full.read_text()
    if _is_gherkin(full):
        new = GHERKIN_HEADER_RE.sub(
            lambda m: f"{m.group(1)}{new_status}", text, count=1,
        )
        if new == text:
            raise SystemExit(
                f"Error: {full} has no '# status:' header comment. "
                f"Gherkin lifecycle requires a header line like '# status: draft' at the top."
            )
    else:
        new = YAML_STATUS_RE.sub(
            lambda m: f"{m.group(1)}{new_status}", text, count=1,
        )
        if new == text:
            injected = YAML_FRONT_RE.sub(
                lambda m: f"{m.group(1)}{m.group(2)}\nstatus: {new_status}{m.group(3)}",
                text, count=1,
            )
            if injected == text:
                raise SystemExit(
                    f"Error: {full} has no YAML frontmatter block. "
                    f"Add one with 'status: draft' and retry."
                )
            new = injected
    full.write_text(new)


def _safe_resolve(root: pathlib.Path, rel: str) -> pathlib.Path:
    full = (root / rel).resolve()
    root_resolved = root.resolve()
    try:
        full.relative_to(root_resolved)
    except ValueError:
        raise SystemExit(f"Error: path {rel} escapes workbench root.")
    return full


def _validate_artifact(root: pathlib.Path, rel_path: str, atype: str) -> None:
    """Run scripts/validate-artifact.py against the artifact; raise SystemExit on failure."""
    validator = root / 'scripts' / 'validate-artifact.py'
    if not validator.is_file():
        return  # validator not installed; skip silently to preserve older workbenches
    env = dict(os.environ)
    env['WB_ROOT'] = str(root)
    try:
        subprocess.run(
            [sys.executable, str(validator), rel_path, atype],
            check=True, env=env,
        )
    except subprocess.CalledProcessError as e:
        raise SystemExit(e.returncode or 1)


# ── Commands ──────────────────────────────────────────────────────────────────

def cmd_publish(root: pathlib.Path, aid: str, apath: str, atype: str) -> None:
    if atype not in ALLOWED_TYPES:
        raise SystemExit(
            f"Error: unknown type '{atype}'. Must be one of: {sorted(ALLOWED_TYPES)}."
        )
    paths = _state_paths(root)
    with _locked(paths):
        pub = _load(paths['published'])
        app = _load(paths['approved'])

        if any(i.get('id') == aid for i in app['items']):
            raise SystemExit(f"Error: {aid} is already approved. Nothing to publish.")

        existing = next((i for i in pub['items'] if i.get('id') == aid), None)
        if existing and not apath:
            apath = existing.get('path', '')

        full = _safe_resolve(root, apath)
        if not full.is_file():
            raise SystemExit(
                f"Error: artifact file not found at {apath}. "
                f"Pass <path> on first publish."
            )

        _validate_artifact(root, apath, atype)
        _flip_status(full, 'published')

        if existing:
            existing['path'] = apath
            existing['type'] = atype
            existing['updated_at'] = _now()
        else:
            pub['items'].append({
                "id": aid, "type": atype, "path": apath,
                "published_by": _user(),
                "published_at": _now(),
            })
        paths['published'].write_text(json.dumps(pub, indent=2))
    print(f"Published: {aid}  ({apath})")


def cmd_approve(root: pathlib.Path, aid: str) -> None:
    paths = _state_paths(root)
    with _locked(paths):
        pub = _load(paths['published'])
        app = _load(paths['approved'])

        if any(i.get('id') == aid for i in app['items']):
            print(f"Already approved: {aid}")
            return

        entry = next((i for i in pub['items'] if i.get('id') == aid), None)
        if not entry:
            raise SystemExit(
                f"Error: {aid} is not in published state. "
                f"Run: wb.publish {aid} <path> <type>"
            )

        full = pathlib.Path(root, entry['path'])
        _validate_artifact(root, entry['path'], entry['type'])
        try:
            _flip_status(full, 'approved')
        except SystemExit as e:
            print(f"Warning: {e}. JSON state updated; file status may be stale.",
                  file=sys.stderr)

        entry['approved_by'] = _user()
        entry['approved_at'] = _now()
        app['items'].append(entry)
        pub['items'] = [i for i in pub['items'] if i.get('id') != aid]
        paths['published'].write_text(json.dumps(pub, indent=2))
        paths['approved'].write_text(json.dumps(app, indent=2))
    print(f"Approved: {aid}  ({entry['path']})")


def cmd_reject(root: pathlib.Path, aid: str, reason: str) -> None:
    paths = _state_paths(root)
    with _locked(paths):
        pub = _load(paths['published'])
        app = _load(paths['approved'])
        rej = _load(paths['rejected'])

        entry = next((i for i in pub['items'] if i.get('id') == aid), None)
        if entry is None:
            entry = next((i for i in app['items'] if i.get('id') == aid), None)
        if entry:
            full = pathlib.Path(root, entry['path'])
            if full.is_file():
                try:
                    _flip_status(full, 'draft')
                except SystemExit as e:
                    print(f"Warning: {e}. JSON state updated; file status may be stale.",
                          file=sys.stderr)
            pub['items'] = [i for i in pub['items'] if i.get('id') != aid]
            app['items'] = [i for i in app['items'] if i.get('id') != aid]
            paths['published'].write_text(json.dumps(pub, indent=2))
            paths['approved'].write_text(json.dumps(app, indent=2))

        rej['items'].append({
            "id": aid, "reason": reason,
            "rejected_by": _user(),
            "rejected_at": _now(),
        })
        paths['rejected'].write_text(json.dumps(rej, indent=2))
    print(f"Rejected: {aid} - {reason}")


def cmd_list(root: pathlib.Path, which: str) -> None:
    paths = _state_paths(root)
    p = paths.get(which)
    if p is None:
        raise SystemExit(f"Error: unknown list '{which}'. Use published|approved|rejected.")
    try:
        items = json.loads(p.read_text()).get('items', [])
    except FileNotFoundError:
        print(f"No {p.name} yet.")
        return

    if not items:
        labels = {
            'published': "Nothing published awaiting approval.",
            'approved':  "Nothing approved yet.",
            'rejected':  "Nothing rejected.",
        }
        print(labels[which])
        return

    if which == 'rejected':
        print(f"Rejected ({len(items)}):")
        for i in items:
            print(f"  [{i.get('id','?')}]  "
                  f"{i.get('rejected_at','?')[:10]}  "
                  f"by {i.get('rejected_by','?')}  "
                  f"- {i.get('reason','?')}")
    else:
        print(f"{which.capitalize()} ({len(items)}):")
        for i in items:
            print(f"  [{i.get('id','?')}]  "
                  f"{i.get('type','?'):15s}  "
                  f"{i.get('path','?')}")


# ── Entrypoint ────────────────────────────────────────────────────────────────

def _workbench_root() -> pathlib.Path:
    env = os.environ.get('WB_ROOT')
    if env:
        return pathlib.Path(env)
    # Fallback: script lives at <root>/scripts/lifecycle.py
    return pathlib.Path(__file__).resolve().parent.parent


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog='lifecycle.py', description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest='cmd', required=True)

    p_pub = sub.add_parser('publish', help='draft -> published')
    p_pub.add_argument('id')
    p_pub.add_argument('path')
    p_pub.add_argument('type')

    p_app = sub.add_parser('approve', help='published -> approved')
    p_app.add_argument('id')

    p_rej = sub.add_parser('reject', help='any -> draft (with reason)')
    p_rej.add_argument('id')
    p_rej.add_argument('reason')

    p_ls = sub.add_parser('list', help='list published|approved|rejected')
    p_ls.add_argument('which', choices=['published', 'approved', 'rejected'])

    args = parser.parse_args(argv)
    root = _workbench_root()

    if args.cmd == 'publish':
        cmd_publish(root, args.id, args.path, args.type)
    elif args.cmd == 'approve':
        cmd_approve(root, args.id)
    elif args.cmd == 'reject':
        cmd_reject(root, args.id, args.reason)
    elif args.cmd == 'list':
        cmd_list(root, args.which)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
