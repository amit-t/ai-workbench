---
title: /ralph-dispatch
layout: default
eyebrow: Orchestrator
subtitle: "Launch parallel autonomous ralph loops across workbench-registered repos. Cross-repo parallelism — net-new over ralph's within-repo parallelism."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output |
|-----|-------|---------------|--------|
| Orchestrator | Execution | `/ralph-workspace-plan` ran; fix_plans present | `ralph/logs/{repo}.log`, `ralph/{repo}.pid`, `ralph/dispatch.log` |

## When to Use

Per-repo fix_plans exist and user wants ralph to execute, ideally in parallel across multiple repos.

## What This Skill Adds Over `ralph` Alone

| Scope | Source |
|-------|--------|
| Within-repo parallelism (`rpc.p N`) | ai-ralph native |
| **Across-repo parallelism** — one loop per registered repo, pidfile + per-repo log | this skill |
| **Continuous mode pass-through** — `--max-tasks M` / positional `--parallel N M`, plus `--max-task-attempts`, `--respawn-delay`, `--no-tabs`, capability-gated against `ralph --help` | this skill |

## Continuous Mode

For long unattended runs over a deep workspace fix_plan, engage ralph's **continuous mode**: workers stay saturated up to N concurrent until M total attempts have been spent, or the queue drains.

Resolution: CLI flag > env > `project.conf` > unset (batch mode).

| Flag | Env var | `project.conf` key | Meaning |
|------|---------|--------------------|---------|
| `--max-tasks M` | `WB_RALPH_MAX_TASKS` | `WB_RALPH_MAX_TASKS` | Engages continuous mode. Total attempts cap. |
| `--max-task-attempts K` | `WB_RALPH_MAX_TASK_ATTEMPTS` | `WB_RALPH_MAX_TASK_ATTEMPTS` | Per-task retry cap. |
| `--respawn-delay SEC` | `WB_RALPH_RESPAWN_DELAY` | `WB_RALPH_RESPAWN_DELAY` | Cooldown between worker respawns. |
| `--no-tabs` | `WB_RALPH_DISABLE_TABS=true` | `WB_RALPH_DISABLE_TABS` | Force single-pane orchestrator. |

The positional form `wb.ralph-dispatch --parallel N M` is accepted as a shorthand and forwarded identically to ralph's own `--parallel N M` shape.

```bash
wb.ralph-dispatch --parallel 3 --max-tasks 30
wb.ralph-dispatch --parallel 3 30
wb.ralph-dispatch --parallel 3 30 --no-tabs --respawn-delay 5
```

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

## Do Not

- Launch if workbench or any target repo is dirty.
- Silently ignore non-zero exits. Surface last 30 lines in status summary.
- Leave stale pidfiles.

## Source

[`skills/ralph-dispatch/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/skills/ralph-dispatch/SKILL.md)
