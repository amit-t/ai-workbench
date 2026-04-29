#!/usr/bin/env python3
"""Validate changed artifact files in a workbench PR.

Usage:
  wb-ci-validate.py <path> [<path> ...]
  wb-ci-validate.py --stdin              # read paths from stdin, one per line

Maps each path to an artifact type by directory prefix and runs
scripts/validate-artifact.py for it. Paths outside the known artifact
directories are skipped. README.md and INDEX.md inside artifact directories
are skipped (they are documentation, not artifacts).

Designed for use from .github/workflows/wb-ci.yml. The workflow generates
the path list with `git diff --name-only --diff-filter=AM
origin/<base>...HEAD` and pipes it in via --stdin.

Exits 0 if every routable file passes (or if no routable files were given).
Exits 1 if any routable file fails validation.
"""
from __future__ import annotations

import os
import pathlib
import subprocess
import sys

WB_ROOT = pathlib.Path(os.environ.get('WB_ROOT',
    pathlib.Path(__file__).resolve().parent.parent))

VALIDATE = WB_ROOT / 'scripts' / 'validate-artifact.py'

# Ordered (directory prefix, artifact type) tuples. First match wins. Prefixes
# end with '/' so a path like product/outputs/prds/PRD-001.md classifies as
# `prd` but product/context-library/epics/EPIC-X.md classifies as
# `epic-context`.
ARTIFACT_DIRS: list[tuple[str, str]] = [
    ('product/outputs/prds/',         'prd'),
    ('product/context-library/epics/', 'epic-context'),
    ('engineering/outputs/specs/',     'eng-spec'),
    ('engineering/outputs/tdd/',       'tdd'),
    ('engineering/outputs/erd/',       'erd'),
    ('engineering/outputs/adrs/',      'adr'),
    ('qa/outputs/bdd/',                'bdd'),
    ('qa/outputs/test-cases/',         'test-cases'),
    ('qa/outputs/test-spec/',          'test-spec'),
    ('qa/outputs/test-erd/',           'test-erd'),
]

SKIP_NAMES = {'README.md', 'INDEX.md'}


def classify(path: str) -> str | None:
    """Return the artifact type for `path`, or None if `path` is not routable.

    BDD files use the `.feature` extension; everything else uses `.md`.
    """
    p = path.strip()
    if not p:
        return None
    name = pathlib.Path(p).name
    if name in SKIP_NAMES:
        return None
    for prefix, atype in ARTIFACT_DIRS:
        if not p.startswith(prefix):
            continue
        if atype == 'bdd':
            return atype if p.endswith('.feature') else None
        return atype if p.endswith('.md') else None
    return None


def main(argv: list[str]) -> int:
    paths: list[str] = []
    if argv and argv[0] == '--stdin':
        for line in sys.stdin:
            paths.append(line.rstrip('\n'))
    else:
        paths = list(argv)

    failures = 0
    routed = 0
    skipped = 0

    for p in paths:
        atype = classify(p)
        if atype is None:
            skipped += 1
            continue
        full = WB_ROOT / p
        if not full.is_file():
            # File no longer exists in the worktree (e.g. renamed). Treat as
            # skipped rather than failed; the rename target gets validated as
            # a separate path in the diff.
            skipped += 1
            continue
        routed += 1
        result = subprocess.run(
            ['python3', str(VALIDATE), p, atype],
            capture_output=True, text=True, cwd=str(WB_ROOT),
        )
        if result.returncode == 0:
            print(f'  ok   {p} ({atype})')
        else:
            failures += 1
            print(f'  FAIL {p} ({atype})')
            for stream in (result.stdout, result.stderr):
                for line in (stream or '').splitlines():
                    print(f'       {line}')

    print()
    if routed == 0:
        print(f'wb-ci-validate: no artifact files in change set ({skipped} skipped)')
        return 0
    print(f'wb-ci-validate: {routed - failures}/{routed} files passed '
          f'({skipped} skipped)')
    return 1 if failures > 0 else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
