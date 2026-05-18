---
title: Ralph Integration
layout: default
eyebrow: Ralph
---

*Prefer the old long-form? See [V1 archive](./v1/ralph.html).*

## What ai-ralph is

Multi-engine autonomous AI dev loop. Given a `fix_plan.md` inside a code repo, drives Claude / Devin / Codex in a controlled loop, committing incrementally, until done. Workbench points at an `ai-ralph` fork under your org (e.g. `<your-org>/ai-ralph`); any ai-ralph-compatible CLI with a `plan` + `int` surface works.

## What the workbench adds

ai-ralph runs one repo natively. Workbench adds three things:

1. **Context routing** (`scripts/sync-context.sh`): reads `.workbench-state/approved.json`, honours each artifact's `target_repos:`, copies into matching `repos/{name}/ai/`. Repo role filters too: service → PRDs+specs+TDDs+ERD+ADRs; automation → PRDs+BDDs+test cases+test spec; shared-lib → specs+TDDs+ADRs; infra → ADRs only.
2. **Workspace-mode planning** (`scripts/ralph-plan.sh`): wraps `ralph-plan --workspace` at `repos/`, writes per-repo `.ralph/fix_plan.md` sections in one pass. Per-repo loop is fallback.
3. **Cross-repo parallel dispatch** (`scripts/ralph-dispatch.sh`): wraps `ralph --workspace --parallel N` at `repos/` (default `N = min(len(REPOS), 4)`). Ralph owns loop, worktrees, commits, pushes, PRs. `--status` shells `gh pr list` + tail of each worker log.

One plan, multiple repos, parallel dispatch. No re-implementation of ralph internals.

## Workspace-mode planning

`wb.ralph-plan` defaults to workspace mode: single `ralph-plan --workspace` at `$WB_ROOT/repos/` aggregates approved context, scans `repos/*`, writes per-repo `## <repo-name>` sections into `repos/.ralph/fix_plan.md`.

Mode resolver: `CLI flag > WB_RALPH_PLAN_MODE > project.conf RALPH_PLAN_MODE > auto`. Auto picks workspace when the installed `ralph-plan` advertises `--workspace`, else loops `project.conf REPOS` per-repo. Override: `wb.ralph-plan --mode per-repo`, env, or `project.conf`.

## `target_repos:` routing

Every PRD, eng-spec, TDD, ERD, BDD, test-cases, test-spec, test-erd carries `target_repos: [...]` naming repos from `project.conf REPOS`. `wb.publish` / `wb.approve` call `scripts/validate-artifact.py`, which rejects missing, empty, or unregistered values. Flows into `sync-context.sh` and `ralph-plan` section routing. ADRs + epic-context exempt.

## Steering drift footer (M4)

When `steering.local/` is non-empty, `sync-context.sh` writes a markdown footer (entries tagged ADD / SUPERSEDE / REMOVE) to `$WB_ROOT/repos/.ralph/pr_footer.md`. Ralph appends it to every PR body via upstream `pr-footer-append`. Footer is removed when overlays empty.

## Adapter scripts

```
scripts/sync-context.sh
  # Push approved workbench artifacts into each repos/{x}/ai/ dir.
  # Honors target_repos: per artifact and the repo's role filter.
  # Writes/removes repos/.ralph/pr_footer.md based on steering.local/ state.

scripts/ralph-context.sh
  # Internal alias for sync-context.sh used by ralph-plan.sh.

scripts/ralph-plan.sh [--mode workspace|per-repo|auto] [--engine ...] [--thinking ...] [--dry-run]
  # Resolver: CLI flag > env WB_RALPH_PLAN_MODE > project.conf RALPH_PLAN_MODE > auto.
  # Workspace: (cd repos && ralph-plan --workspace --engine $E --thinking $T)
  # Per-repo fallback: loops project.conf REPOS, runs ralph-plan inside each.

scripts/ralph-dispatch.sh [--parallel N] [--engine ...] [--status] [--dry-run]
  # (cd repos && ralph --workspace --parallel N)
  # Default N = min(len(REPOS), 4). Engine flag passed through when ralph supports it.
  # --status: gh pr list per repo + tail of repos/.ralph/logs/.

scripts/ralph-enable-check.sh
  # Preflights that `ralph enable --workspace` ran at $WB_ROOT/repos/.
  # Called by wb.ralph-plan and wb.ralph-dispatch.

scripts/validate-artifact.py
  # Validates target_repos: against project.conf REPOS. Hooked into lifecycle.py
  # at both publish and approve. Pass-through for adr and epic-context types.
```

Single-repo debugging (workbench does not wrap this):

```bash
(cd "$WB_ROOT/repos/<name>" && ralph --live --monitor)
```

## Hard rules

- No fix_plan entry for a repo without an approved PRD (and, for service repos, an approved eng-spec).
- Ralph runs from a code repo's cwd, never from workbench root.
- `.workbench-state/approved.json` is the only gate. Frontmatter is not inspected at sync time; the JSON is the contract.
- Never write into `repos/*` from a workbench Claude/Devin session. That is ralph's job.
