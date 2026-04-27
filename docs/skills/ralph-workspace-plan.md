---
title: /ralph-workspace-plan
layout: default
eyebrow: Orchestrator
subtitle: "Sync approved context, invoke ralph workspace-mode plan, produce per-repo fix_plans + workbench rollup. Gated on three-stage approvals."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| Orchestrator | Execution plan | PRD + SPEC + TDD + TSD all approved | `repos/*/ai/fix_plan.md` per repo + `ralph/workspace-plan.md` rollup | `/ralph-dispatch` |

## When to Use

All upstream artifacts are approved and user wants per-repo fix_plans so ralph can execute.

## Hard Gate — Refuses Unless All True

For every PRD being planned:

1. PRD `approved` AND `approved.json` has `PRD-{NNN}`.
2. For every target repo with `role=service` or `shared-lib`: SPEC `approved`; if a TDD exists, TDD `approved`.
3. For every target repo with `role=automation-tests`: TSD `approved` and test-case set `approved`.

Any failure → print `Gate failure. Missing approvals: {list}. Run wb.publish then wb.approve after review.` and stop.

## What This Skill Adds Over `ralph-plan` Alone

| Feature | Source |
|---------|--------|
| Plan generation | ai-ralph native |
| Approval gate | **this skill** |
| Context routing via `sync-context.sh` | **this skill** |
| Workspace rollup `ralph/workspace-plan.md` | **this skill** |

## Protocol

1. Scope — ask PRDs (default: approved PRDs with empty `fix_plan repos` column in `EPIC-PIPELINE.md`), target repos (default: all), engine (default: `DEVIN_DEFAULT`).
2. Run adapter: `./scripts/ralph-plan.sh [--agent {engine}] [{repo}]`.
3. Aggregate per-repo fix_plans into `ralph/workspace-plan.md` rollup — PRDs planned, tasks per repo table, risks/blockers.
4. Update `EPIC-PIPELINE.md` — populate `fix_plan repos`, set `Exec` to `~`.
5. Suggest next: `/ralph-dispatch`.

## Do Not

- Bypass approval gate. "Urgent" is not a reason.
- Switch engines mid-run. Pick one; rerun if needed.

## Source

[`skills/ralph-workspace-plan/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/skills/ralph-workspace-plan/SKILL.md)
