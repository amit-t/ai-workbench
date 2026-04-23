---
name: pmo-status
description: Cross-cutting status view of the workbench — epics, PRDs, specs, TDDs, BDDs, ralph fix_plan coverage per repo, dispatch state. Run at session start or on demand. Reads `.workbench-state/` as source of truth; never guesses.
category: Project Management
---

# /pmo-status

## When to use

- Start of a workbench session — orient before deciding next action.
- Before dispatching ralph — confirm upstream gates are green.
- After a long running dispatch — see which repos landed and which did not.

## Prerequisites

- Workbench is initialised (`EPIC-PIPELINE.md` exists, `.workbench-state/approved.json` exists even if empty).
- `project.conf` is sourced (REPOS list).

## Steps

Read the following in parallel before producing output. Do not infer — read.

1. `EPIC-PIPELINE.md`
2. `.workbench-state/approved.json`
3. `.workbench-state/published.json`
4. `.workbench-state/rejected.json` (if present)
5. Directory listings:
   - `product/outputs/prds/` (flat; no `approved/` subdir in Phase 2+)
   - `engineering/outputs/specs/`
   - `engineering/outputs/tdds/`
   - `engineering/outputs/adrs/`
   - `engineering/outputs/erd/`
   - `qa/outputs/bdd/`, `qa/outputs/test-cases/`, `qa/outputs/test-specs/`
   - `design/outputs/screens/`, `design/outputs/handoffs/`
6. For each repo in `project.conf REPOS`: `repos/{repo}/.ralph/fix_plan.md` and `ralph/{repo}.pid` (if present), plus `ralph/logs/{repo}.log` last line.

## Output format

Produce exactly this structure. One row per artifact. No filler.

```
# Workbench status — {today}

## Epics
| Epic | Context | PRDs (draft/published/approved) | Next action |
|------|---------|---------------------------------|-------------|

## PRDs
| PRD | Title | Stage | Spec | TDD | BDD | Test-cases | Design | Exec |
|-----|-------|-------|------|-----|-----|------------|--------|------|

Legend: ✓ approved, ~ published/awaiting-approval, · draft, — none

## Engineering
| Artifact | Count draft | Count published | Count approved |
|----------|-------------|-----------------|----------------|

## QA
| Artifact | Count draft | Count published | Count approved |

## Ralph per repo
| Repo | fix_plan? | Lines | Dispatch state | Last log line |

## Blockers
- {artifact id} — {what's blocking} — {owner}

## Next 3 actions
1. {specific command or file edit — not a vague TODO}
2. ...
3. ...
```

**Stage resolution rules:**
- Artifact appears in `approved.json` → approved.
- Else in `published.json` → published.
- Else file exists with `status: draft` in frontmatter → draft.
- Else missing.

**Dispatch state** is one of: `idle` (no pidfile), `running` (pidfile + live PID), `stale` (pidfile but PID gone), `done` (log ends with exit code 0), `failed` (exit non-zero).

## Output contract

- Read-only. Produces stdout report; does not modify any file.

## Do not

- Do not infer `approved` from the existence of a file — `.workbench-state/approved.json` is the only gate.
- Do not stall on a missing repo checkout — render `fix_plan?: ✗ (not cloned)` and move on.
- Do not compute counts greater than 50 per cell without truncating; show `50+` and link to the directory.
