---
name: ralph-workspace-plan
description: Drive scripts/ralph-plan.sh — sync approved context, invoke ralph workspace-mode plan, produce per-repo fix_plans + workbench rollup. Gated on three-stage approvals.
category: Engineering
---

# /ralph-workspace-plan

## When to use

All upstream artifacts are approved and the user wants per-repo fix_plans so ralph can execute.

## Prerequisites

- Every PRD to be planned has `status: approved` AND an entry in `.workbench-state/approved.json`.
- Every relevant engineering SPEC, TDD, and test spec has `status: approved` (see Hard gate below for the exact rules).
- `project.conf REPOS` lists at least one target repo.

## Hard gate — refuse unless all true

For every PRD being planned:

1. PRD is at `approved` AND `approved.json` has `PRD-{NNN}`.
2. For every target repo with `role=service` or `role=shared-lib`: the SPEC is `approved`, and if a TDD exists it is `approved`.
3. For every target repo with `role=automation-tests`: the TSD is `approved` and the test-case set is `approved`.

If any check fails, print:

> Gate failure. Missing approvals: {list}. Run `wb.publish` then `wb.approve` after review.

and stop.

## What this skill adds over `ralph-plan` alone

`ai-ralph`'s own plan mode reads requirements and produces a fix_plan. This skill adds:

1. **Approval gate** — refuses to plan unless upstream artifacts are `approved` in workbench state.
2. **Context routing** — calls `sync-context.sh` so each repo sees only the role-appropriate artifacts before ralph plans.
3. **Workspace rollup** — aggregates per-repo fix_plans into `ralph/workspace-plan.md` for human overview.

Without those, ralph would either plan off stale context or skip gate enforcement.

## Steps

1. **Scope.** Ask:
   - PRDs to include (default: all approved PRDs with empty `fix_plan repos` column in `EPIC-PIPELINE.md`).
   - Target repos (default: all in `project.conf REPOS`).
   - Engine (default: `DEVIN_DEFAULT` from project.conf).

2. **Run the adapter:**

   ```bash
   ./scripts/ralph-plan.sh [--agent {engine}] [{repo}]
   ```

3. **Read per-repo fix_plans** and write a rollup to `ralph/workspace-plan.md`:

   ```markdown
   # Workspace plan rollup — {today}

   ## PRDs planned
   - PRD-{NNN}: {title}

   ## Tasks per repo
   | Repo | Role | Tasks | File |
   |------|------|-------|------|
   | {repo-1} | service | {N} | repos/{repo-1}/.ralph/fix_plan.md |
   | {repo-2} | automation-tests | {M} | repos/{repo-2}/.ralph/fix_plan.md |

   ## Risks / blockers noted by ralph
   - {list, or "none"}
   ```

4. **Update `EPIC-PIPELINE.md`.** Populate `fix_plan repos` column comma-joined; set `Exec` to `~`.

5. **Next step suggestion:** `/ralph-dispatch` to launch loops.

## Output contract

- Overwrites: `ralph/workspace-plan.md`.
- Per-repo `.ralph/fix_plan.md` written by the adapter.
- Modifies: `EPIC-PIPELINE.md`.

## Do not

- Do not bypass the approval gate. Even "urgent" is not a reason.
- Do not switch engines mid-run. Pick one; rerun if needed.
