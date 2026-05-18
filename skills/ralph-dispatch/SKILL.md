---
name: ralph-dispatch
description: Drive `wb.ralph-dispatch`. Runs ralph in workspace mode with native cross-repo parallelism. Workbench preflights, syncs context, and shells out; ralph owns the loop, parallelism, and PR creation.
category: Engineering
relevant_topics: []
---

# /ralph-dispatch

## When to use

Per-repo fix_plans exist (workspace mode: sections of `repos/.ralph/fix_plan.md`; per-repo mode: one fix_plan per repo) and the user wants ralph to execute, with cross-repo parallelism.

## What this skill adds over `ralph` alone

`ralph --workspace --parallel N` natively iterates the workspace fix_plan and runs N loops in parallel. This skill is the workbench-side wrapper that:

- Preflights `ralph enable --workspace` via `wb.ralph-enable-check`.
- Resolves N from CLI flag, env `WB_RALPH_PARALLEL`, or `project.conf` (default `min(len(REPOS), 4)`).
- Resolves the engine from CLI flag, env `WB_RALPH_ENGINE`, or `project.conf`.
- Resolves continuous-mode knobs (M, K, respawn-delay, no-tabs) from CLI flag, env, or `project.conf`.
- Exports `WORKSPACE_ROOT=$WB_ROOT/repos` so ralph picks up the right context dir.
- Capability-gates continuous-mode forwarding against `ralph --help`, failing fast if the installed ralph predates `--parallel N M`.
- Surfaces `--status`: lists open ralph-authored PRs across registered repos plus a tail of recent ralph worker logs.

Workbench does not re-implement the loop, parallelism, or PR creation; that is `ai-ralph`'s job.

## Continuous mode

For long unattended runs over a deep workspace fix_plan, engage ralph's **continuous mode**: workers stay saturated up to N concurrent until M total attempts have been spent (success or failure both count), or the queue drains.

Engagement: set M via `--max-tasks M` (named, preferred), positional `--parallel N M` (mirrors ralph's own CLI), env `WB_RALPH_MAX_TASKS`, or `project.conf WB_RALPH_MAX_TASKS`. Without M, dispatch runs in V1 batch mode (byte-identical to prior behavior).

When to engage continuous mode:
- The workspace fix_plan has more than ~10 pending tasks and you want one orchestrator to drain it, not a one-shot batch.
- Tasks are heterogeneous and individual durations are unpredictable (continuous keeps N busy; batch leaves idle workers).
- You want a hard cap on total attempts (cost / time control).

Tuning knobs (inert without M):
- `--max-task-attempts K` (env `WB_RALPH_MAX_TASK_ATTEMPTS`) — per-task retry cap. After K failures on the same task ralph skip-lists it.
- `--respawn-delay SEC` (env `WB_RALPH_RESPAWN_DELAY`) — cooldown between worker replacements. Useful when the engine throttles session creation.
- `--no-tabs` (env `WB_RALPH_DISABLE_TABS=true`) — force the single-pane orchestrator. Default is per-worker terminal tabs on iTerm2 / VS Code / Windsurf / Cursor.

Examples:

```bash
# 3 workers, 30 attempts, default per-worker tabs
wb.ralph-dispatch --parallel 3 --max-tasks 30

# Positional form (ralph's native shape)
wb.ralph-dispatch --parallel 3 30

# Single-pane, with 2 retries per task and a 5s respawn cooldown
wb.ralph-dispatch --parallel 3 30 --no-tabs --max-task-attempts 2 --respawn-delay 5

# Drive from project.conf so all team members run the same shape
echo 'WB_RALPH_MAX_TASKS="50"' >> project.conf
wb.ralph-dispatch --parallel 4
```

Mode is printed in the banner: `[wb.ralph-dispatch] mode=continuous parallel=3 max_tasks=30 ...`. If you intended continuous but the banner says `mode=batch`, M did not resolve — check the resolution chain.

## Prerequisites

- `/ralph-workspace-plan` has been run for the PRDs in scope. This implies every upstream artifact (PRD, engineering spec, TDD, test spec) is at `status: approved` with an entry in `.workbench-state/approved.json`. Dispatch inherits that gate; it does not re-check.
- `repos/.ralph/fix_plan.md` (workspace mode) is non-empty, OR `.ralph/fix_plan.md` exists and is non-empty in every target repo (per-repo mode).
- `ralph enable --workspace` ran once at `$WB_ROOT/repos/`. `wb.ralph-dispatch` calls `wb.ralph-enable-check` itself; failure aborts the run.

> Note. Per-repo subset selection (`--repos a,b`) is **not yet wired**. It is a parked follow-up (Plan E2) waiting on an upstream `ralph --workspace --repos` filter. Today, scoping a partial dispatch means pre-editing `repos/.ralph/fix_plan.md` to remove sections you do not want executed.

## Steps

0. **Load steering.** This skill shells out to `ralph --workspace` and does not produce a typed workbench artifact, so no Layer 2 artifact rules apply. Layer 0 (golden, loaded at session start) governs voice and the rule against bypassing the upstream approval gate. Each fix_plan task ralph executes was generated under per-artifact Layer 2 steering already (PRD, eng-spec, TDD, test spec drafted under `wb.steering artifact:<type>`). The M4 drift footer staged at `repos/.ralph/pr_footer.md` by `sync-context.sh` is what ralph appends to PR bodies, so reviewers see overlay drift on every dispatch. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none by default).

1. **Sanity checks.** Refuse if any fail; print the specific failure.

   ```bash
   # workbench clean?
   git -C "$WB_ROOT" status --porcelain
   # each registered repo clean?
   for r in <selected-repos>; do git -C "$WB_ROOT/repos/$r" status --porcelain; done
   # workspace fix_plan has content?
   [[ -s "$WB_ROOT/repos/.ralph/fix_plan.md" ]] || echo "workspace fix_plan missing or empty"
   ```

2. **Resolve flags.** Engine and parallelism come from project.conf by default; only set `--parallel` / `--engine` when the user wants to override.

3. **Launch.** Always call through the alias, never the script path:

   ```bash
   wb.ralph-dispatch                        # ralph --workspace --parallel N
   wb.ralph-dispatch --parallel 2
   wb.ralph-dispatch --engine claude
   wb.ralph-dispatch --dry-run              # preview the ralph command, do not execute
   ```

   The alias resolves to `scripts/ralph-dispatch.sh`, which preflights `wb.ralph-enable-check` and then runs `(cd $WB_ROOT/repos && WORKSPACE_ROOT=$WB_ROOT/repos ralph --workspace --parallel N)`. The `--engine` flag is passed through only when the installed ralph reports it.

4. **Watch progress.** Use the dedicated status flag; do not invent your own log scraping:

   ```bash
   wb.ralph-dispatch --status
   ```

   Output lists open ralph-authored PRs (`gh pr list -R {repo} --search 'head:rp-'`) per registered repo, and a tail of the five most recent files under `repos/.ralph/logs/parallel/`.

5. **On completion.** Once `wb.ralph-dispatch --status` shows no active workers and PRs have surfaced:
   - Read the latest ralph worker logs to confirm exit codes.
   - Update `EPIC-PIPELINE.md` `Exec` column: `~` → `✓` on success with a PR surfaced, `✗` on non-zero exit.
   - For PRs that ralph created with team steering overrides applied, confirm the M4 drift footer is present in the PR body (ralph appends it from `repos/.ralph/pr_footer.md`). If the deployed ralph predates the `pr-footer-append` change, run `wb.ralph-annotate [--since 30m]` as the post-hoc fallback.

## Single-repo debugging

For one-repo iteration outside dispatch, drop the wrapper and use ralph directly:

```bash
(cd "$WB_ROOT/repos/<name>" && ralph --live --monitor)
```

There is no `wb.ralph-loop`. It was retired with the V1 adapter ship.

## Output contract

- Foreground process: `ralph --workspace --parallel N` running at `$WB_ROOT/repos/`.
- Writes (ralph-owned, do not edit from workbench): `repos/.ralph/logs/parallel/*.log`, ralph-authored PRs on each target repo.
- Modifies: `EPIC-PIPELINE.md` on completion.

## Do not

- Do not launch if workbench or any target repo is dirty.
- Do not call `scripts/ralph-dispatch.sh` directly. Use `wb.ralph-dispatch` so the preflight runs and `WORKSPACE_ROOT` is exported.
- Do not write into `repos/.ralph/`. That tree is ralph-owned; workbench only stages `repos/.ralph/pr_footer.md` from `sync-context.sh`.
- Do not silently ignore a non-zero ralph exit. Surface the relevant log tail in the status summary.
- Do not re-implement parallel scheduling, pidfiles, or PR scraping. `--status` already surfaces PRs and logs; extend ralph if more is needed.
