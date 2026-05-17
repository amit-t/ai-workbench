#!/usr/bin/env python3
"""What-To-Do (wtd) — single-shot next-action recommender for a workbench.

Reads only the source-of-truth state: project.conf, .workbench-state/{approved,
published,rejected}.json, EPIC-PIPELINE.md, and the YAML frontmatter of files
those ledgers point at. Walks the per-epic precondition chain (epic-context →
PRD → eng-spec / TDD → BDD / test-cases / test-spec → ralph plan → dispatch)
and prints the first gap as one concrete command per epic, plus an overall
top recommendation.

Does not infer state from filesystem layout. Does not write any file. Designed
to be called both directly (`python3 scripts/wtd.py`) and from the `wb.wtd`
alias.

Exit codes:
  0   recommendation printed (even when "everything is approved + dispatch idle")
  2   workbench misconfigured (no project.conf, no EPICS, no state dir)
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Iterable

# ── Pipeline definition ──────────────────────────────────────────────────────
# Ordered list of (artifact-type, label, downstream-skill, target-scope) tuples.
# `target-scope`:
#   "epic" — one artifact expected per epic (epic-context)
#   "prd"  — one artifact expected per approved PRD
PIPELINE_PRD = [
    ("eng-spec",    "Engineering spec",  "/eng-spec",        "prd"),
    ("tdd",         "TDD",               "/tdd",             "prd"),
    ("bdd",         "BDD features",      "/bdd-gen",         "prd"),
    ("test-cases",  "Test cases",        "/test-cases-gen",  "prd"),
    ("test-spec",   "Test spec",         "/test-spec",       "prd"),
]
# ERD / ADR are intentionally not gates — they are optional adjuncts.

FRONT_RE = re.compile(r"(?s)\A---\n(.*?)\n---")
KV_RE    = re.compile(r"^([A-Za-z_][\w-]*)\s*:\s*(.*?)\s*$", re.M)


# ── Data ─────────────────────────────────────────────────────────────────────
@dataclass
class StateEntry:
    id: str
    type: str
    path: str
    stage: str             # "approved" | "published"
    epic_id: str | None    # parsed from frontmatter
    prd_id:  str | None    # parsed from frontmatter (downstream artifacts)


@dataclass
class Recommendation:
    scope: str             # "epic:EPIC-001" or "prd:prd-EPIC-001-foo" or "global"
    headline: str          # one-line human summary
    command: str           # exact command to run
    blocker: bool = False  # blocked on upstream gate
    priority: int = 50     # lower wins; 10=critical, 50=normal, 90=nice-to-have

    def render(self) -> str:
        prefix = "⛔" if self.blocker else "→"
        return f"  {prefix} {self.headline}\n    $ {self.command}"


# ── IO helpers ───────────────────────────────────────────────────────────────
def _wb_root() -> pathlib.Path:
    env = os.environ.get("WB_ROOT")
    if env:
        return pathlib.Path(env)
    return pathlib.Path(__file__).resolve().parent.parent


def _load_json(p: pathlib.Path) -> dict:
    try:
        return json.loads(p.read_text())
    except FileNotFoundError:
        return {"items": []}


def _parse_frontmatter(full: pathlib.Path) -> dict[str, str]:
    if not full.is_file():
        return {}
    try:
        text = full.read_text(errors="replace")
    except OSError:
        return {}
    m = FRONT_RE.match(text)
    if not m:
        # Gherkin / non-YAML — scan header comments
        kv: dict[str, str] = {}
        for line in text.splitlines()[:30]:
            line = line.strip()
            if line.startswith("#"):
                line = line.lstrip("#").strip()
                mm = KV_RE.match(line)
                if mm:
                    kv[mm.group(1)] = mm.group(2)
            elif line and not line.startswith("Feature"):
                continue
        return kv
    front = m.group(1)
    return {mm.group(1): mm.group(2) for mm in KV_RE.finditer(front)}


def _load_state(root: pathlib.Path) -> list[StateEntry]:
    state_dir = root / ".workbench-state"
    entries: list[StateEntry] = []
    for stage in ("approved", "published"):
        data = _load_json(state_dir / f"{stage}.json")
        for item in data.get("items", []):
            front = _parse_frontmatter(root / item["path"]) if item.get("path") else {}
            entries.append(StateEntry(
                id=item.get("id", "?"),
                type=item.get("type", "?"),
                path=item.get("path", ""),
                stage=stage,
                epic_id=front.get("epic_id") or front.get("epic") or None,
                prd_id=front.get("prd_id") or None,
            ))
    return entries


def _load_epics(root: pathlib.Path) -> list[str]:
    pc = root / "project.conf"
    if not pc.is_file():
        return []
    try:
        out = subprocess.check_output(
            ["bash", "-c", f". {shlex.quote(str(pc))} && printf '%s\\n' \"${{EPICS[@]}}\""],
            text=True,
        )
    except subprocess.CalledProcessError:
        return []
    return [line.strip() for line in out.splitlines() if line.strip()]


def _load_repos(root: pathlib.Path) -> list[str]:
    pc = root / "project.conf"
    if not pc.is_file():
        return []
    try:
        out = subprocess.check_output(
            ["bash", "-c",
             f". {shlex.quote(str(pc))} && for r in \"${{REPOS[@]}}\"; do echo \"$r\"; done"],
            text=True,
        )
    except subprocess.CalledProcessError:
        return []
    repos: list[str] = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        # Format: name=<name>;url=<...>;role=<...>
        for kv in line.split(";"):
            if kv.startswith("name="):
                repos.append(kv.split("=", 1)[1].strip())
                break
    return repos


# ── Linkage ──────────────────────────────────────────────────────────────────
def _epic_for(entry: StateEntry, epics: list[str]) -> str | None:
    """Return the EPIC id this entry belongs to, by frontmatter or id-prefix."""
    if entry.epic_id and entry.epic_id in epics:
        return entry.epic_id
    # PRD ids often look like prd-EPIC-001-slug. Match the longest epic id that
    # is a substring of the artifact id.
    for ep in sorted(epics, key=len, reverse=True):
        if ep in entry.id:
            return ep
    return None


def _prd_id_for(entry: StateEntry, prds_by_id: dict[str, StateEntry]) -> str | None:
    """Match a downstream artifact (spec/tdd/bdd/...) back to its parent PRD."""
    if entry.prd_id and entry.prd_id in prds_by_id:
        return entry.prd_id
    # Heuristic: trailing slug matches the PRD id's trailing slug.
    # prd-EPIC-001-foo, spec-EPIC-001-foo → match.
    parts = entry.id.split("-")
    if len(parts) >= 2:
        for prd_id in prds_by_id:
            # match by suffix slug, ignoring the leading "prd-"
            prd_tail = prd_id[len("prd-"):] if prd_id.startswith("prd-") else prd_id
            if entry.id.endswith(prd_tail):
                return prd_id
    return None


# ── Recommendation engine ────────────────────────────────────────────────────
def _recommend(root: pathlib.Path) -> tuple[list[Recommendation], list[str]]:
    notes: list[str] = []
    epics = _load_epics(root)
    if not epics:
        return ([Recommendation(
            scope="global",
            headline="No epics in scope. Edit project.conf and append to EPICS=(...).",
            command="$EDITOR project.conf",
            blocker=True,
            priority=5,
        )], notes)

    repos = _load_repos(root)
    entries = _load_state(root)
    rejected = _load_json(root / ".workbench-state" / "rejected.json").get("items", [])

    by_stage: dict[tuple[str, str], list[StateEntry]] = {}
    for e in entries:
        by_stage.setdefault((e.stage, e.type), []).append(e)

    approved_by_id  = {e.id: e for e in entries if e.stage == "approved"}
    published_by_id = {e.id: e for e in entries if e.stage == "published"}

    recs: list[Recommendation] = []

    # Surface any rejection from the last 7 entries — these block their downstream chain.
    for r in rejected[-5:]:
        notes.append(f"recent rejection: {r.get('id')} — {r.get('reason','?')}")

    for ep in epics:
        # 1. epic-context approved?
        epic_ctx_id = f"epic-{ep}"
        epic_approved = epic_ctx_id in approved_by_id
        epic_published = epic_ctx_id in published_by_id

        if not epic_approved:
            if epic_published:
                recs.append(Recommendation(
                    scope=f"epic:{ep}",
                    headline=f"[{ep}] epic-context awaiting approval — review then approve.",
                    command=f"wb.approve {epic_ctx_id}",
                    priority=20,
                ))
            else:
                recs.append(Recommendation(
                    scope=f"epic:{ep}",
                    headline=f"[{ep}] pull epic body and stamp it as draft context.",
                    command=f"/epic-intake {ep}",
                    blocker=True,
                    priority=10,
                ))
            continue

        # 2. any PRD approved for this epic?
        prds_approved  = [e for e in approved_by_id.values()
                          if e.type == "prd" and _epic_for(e, [ep]) == ep]
        prds_published = [e for e in published_by_id.values()
                          if e.type == "prd" and _epic_for(e, [ep]) == ep]

        if not prds_approved:
            if prds_published:
                ids = ", ".join(e.id for e in prds_published)
                recs.append(Recommendation(
                    scope=f"epic:{ep}",
                    headline=f"[{ep}] PRD(s) awaiting approval — run review panel then approve.",
                    command=f"/prd-review-panel {prds_published[0].id}",
                    priority=20,
                ))
            else:
                recs.append(Recommendation(
                    scope=f"epic:{ep}",
                    headline=f"[{ep}] no PRD yet — draft one from the approved epic context.",
                    command=f"/prd-draft {ep}",
                    blocker=True,
                    priority=15,
                ))
            continue

        # 3. for each approved PRD, walk the downstream chain
        prds_by_id = {e.id: e for e in prds_approved}
        for prd in prds_approved:
            gap_found = False
            for atype, label, skill, _scope in PIPELINE_PRD:
                # is there an approved artifact of this type tied to this PRD?
                children_approved = [
                    e for e in approved_by_id.values()
                    if e.type == atype and _prd_id_for(e, prds_by_id) == prd.id
                ]
                children_published = [
                    e for e in published_by_id.values()
                    if e.type == atype and _prd_id_for(e, prds_by_id) == prd.id
                ]
                if children_approved:
                    continue
                if children_published:
                    eids = ", ".join(e.id for e in children_published)
                    recs.append(Recommendation(
                        scope=f"prd:{prd.id}",
                        headline=f"[{prd.id}] {label} awaiting approval ({eids}).",
                        command=f"wb.approve {children_published[0].id}",
                        priority=25,
                    ))
                else:
                    recs.append(Recommendation(
                        scope=f"prd:{prd.id}",
                        headline=f"[{prd.id}] missing {label} — generate it now.",
                        command=f"{skill} {prd.id}",
                        blocker=(atype in ("eng-spec", "tdd")),
                        priority=30,
                    ))
                gap_found = True
                break  # first gap per PRD wins
            if not gap_found:
                # all PRD-scoped artifacts approved — check ralph readiness
                fixplan = root / "repos" / ".ralph" / "fix_plan.md"
                if not fixplan.is_file():
                    recs.append(Recommendation(
                        scope=f"prd:{prd.id}",
                        headline=f"[{prd.id}] all artifacts approved — run workspace plan.",
                        command="/ralph-workspace-plan",
                        priority=40,
                    ))
                else:
                    recs.append(Recommendation(
                        scope=f"prd:{prd.id}",
                        headline=f"[{prd.id}] fix_plan ready — dispatch ralph across {len(repos) or '?'} repo(s).",
                        command="wb.ralph-dispatch",
                        priority=60,
                    ))

    if not recs:
        recs.append(Recommendation(
            scope="global",
            headline="Pipeline idle and clean. Pick a new epic or extend coverage.",
            command="/pmo-status",
            priority=90,
        ))

    recs.sort(key=lambda r: r.priority)
    return (recs, notes)


# ── Rendering ────────────────────────────────────────────────────────────────
def _render(recs: list[Recommendation], notes: list[str], fmt: str) -> str:
    if fmt == "json":
        return json.dumps({
            "recommendations": [
                {
                    "scope": r.scope, "headline": r.headline,
                    "command": r.command, "blocker": r.blocker, "priority": r.priority,
                } for r in recs
            ],
            "notes": notes,
        }, indent=2)

    top = recs[0]
    out: list[str] = []
    out.append("What to do next")
    out.append("===============")
    out.append("")
    marker = "⛔ BLOCKER" if top.blocker else "→ Next"
    out.append(f"{marker}  ({top.scope})")
    out.append(f"  $ {top.command}")
    out.append(f"  {top.headline}")
    out.append("")
    if len(recs) > 1:
        out.append("Also queued:")
        for r in recs[1:6]:
            out.append(r.render())
        if len(recs) > 6:
            out.append(f"  … {len(recs) - 6} more (run with --json for full list)")
        out.append("")
    if notes:
        out.append("Notes:")
        for n in notes:
            out.append(f"  • {n}")
        out.append("")
    return "\n".join(out)


# ── Entrypoint ───────────────────────────────────────────────────────────────
def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(prog="wtd", description=__doc__.splitlines()[0])
    p.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    p.add_argument("--root", default=None, help="override workbench root")
    args = p.parse_args(argv)

    root = pathlib.Path(args.root) if args.root else _wb_root()
    if not (root / ".workbench-state").is_dir():
        print(f"wtd: {root} is not a workbench (no .workbench-state/).", file=sys.stderr)
        return 2

    # Template-dev detection: ai-workbench template repo itself, not a stamped wb.
    if not (root / "project.conf").is_file() and (root / "SESSION-HANDOFF.md").is_file():
        print(
            f"wtd: {root} looks like the ai-workbench template repo (no project.conf, "
            f"SESSION-HANDOFF.md present). /wtd is a stamped-wb command — "
            f"cd into a stamped workbench (one with project.conf), or read SESSION-HANDOFF.md "
            f"for template-dev next steps.",
            file=sys.stderr,
        )
        return 2

    recs, notes = _recommend(root)
    print(_render(recs, notes, "json" if args.json else "text"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
