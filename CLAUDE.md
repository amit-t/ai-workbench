# CLAUDE.md — Workbench Instructions

This file is read by Claude Code every session. Read `AGENTS.md` first (shared constitution), then this file.

---

## What this is

You are in a **workbench** — a private per-bundle git repo cloned from `ai-workbench` for a dev + QA pair working on one or more Jira epics. Your job is to help the user move from Jira epic to PRD to engineering artifacts to approved fix_plan entries in the code repos under `repos/`.

You never write production code from the workbench. Code lives in `repos/*/`, and ralph runs there with the fix_plans you helped prepare.

---

## Session Start Protocol

Every session, in this order:

1. `git pull --rebase` — workbench is shared with a collaborator; pull first.
2. Read `project.conf` — workspace label, epics in scope, registered repos and their roles.
3. Read `EPIC-PIPELINE.md` — current status per epic and PRD.
4. Read `.workbench-state/published.json` — artifacts awaiting approval.
5. Read `.workbench-state/approved.json` — what ralph can consume right now.
6. Scan `product/outputs/prds/` for drafts and approved PRDs.
7. Suggest the most useful next action based on what is unfinished.

---

## Role inference (you adapt; don't ask the user to switch modes)

| Signal | Mode |
|--------|------|
| Discussing a Jira epic, requirements, acceptance criteria | PO mode — produce PRDs |
| Discussing layouts, components, Figma | UXD mode — pull refs, draft screens |
| Discussing architecture, ports, services, data models | Engineering mode — eng spec / TDD / ERD / ADR |
| Discussing test coverage, BDD, scenarios, test data | QA mode — BDD / test cases / test spec |
| Discussing ralph, fix_plan, parallel loops | Orchestrator mode — workspace-plan / dispatch |

## Plan-mode rule

Always present a plan before writing any code (in `repos/*`) or creating any fix_plan entry. Get explicit approval from the user. Only then execute. Artifacts under `product/`, `design/`, `engineering/`, `qa/` may be drafted without a plan. They start at `status: draft` and only move to `published` or `approved` via the human-driven `wb.publish` / `wb.approve` aliases.

## Artifact lifecycle (three stages)

Every artifact you write starts at `status: draft`. State transitions happen only via the three aliases:

| Alias | Transition | Effect |
|-------|-----------|--------|
| `wb.publish <id> <path> <type>` | `draft → published` | Sets `status: published`; appends entry to `.workbench-state/published.json`. |
| `wb.approve <id>` | `published → approved` | Sets `status: approved`; moves entry from `published.json` to `approved.json`. |
| `wb.reject <id> "<reason>"` | any stage → `draft` | Records rejection reason in `rejected.json`; clears `published.json` and `approved.json` entries. |

**Rules for agents:**

- **Write `draft` only.** Never set `status: published` or `status: approved` yourself. Those transitions are human-driven.
- **Never bypass the lifecycle.** Do not write an artifact directly with `status: approved`.
- **Ralph gate is `.workbench-state/approved.json`.** `sync-context.sh` filters only what is listed there.

**Downstream skill preconditions** (upstream must be `approved`):

| Skill | Requires at `approved` |
|-------|------------------------|
| `/prd-draft` | epic-context file (typed `epic-context`, produced by `/epic-intake`) |
| `/eng-spec` | PRD |
| `/tdd` | engineering spec |
| `/erd` | engineering spec |
| `/adr` | engineering spec if one exists; otherwise no upstream gate (ADRs can stand alone) |
| `/bdd-gen` | PRD |
| `/test-cases-gen` | BDDs (all relevant `.feature` files) |
| `/test-spec` | PRD + BDDs + test cases |
| `/ralph-workspace-plan` | PRD + engineering spec + TDD + test spec |

## Context library routing

| User asks about | Where to look |
|-----------------|--------------|
| Current epics, PRDs | `EPIC-PIPELINE.md` |
| Epic body (Jira) | `product/context-library/epics/<EPIC-ID>.md` |
| PRDs | `product/outputs/prds/` |
| Design system ref | `design/context-library/design-system-ref.md` |
| Figma links | `design/context-library/figma-links.md` |
| Engineering specs | `engineering/outputs/specs/` |
| TDDs | `engineering/outputs/tdd/` |
| ERDs | `engineering/outputs/erd/` |
| ADRs | `engineering/outputs/adrs/` |
| BDD features | `qa/outputs/bdd/` |
| Test cases | `qa/outputs/test-cases/` |
| Test spec (QA engg spec) | `qa/outputs/test-spec/` |
| Test ERD | `qa/outputs/test-erd/` |
| Registered code repos | `project.conf` REPOS array |
| Published (awaiting approval) | `.workbench-state/published.json` |
| Approved (ralph-ingestable)   | `.workbench-state/approved.json` |
| Rejections                    | `.workbench-state/rejected.json` |

## Key commands (sourced via `aliases.sh`)

```
wb.sync-context                       # push workbench outputs into repos/*/ai/
wb.ralph-plan                         # ralph workspace-mode plan
wb.ralph-loop <repo> [--agent ...]    # one-repo loop
wb.ralph-dispatch [--repos r1,r2]     # parallel loops
wb.register-repo <name> <url> <role>  # add code repo
wb.publish <id> <path> <type>         # draft → published
wb.approve <id>                       # published → approved
wb.reject <id> "<reason>"             # any → draft (with reason)
wb.published                          # list awaiting approval
wb.approved                           # list ralph-ingestable
```

## Hard rules

- Never generate a fix_plan entry for a repo without an approved PRD and (for service repos) an approved engineering spec.
- Never write into `repos/*` from a workbench Claude session. That is ralph's job.
- Never touch files under `skills/`, `scripts/`, `CLAUDE.md`, `AGENTS.md`, `aliases.sh`, or `.workbench-manifest.json`. Those are template-owned and rewritten by `update.wb`.
- No em dashes in documents. Use commas or parentheses. Exception: code blocks preserve exact content.
- No hype words. No "leverage", "utilize", "robust", "streamline", "unlock". Plain English.
