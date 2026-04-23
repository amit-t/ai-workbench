---
title: Ralph integration
layout: default
kicker: Ralph
eyebrow: ralph
tagline: Workspace-mode planning, context routing, parallel dispatch across service and automation repos.
---

# Ralph integration

## What ai-ralph is

**ai-ralph** is a multi-engine autonomous AI development loop: given a `fix_plan.md` inside a code repo, it drives a Claude / Devin / Codex agent in a controlled loop, committing incrementally, until the plan is done. The workbench points at an `ai-ralph` fork under your org — e.g. `<your-org>/ai-ralph` — but any ai-ralph-compatible CLI with a `plan` + `int` surface works.

## What the workbench adds

ai-ralph natively operates on a single repo. The workbench layers two things on top:

1. **Context routing** (`scripts/sync-context.sh`) — reads `.workbench-state/approved.json` and copies each approved artifact into `repos/{name}/ai/` filtered by the target repo's role. Service repos get PRDs + specs + TDDs + ADRs. Automation repos get PRDs + BDDs + test cases + test spec. Shared-lib repos get specs + TDDs + ADRs. Infra repos get ADRs only.
2. **Cross-repo parallel dispatch** (`scripts/ralph-dispatch.sh`) — launches a ralph loop per repo in parallel (background processes or tmux panes), logs PIDs + streams to `ralph/dispatch.log`, exposes a `--status` command that reports per-repo state by reading the log plus each worktree's git status.

This gives you "one plan, multiple repos, dispatch them in parallel" — which ai-ralph native parallelism (within a single repo) does not cover.

## Workspace-mode planning

`wb.ralph-plan` is assumed to invoke ai-ralph's **workspace mode** — a planning command that, when run from a workbench root, aggregates all approved workbench context, scans `repos/*`, writes per-repo `.ralph/fix_plan.md` files, and emits a rollup at `ralph/workspace-plan.md`.

If workspace mode is not yet merged in the ai-ralph fork you point at, the workbench falls back to per-repo planning: it iterates `repos/*`, runs `ralph-plan` inside each with repo-specific context prepared by `ralph-context.sh`, and stitches the results.

> **Plan B** tracks finalising the workspace-mode flag (`--workspace` vs `--workbench`) once the upstream PR merges. Only `scripts/ralph-plan.sh` changes when that happens.

## Adapter scripts

```
scripts/ralph-context.sh
  # Push workbench artifacts into each repos/{x}/ai/ dir per role:
  #   role=service           → PRDs (approved) + specs + TDD + ERD + ADRs
  #   role=automation-tests  → PRDs (approved) + BDDs + test cases + test spec
  #   role=shared-lib        → specs + TDD + ADRs
  #   role=infra             → ADRs only
  # Filter via project.conf REPOS array

scripts/ralph-plan.sh
  # Wraps ai-ralph workspace command
  # Likely: ralph-plan --workspace (or --workbench) invoked from workbench root
  # Single-repo fallback: iterate repos/* and run
  #   (cd repos/{x} && ralph-plan) with repo-specific context from ralph-context.sh

scripts/ralph-loop.sh <repo> [--agent claude|devin|codex]
  # cd repos/{repo} && {rpc.int|rpd.int|rpx.int}
  # Pass through --live --monitor by default

scripts/ralph-dispatch.sh [--repos r1,r2,...] [--agent ...]
  # For each repo, launch ralph-loop in a background process (nohup) or tmux pane
  # Log PIDs + streams to ralph/dispatch.log
  # Status: ralph-dispatch.sh --status reads the log and git status of each worktree
```

## Hard rules

- **Never generate a fix_plan entry for a repo without an approved PRD** and, for service repos, an approved engineering spec.
- **Ralph always runs from a code repo's cwd**, never from the workbench root.
- **`.workbench-state/approved.json` is the only gate.** Frontmatter is not inspected at sync time — the JSON is the contract.
- **Never write into `repos/*` from a workbench Claude/Devin session.** That is ralph's job.
