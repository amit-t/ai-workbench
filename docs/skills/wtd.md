---
title: /wtd
layout: default
eyebrow: Cross-Cutting
subtitle: "What-To-Do — one-shot 'what is my next action in this workbench?'. Walks the per-epic precondition chain and prints one concrete command. The trimmer cousin of `/pmo-status`."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output |
|-----|-------|---------------|--------|
| Cross-cutting | Status | None (read-only) | Stdout text or `--json` payload (no file writes) |

## When to Use

- You joined a workbench mid-stream and don't know what step is next.
- After a publish or approve, to confirm the next move without scanning `EPIC-PIPELINE.md`.
- Before opening Jira or pinging a counterpart — let the workbench tell you.
- When `/pmo-status` is more rollup than you need.

## Prerequisites

- Workbench initialised (`project.conf` exists, `EPICS=(...)` non-empty).
- `.workbench-state/` present (`wb.publish` auto-creates the ledgers on first use).

## Run

```zsh
wb.wtd            # text report
wb.wtd --json     # machine-readable
```

## How It Decides

For every epic in `project.conf EPICS=(...)` it walks this chain and emits a recommendation for the first gap:

```
epic-context → PRD → eng-spec → TDD → BDD → test-cases → test-spec → ralph plan → dispatch
```

| Question (in order) | If no → recommendation |
|---------------------|------------------------|
| Is artifact in `.workbench-state/approved.json`? | If in `published.json` → "review and approve". Else → run the producing skill. |
| Is upstream gate approved? | Block; surface the upstream gap instead. |
| All PRD-scoped artifacts approved for this PRD? | Yes → `/ralph-workspace-plan`, then `wb.ralph-dispatch`. |

Linkage uses YAML frontmatter (`epic_id`, `prd_id`) when present, falling back to ID-prefix matching (`prd-EPIC-001-foo` → `spec-EPIC-001-foo`).

## Output Shape

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
```

`⛔ BLOCKER` / `⛔` = blocker (upstream gate not green). `→ Next` / `→` = normal next step.

## Priority Order

Lower wins; ties broken by epic order in `project.conf`.

| Priority | Meaning |
|----------|---------|
| 5  | Workbench misconfigured (no EPICS, etc.) |
| 10 | Missing epic context |
| 15 | Missing PRD |
| 20–25 | Awaiting human approval (publish/approve gap) |
| 30 | Missing PRD-scoped artifact (spec, TDD, BDD, …) |
| 40 | Ready for `/ralph-workspace-plan` |
| 60 | Ready for `wb.ralph-dispatch` |
| 90 | Pipeline idle and clean — open a new epic |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Recommendation printed (including the "pipeline idle" case). |
| 2 | Workbench misconfigured (`.workbench-state/` missing). |

## Do Not

- Don't infer state from filesystem layout. `.workbench-state/{approved,published}.json` is the only gate.
- Don't auto-run the recommended command. The skill prints; the human runs.
- Don't duplicate `/pmo-status`. `wtd` answers "what next?"; `pmo-status` answers "where does everything stand?".

## Source

- Skill — [`skills/wtd/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/skills/wtd/SKILL.md)
- Engine — [`scripts/wtd.py`]({{ links.ai_workbench_repo }}/blob/main/scripts/wtd.py)
- Alias — [`aliases.sh`]({{ links.ai_workbench_repo }}/blob/main/aliases.sh) (`wb.wtd`)
- Workflows reference — [Workflows](../workflows.html)
