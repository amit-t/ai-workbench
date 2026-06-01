---
name: wtd
description: What-To-Do — one-shot "what is my next action in this workbench?" Reads `.workbench-state/`, `project.conf`, and artifact frontmatter, walks the per-epic precondition chain (epic-context → PRD → eng-spec/TDD → BDD/test-cases/test-spec → ralph plan → dispatch), and prints the first gap as one concrete command per epic plus an overall top recommendation. Designed for engineers who land in a workbench mid-stream and do not know what step is next.
category: Cross-Cutting
relevant_topics: []
---

# /wtd

## When to use

- Engineer joins a workbench mid-stream and asks "what do I do?"
- Mid-session, after a publish or approve, to confirm the next move.
- Before opening Jira or pinging a counterpart — let the workbench tell you.
- Trimmer alternative to `/pmo-status` when you want one command, not a rollup.

## Prerequisites

- Workbench initialised (`project.conf` exists, `EPICS=(...)` non-empty, `.workbench-state/` present).
- `python3` available (the heavy lifting lives in `scripts/wtd.py`).

## Steps

0. **Load steering.** Read-only skill, no typed artifact, no Layer 2 rules. Layer 0 (loaded at session start) governs voice. No additional load required.

1. Run the alias:

   ```
   wb.wtd
   ```

   For a machine-readable payload (CI, scripting, downstream agents):

   ```
   wb.wtd --json
   ```

2. Read the **Top recommendation**. Run the command verbatim. Done.

3. If multiple epics are in scope, the **Also queued** block lists the next gap per epic in priority order. Stop at the first one you can act on.

## How recommendations are produced

The recommender walks the pipeline below for every epic in `project.conf EPICS=(...)`:

```
epic-context → PRD → eng-spec → TDD → BDD → test-cases → test-spec → ralph plan → dispatch
```

For each step it asks three questions in order, and emits a recommendation for the first "no":

| Question | If no → recommendation |
|----------|------------------------|
| Is the artifact in `.workbench-state/approved.json`? | If it is in `published.json` → "review and approve". Else → run the producing skill. |
| Is the upstream gate approved? | Block and surface the upstream gap instead. |
| Are all PRD-scoped artifacts approved for this PRD? | If yes → `/ralph-workspace-plan`, then `wb.ralph-dispatch`. |

Linkage between artifacts uses YAML frontmatter (`epic_id`, `prd_id`) when present, falling back to ID-prefix matching (`prd-EPIC-001-foo` → `spec-EPIC-001-foo`).

## Output shape

```
What to do next
===============

→ Next  (epic:EPIC-001)
  $ /prd-draft EPIC-001
  [EPIC-001] no PRD yet — draft one from the approved epic context.

Also queued:
  → [EPIC-002] missing TDD — generate it now.
    $ /tdd prd-EPIC-002-checkout
  ⛔ [EPIC-003] pull epic body and stamp it as draft context.
    $ /epic-intake EPIC-003
  → [prd-EPIC-001-foo] all artifacts approved — run workspace plan.
    $ /ralph-workspace-plan

Notes:
  • recent rejection: spec-EPIC-001-foo — TDD missing failure matrix
```

`⛔ BLOCKER` (top) or `⛔` (queued) marks a hard blocker — upstream gate not green. `→ Next` (top) or `→` (queued) is a normal next step.

Priority order (lower wins, ties broken by epic order in `project.conf`):

| Priority | Meaning |
|----------|---------|
| 5  | Workbench misconfigured (no EPICS, etc.) |
| 10 | Missing epic context |
| 15 | Missing PRD |
| 20–25 | Awaiting human approval (publish/approve gap) |
| 30 | Missing PRD-scoped artifact (spec, TDD, BDD, …) |
| 40 | Ready for `/ralph-workspace-plan` |
| 55 | Non-graphified repo(s) — surfaced as queued, never the top recommendation |
| 60 | Ready for `wb.ralph-dispatch` |
| 90 | Pipeline idle and clean — open a new epic |

## Output contract

- Read-only. Produces stdout report; does not modify any file.
- Exit 0 — recommendation printed (even when pipeline is fully idle).
- Exit 2 — workbench misconfigured (`.workbench-state/` missing).

## Do not

- Do not infer state from filesystem layout. `.workbench-state/{approved,published}.json` is the only gate.
- Do not auto-run the recommended command. The skill prints; the human runs.
- Do not duplicate `/pmo-status`. `wtd` answers "what next?", `pmo-status` answers "where does everything stand?".
