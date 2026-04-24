---
title: /ralph-dispatch
layout: default
---

[← Back to skills](../skills.html)

# /ralph-dispatch

> Launch parallel autonomous ralph loops across workbench-registered repos. Cross-repo parallelism — net-new over ralph's within-repo parallelism.

| Hat | Stage | Upstream gate | Output |
|-----|-------|---------------|--------|
| Orchestrator | Execution | `/ralph-workspace-plan` ran; fix_plans present | `ralph/logs/{repo}.log`, `ralph/{repo}.pid`, `ralph/dispatch.log` |

## When to use

Per-repo fix_plans exist and user wants ralph to execute, ideally in parallel across multiple repos.

## What this skill adds over `ralph` alone

| Scope | Source |
|-------|--------|
| Within-repo parallelism (`rpc.p N`) | ai-ralph native |
| **Across-repo parallelism** — one loop per registered repo, pidfile + per-repo log | this skill |

## Prerequisites

- `/ralph-workspace-plan` ran — implies upstream artifacts all `approved`. Dispatch inherits the gate; does not re-check.
- `.ralph/fix_plan.md` exists and non-empty in every target repo.
- Workbench git-clean. Every target repo git-clean.

## Protocol

1. Sanity checks — refuse and print specific failure:

    ```bash
    git -C "$WB_ROOT" status --porcelain
    for r in <selected-repos>; do git -C "$WB_ROOT/repos/$r" status --porcelain; done
    for r in <selected-repos>; do
      [[ -f "$WB_ROOT/repos/$r/.ralph/fix_plan.md" ]] && [[ -s "$WB_ROOT/repos/$r/.ralph/fix_plan.md" ]] \
        || echo "fix_plan missing or empty: $r"
    done
    ```

2. Select repos — default all with fix_plan; override `--repos r1,r2`.
3. Pick engine — respects `DEVIN_DEFAULT`; override `--agent`.
4. Launch: `./scripts/ralph-dispatch.sh [--repos {csv}] [--agent {engine}]`.
5. Report launched loops — PIDs, log paths.
6. On status requests, read pidfiles + logs: `| Repo | PID | State | Last line |`.
7. On completion (all PIDs gone) — read last 30 lines, extract exit code + any PR URL, update `EPIC-PIPELINE.md` `Exec` column (`~` → `✓` or `✗`), remove stale pidfiles.

## Do not

- Launch if workbench or any target repo is dirty.
- Silently ignore non-zero exits. Surface last 30 lines in status summary.
- Leave stale pidfiles.

## Source

[`skills/ralph-dispatch/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/ralph-dispatch/SKILL.md)
