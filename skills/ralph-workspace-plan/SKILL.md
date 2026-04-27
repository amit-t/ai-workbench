---
name: ralph-workspace-plan
description: Drive `wb.ralph-plan`. Sync approved context, run ralph-plan in workspace mode (or per-repo fallback), produce per-repo fix_plans plus a workbench rollup. Gated on three-stage approvals.
category: Engineering
---

# /ralph-workspace-plan

## When to use

All upstream artifacts are approved and the user wants per-repo fix_plans so ralph can execute.

## Prerequisites

- Every PRD to be planned has `status: approved` AND an entry in `.workbench-state/approved.json`.
- Every relevant engineering SPEC, TDD, and test spec has `status: approved` (see Hard gate below for the exact rules).
- `project.conf REPOS` lists at least one target repo.
- `ralph enable --workspace` has run once at `$WB_ROOT/repos/`. `wb.ralph-enable-check` is the preflight; it is invoked automatically by `wb.ralph-plan`.

## Hard gate (refuse unless all true)

For every PRD being planned:

1. PRD is at `approved` AND `approved.json` has `PRD-{NNN}`.
2. For every target repo with `role=service` or `role=shared-lib`: the SPEC is `approved`, and if a TDD exists it is `approved`.
3. For every target repo with `role=automation-tests`: the TSD is `approved` and the test-case set is `approved`.

If any check fails, print:

> Gate failure. Missing approvals: {list}. Run `wb.publish` then `wb.approve` after review.

and stop.

## What this skill adds over `ralph-plan` alone

Upstream `ralph-plan --workspace` reads requirements and emits a fix_plan. This skill adds:

1. **Approval gate.** Refuses to plan unless upstream artifacts are `approved` in workbench state.
2. **Context routing.** `sync-context.sh` runs first so each repo sees only the role-appropriate artifacts before ralph plans, and the M4 drift footer is staged at `repos/.ralph/pr_footer.md`.
3. **Mode resolver.** Picks workspace mode by default and falls back to per-repo for older ralph installs (CLI flag > env `WB_RALPH_PLAN_MODE` > `project.conf RALPH_PLAN_MODE` > auto-detect from `ralph-plan --help`).
4. **Workspace rollup.** Aggregates per-repo fix_plans into `ralph/workspace-plan.md` for human overview.

Without those, ralph would either plan off stale context or skip gate enforcement.

## Steps

1. **Scope.** Ask:
   - PRDs to include (default: all approved PRDs with empty `fix_plan repos` column in `EPIC-PIPELINE.md`).
   - Target repos (default: all in `project.conf REPOS`).
   - Engine (default: `RALPH_PLAN_ENGINE` from `project.conf`, falls back to `devin`).
   - Mode (default: `auto`; pick `workspace` or `per-repo` only when the user wants to override).

2. **Run the adapter.** Always call through the alias, never the script path:

   ```bash
   wb.ralph-plan                               # workspace mode by default
   wb.ralph-plan --mode per-repo               # explicit fallback
   wb.ralph-plan --engine claude --thinking hard
   wb.ralph-plan <repo>                        # only meaningful in per-repo mode
   wb.ralph-plan --dry-run                     # preview the ralph command, do not execute
   ```

   The alias resolves to `scripts/ralph-plan.sh`, which preflights `wb.ralph-enable-check`, runs `sync-context.sh`, and invokes ralph-plan with the resolved engine, thinking depth, and mode. In workspace mode the call is `(cd $WB_ROOT/repos && ralph-plan --workspace --engine {engine} --thinking {thinking})` and ralph writes the per-repo `## <repo-name>` sections inside `repos/.ralph/fix_plan.md`. In per-repo mode the script loops `project.conf REPOS` and runs `ralph-plan` once per repo.

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

   In workspace mode the per-repo files are sections of `repos/.ralph/fix_plan.md`; cite the section anchor in the table when that is the case.

4. **Update `EPIC-PIPELINE.md`.** Populate `fix_plan repos` column comma-joined; set `Exec` to `~`.

5. **Next step suggestion:** `/ralph-dispatch` to launch loops via `wb.ralph-dispatch`.

## Output contract

- Overwrites: `ralph/workspace-plan.md`.
- Per-repo `.ralph/fix_plan.md` (or `repos/.ralph/fix_plan.md` sections in workspace mode) written by ralph itself.
- Modifies: `EPIC-PIPELINE.md`.

## Do not

- Do not bypass the approval gate. Even "urgent" is not a reason.
- Do not switch engines mid-run. Pick one; rerun if needed.
- Do not call `scripts/ralph-plan.sh` directly. Use `wb.ralph-plan` so context sync and the enable preflight run first.
- Do not re-implement ralph internals (mode handling, parallelism, PR creation). Workbench only wraps.
