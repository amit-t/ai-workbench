#!/usr/bin/env python3
"""Weekly steering drift digest.

Queries the GitHub org (passed via --org) for every repo with topic
`ai-workbench`, then lists every file under `steering.local/**` in each repo
(via the Git trees API), classifies each entry as add / supersede / remove
from its frontmatter, and emits a markdown digest suitable for an issue body.

Requires the `gh` CLI on PATH, authenticated with an org-installation token
passed in the environment as `GH_TOKEN`.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field

FM_FENCE = re.compile(r'(?s)^---\n(.*?)\n---\n?')


@dataclass
class OverlayFile:
    repo: str
    path: str
    rule_id: str
    title: str
    kind: str      # 'add' | 'supersede' | 'remove'
    affects: list[str] = field(default_factory=list)
    owner: str = ''


def gh(*args: str) -> str:
    """Run gh and return stdout. GH_TOKEN in env authenticates."""
    cmd = ['gh', *args]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(
            f"gh command failed: {' '.join(cmd)}\nstderr: {result.stderr}"
        )
    return result.stdout


def list_workbench_repos(org: str) -> list[dict]:
    """List repos in `org` with topic `ai-workbench`."""
    # Use the REST API for topic-filtered listing.
    query = f"org:{org} topic:ai-workbench"
    out = gh('api', f"/search/repositories?q={query}&per_page=100")
    data = json.loads(out)
    return data.get('items', [])


def list_overlay_files(repo_full: str) -> list[dict]:
    """Return the list of files under steering.local/ for a given repo."""
    # Get the default branch.
    meta = json.loads(gh('api', f'/repos/{repo_full}'))
    default = meta.get('default_branch', 'main')

    # Get the tree recursively.
    try:
        tree = json.loads(
            gh('api', f'/repos/{repo_full}/git/trees/{default}?recursive=1')
        )
    except SystemExit:
        return []
    return [
        t for t in tree.get('tree', [])
        if t.get('type') == 'blob' and t.get('path', '').startswith('steering.local/')
    ]


def fetch_file(repo_full: str, path: str) -> str:
    """Fetch a file's contents from the default branch."""
    out = gh('api', '-H', 'Accept: application/vnd.github.v3.raw',
             f'/repos/{repo_full}/contents/{path}')
    return out


def parse_frontmatter(text: str) -> dict:
    m = FM_FENCE.match(text)
    if not m:
        return {}
    raw = m.group(1)
    fields: dict[str, object] = {}
    for line in raw.splitlines():
        line = line.rstrip()
        if not line.strip() or ':' not in line:
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
    return fields


def classify(repo_full: str, path: str, fields: dict) -> OverlayFile:
    fname = path.rsplit('/', 1)[-1]
    rid = str(fields.get('id', fname))
    title = str(fields.get('title', '(no title)'))
    owner = str(fields.get('owner', ''))
    if fname.endswith('.removed.md'):
        kind = 'remove'
        affects = list(fields.get('removes') or [])
    elif fields.get('supersedes'):
        kind = 'supersede'
        affects = list(fields.get('supersedes') or [])
    else:
        kind = 'add'
        affects = [rid]
    return OverlayFile(
        repo=repo_full, path=path, rule_id=rid, title=title,
        kind=kind, affects=affects, owner=owner,
    )


def render(digests: list[OverlayFile]) -> str:
    out = []
    out.append("# Steering drift digest\n")
    if not digests:
        out.append("No team-local overrides in any stamped workbench this week.")
        return "\n".join(out)
    # Group by repo.
    by_repo: dict[str, list[OverlayFile]] = {}
    for d in digests:
        by_repo.setdefault(d.repo, []).append(d)
    for repo, items in sorted(by_repo.items()):
        added = [i for i in items if i.kind == 'add']
        superseded = [i for i in items if i.kind == 'supersede']
        removed = [i for i in items if i.kind == 'remove']
        out.append(f"## {repo}\n")
        out.append(
            f"added: {len(added)}, superseded: {len(superseded)}, removed: {len(removed)}\n"
        )
        for bucket, label in [(added, 'Added'), (superseded, 'Superseded'), (removed, 'Removed')]:
            if not bucket:
                continue
            out.append(f"**{label}:**\n")
            for i in bucket:
                affects = ", ".join(i.affects) or "(n/a)"
                out.append(f"- `{i.rule_id}` ({i.title}) — affects: {affects}, owner: `{i.owner}`, file: `{i.path}`")
            out.append("")
    out.append("---\n")
    out.append(
        "_Promote recurring overrides to the template via PR: "
        "clone `ai-workbench`, port `steering.local/<path>/<ID>.md` to "
        "`steering/<path>/<ID>.md` (drop the `-LOCAL` infix), open PR. "
        "CODEOWNERS for the target directory will review._"
    )
    return "\n".join(out)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument('--org', required=True)
    p.add_argument('--output', required=True)
    args = p.parse_args(argv)

    if not os.environ.get('GH_TOKEN'):
        print("GH_TOKEN not set; aborting.", file=sys.stderr)
        return 2

    repos = list_workbench_repos(args.org)
    digests: list[OverlayFile] = []
    for repo in repos:
        full = repo.get('full_name', '')
        for t in list_overlay_files(full):
            path = t.get('path')
            if not path or not path.endswith('.md'):
                continue
            try:
                body = fetch_file(full, path)
            except SystemExit:
                continue
            fm = parse_frontmatter(body)
            digests.append(classify(full, path, fm))

    with open(args.output, 'w') as f:
        f.write(render(digests))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
