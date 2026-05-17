---
title: Ralph Integration
layout: default
eyebrow: Ralph
---

## What ai-ralph Is

**ai-ralph** is a multi-engine autonomous AI development loop: given a `fix_plan.md` inside a code repo, it drives a Claude / Devin / Codex agent in a controlled loop, committing incrementally, until the plan is done. The workbench points at an `ai-ralph` fork under your org — e.g. `<your-org>/ai-ralph` — but any ai-ralph-compatible CLI with a `plan` + `int` surface works.

## What the Workbench Adds

ai-ralph natively operates on a single repo. The workbench layers three things on top:

1. **Context routing** (`scripts/sync-context.sh`) reads `.workbench-state/approved.json`, honors each artifact's `target_repos:` frontmatter, and copies the artifact only into the listed `repos/{name}/ai/` directories. The repo's role still filters by type (service repos see PRDs + specs + TDDs + ERD + ADRs; automation repos see PRDs + BDDs + test cases + test spec; shared-lib repos see specs + TDDs + ADRs; infra repos see ADRs only).
2. **Workspace-mode planning** (`scripts/ralph-plan.sh`) wraps `ralph-plan --workspace` invoked at `repos/`, which writes per-repo `.ralph/fix_plan.md` sections from a single workbench-aware planning pass. Per-repo mode is kept as a fallback for older ralph installs.
3. **Cross-repo parallel dispatch** (`scripts/ralph-dispatch.sh`) wraps `ralph --workspace --parallel N` invoked at `repos/` (default `N = min(len(REPOS), 4)`). Ralph itself owns the loop, worktrees, commits, pushes, and PRs. `--status` shells out to `gh pr list` plus a tail of each repo's worker log.

This gives you "one plan, multiple repos, dispatch them in parallel" without re-implementing any ralph internals.

## Workspace-Mode Planning

`wb.ralph-plan` defaults to workspace mode: a single `ralph-plan --workspace` call at `$WB_ROOT/repos/` aggregates all approved workbench context, scans `repos/*`, and writes per-repo `## <repo-name>` sections into `repos/.ralph/fix_plan.md`. The mode resolver is `CLI flag > env (WB_RALPH_PLAN_MODE) > project.conf RALPH_PLAN_MODE > auto`. Auto picks workspace when the installed `ralph-plan` advertises `--workspace`, otherwise it loops `project.conf REPOS` per-repo.

Override with `wb.ralph-plan --mode per-repo`, `WB_RALPH_PLAN_MODE=per-repo`, or `RALPH_PLAN_MODE=per-repo` in `project.conf`.

## `target_repos:` Routing

Every PRD, eng-spec, TDD, ERD, BDD, test-cases, test-spec, and test-erd carries a `target_repos: [...]` field naming repos from `project.conf REPOS`. `wb.publish` and `wb.approve` both call `scripts/validate-artifact.py`, which rejects missing, empty, or unregistered values. The list flows into `sync-context.sh` (only listed repos receive the artifact) and into `ralph-plan`'s `## <repo-name>` section routing. ADRs and epic-context files are exempt and pass through.

## Steering Drift Footer (M4)

When the team has overlays under `steering.local/`, `sync-context.sh` writes a markdown footer (classifying every entry as ADD / SUPERSEDE / REMOVE) to `$WB_ROOT/repos/.ralph/pr_footer.md`. Ralph appends that file to every PR body via the upstream `pr-footer-append` support in `pr_manager.sh`. The footer file is removed when the overlay set empties.

## Adapter Scripts

```
scripts/sync-context.sh
  # Push approved workbench artifacts into each repos/{x}/ai/ dir.
  # Honors target_repos: per artifact and the repo's role filter.
  # Writes/removes repos/.ralph/pr_footer.md based on steering.local/ state.

scripts/ralph-context.sh
  # Internal alias for sync-context.sh used by ralph-plan.sh.

scripts/ralph-plan.sh [--mode workspace|per-repo|auto] [--engine ...] [--thinking ...] [--dry-run]
  # Resolver order: CLI flag > env WB_RALPH_PLAN_MODE > project.conf RALPH_PLAN_MODE > auto.
  # Workspace mode: (cd repos && ralph-plan --workspace --engine $E --thinking $T)
  # Per-repo fallback: loops project.conf REPOS, runs ralph-plan inside each.

scripts/ralph-dispatch.sh [--parallel N [M]] [--max-tasks M] [--max-task-attempts K] [--respawn-delay SEC] [--no-tabs] [--engine ...] [--repos a,b] [--exclude c] [--status] [--dry-run]
  # (cd repos && ralph --workspace --parallel N [M] [--max-task-attempts K] [--respawn-delay SEC] [--no-tabs])
  # Default N = min(len(REPOS), 4). With M set, engages ralph's continuous mode.
  # Engine + continuous knobs passed through when ralph supports them; missing
  # continuous support fails fast (no silent fallback to batch).
  # --status: gh pr list per repo + tail of repos/.ralph/logs/.

scripts/ralph-enable-check.sh
  # Preflights that `ralph enable --workspace` ran at $WB_ROOT/repos/.
  # Called by wb.ralph-plan and wb.ralph-dispatch.

scripts/validate-artifact.py
  # Validates target_repos: against project.conf REPOS. Hooked into lifecycle.py
  # at both publish and approve. Pass-through for adr and epic-context types.
```

Single-repo debugging is a one-liner; the workbench does not wrap it:

```bash
(cd "$WB_ROOT/repos/<name>" && ralph --live --monitor)
```

## Continuous Dispatch

`wb.ralph-dispatch` defaults to **batch mode**: spawn N agents, each runs the workspace loop, wrapper exits when all N have stopped. That is a one-shot fan-out.

**Continuous mode** keeps N workers saturated until M total task attempts have been spent (success or failure both count), or the queue drains. It is the right shape for long unattended runs over a deep workspace fix_plan.

Engagement is opt-in. Setting M flips the mode:

```bash
# Named form (preferred — pairs cleanly with project.conf)
wb.ralph-dispatch --parallel 3 --max-tasks 30

# Positional form (mirrors ralph's `--parallel N M` shape byte-identically)
wb.ralph-dispatch --parallel 3 30

# Drive from project.conf so the team runs the same shape
echo 'WB_RALPH_MAX_TASKS="50"' >> project.conf
wb.ralph-dispatch --parallel 4
```

Tuning knobs (inert without M; ralph accepts them in batch mode but they only matter in continuous):

| Flag | Env var | `project.conf` key | Default | Meaning |
|------|---------|--------------------|---------|---------|
| `--max-tasks M` | `WB_RALPH_MAX_TASKS` | `WB_RALPH_MAX_TASKS` | unset | Engages continuous; total attempts cap. |
| `--max-task-attempts K` | `WB_RALPH_MAX_TASK_ATTEMPTS` | `WB_RALPH_MAX_TASK_ATTEMPTS` | 1 (ralph) | Per-task retry cap; task is skip-listed after K failures. |
| `--respawn-delay SEC` | `WB_RALPH_RESPAWN_DELAY` | `WB_RALPH_RESPAWN_DELAY` | 0 (ralph) | Cooldown between worker respawns. |
| `--no-tabs` | `WB_RALPH_DISABLE_TABS=true` | `WB_RALPH_DISABLE_TABS` | (off) | Force single-pane orchestrator. |

The wrapper capability-gates the forwarding: continuous-mode flags are only passed through when `ralph --help` advertises the `--parallel N M` surface. An older ralph that does not understand continuous mode causes `wb.ralph-dispatch --max-tasks` to fail fast with a clear error instead of silently running batch.

## Hard Rules

- **Never generate a fix_plan entry for a repo without an approved PRD** and, for service repos, an approved engineering spec.
- **Ralph always runs from a code repo's cwd**, never from the workbench root.
- **`.workbench-state/approved.json` is the only gate.** Frontmatter is not inspected at sync time — the JSON is the contract.
- **Never write into `repos/*` from a workbench Claude/Devin session.** That is ralph's job.
