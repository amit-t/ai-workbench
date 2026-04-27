---
title: /pmo-status
layout: default
eyebrow: Cross-Cutting
subtitle: "Cross-cutting workbench status view — epics, PRDs, specs, TDDs, BDDs, ralph fix_plan coverage per repo, dispatch state. Reads `.workbench-state/` as source of truth; never guesses."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output |
|-----|-------|---------------|--------|
| Cross-cutting | Status | None (read-only) | Terminal report (no file writes) |

## When to Use

- Start of a workbench session — orient before deciding next action.
- Before dispatching ralph — confirm upstream gates are green.
- After long-running dispatch — see which repos landed and which did not.

## Prerequisites

- Workbench initialised — `EPIC-PIPELINE.md` exists, `.workbench-state/approved.json` exists (empty is fine).
- `project.conf` sourced (REPOS list).

## Reads in Parallel (Never Infers)

1. `EPIC-PIPELINE.md`
2. `.workbench-state/approved.json`
3. `.workbench-state/published.json`
4. `.workbench-state/rejected.json`
5. Directory listings — `product/outputs/prds/`, `engineering/outputs/{specs,tdds,adrs,erd}/`, `qa/outputs/{bdd,test-cases,test-specs}/`, `design/outputs/{screens,handoffs}/`.
6. Per repo — `repos/{repo}/.ralph/fix_plan.md`, `ralph/{repo}.pid`, `ralph/logs/{repo}.log` last line.

## Output Format (Verbatim)

```
# Workbench status — {today}

## Epics
| Epic | Context | PRDs (draft/published/approved) | Next action |

## PRDs
| PRD | Title | Stage | Spec | TDD | BDD | Test-cases | Design | Exec |

Legend: ✓ approved, ~ published/awaiting-approval, · draft, — none

## Engineering
| Artifact | Count draft | Count published | Count approved |

## QA
| Artifact | Count draft | Count published | Count approved |

## Ralph per repo
| Repo | fix_plan? | Lines | Dispatch state | Last log line |

## Blockers
- {artifact id} — {what's blocking} — {owner}

## Next 3 actions
1. {specific command or file edit — not a vague TODO}
```

## Stage Resolution

| Rule | Stage |
|------|-------|
| Appears in `approved.json` | approved |
| Else in `published.json` | published |
| Else file exists with `status: draft` | draft |
| Else | missing |

## Dispatch State

`idle` (no pidfile) · `running` (pidfile + live PID) · `stale` (pidfile, PID gone) · `done` (log ends exit code 0) · `failed` (non-zero).

## Do Not

- Infer `approved` from existence of a file. `.workbench-state/approved.json` is the only gate.
- Stall on a missing repo checkout — render `fix_plan?: ✗ (not cloned)` and move on.
- Compute cell counts > 50 without truncating. Show `50+` and link to directory.

## Source

[`skills/pmo-status/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/skills/pmo-status/SKILL.md)
