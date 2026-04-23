---
name: ralph-dispatch
description: Launch parallel autonomous ralph loops across workbench-registered repos. Cross-repo parallelism is the net-new behavior — ai-ralph native parallelism is within-repo only.
category: Engineering
---

# /ralph-dispatch

## When to use

Per-repo fix_plans exist and the user wants ralph to execute, ideally in parallel across multiple repos.

## What this skill adds over `ralph` alone

- ai-ralph has within-repo parallelism (`rpc.p N` spawns N agents working the same fix_plan).
- This skill adds across-repo parallelism: one ralph loop per registered repo, launched in the background, tracked by pidfile and per-repo log.

## Prerequisites

- `/ralph-workspace-plan` has been run for the PRDs in scope. This implies every upstream artifact (PRD, engineering spec, TDD, test spec) is already at `status: approved` with an entry in `.workbench-state/approved.json`. Dispatch inherits that gate — it does not re-check.
- `.ralph/fix_plan.md` exists and is non-empty in every target repo.
- Workbench is git-clean (no uncommitted artifacts) — prevents split-brain between workbench and in-flight ralph context.
- Each target repo is git-clean.

## Steps

1. **Sanity checks.** Refuse if any fail; print the specific failure.

   ```bash
   # workbench clean?
   git -C "$WB_ROOT" status --porcelain
   # each target repo clean?
   for r in <selected-repos>; do git -C "$WB_ROOT/repos/$r" status --porcelain; done
   # each has a fix_plan?
   for r in <selected-repos>; do
     [[ -f "$WB_ROOT/repos/$r/.ralph/fix_plan.md" ]] && [[ -s "$WB_ROOT/repos/$r/.ralph/fix_plan.md" ]] \
       || echo "fix_plan missing or empty: $r"
   done
   ```

2. **Select repos.** Default: all with a fix_plan. Override with `--repos r1,r2`.

3. **Pick engine.** Respect `DEVIN_DEFAULT`. Override with `--agent`.

4. **Launch:**

   ```bash
   ./scripts/ralph-dispatch.sh [--repos {csv}] [--agent {engine}]
   ```

5. **Report launched loops** — PIDs, log paths.

6. **On status requests**, read pidfiles + logs:

   ```
   | Repo | PID | State | Last line |
   ```

7. **On completion** (all PIDs gone):
   - Read last 30 lines of each log; extract exit code and any PR URL the loop printed.
   - Update `EPIC-PIPELINE.md` `Exec` column: `~` → `✓` on exit 0 with a PR surfaced, `✗` on non-zero.
   - Remove stale pidfiles.

## Output contract

- Background processes: one ralph loop per target repo.
- Writes: `ralph/logs/{repo}.log`, `ralph/{repo}.pid`, `ralph/dispatch.log` (summary).
- Modifies: `EPIC-PIPELINE.md` on completion.

## Do not

- Do not launch if workbench or any target repo is dirty.
- Do not silently ignore a non-zero exit. Surface the last 30 lines in the status summary.
- Do not leave stale pidfiles.
