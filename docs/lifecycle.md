---
title: Artifact Lifecycle
layout: default
eyebrow: Lifecycle
subtitle: Three stages, two sources of truth, one ralph gate.
---

*Prefer the old long-form? See [V1 archive](./v1/lifecycle.html).*

Every artifact (PRD, eng-spec, TDD, ERD, ADR, BDD, test cases, test spec, test ERD) carries `status` in YAML frontmatter and flows through three stages.

## Stages

| Stage | Meaning | Who sets it | Where recorded |
|-------|---------|-------------|----------------|
| `draft` | Agent wrote it. Internal. | Skill (e.g. `/prd-draft`) | frontmatter only |
| `published` | Human-reviewed, ready for panel / counterpart review. | `wb.publish <id> <path> <type>` | frontmatter + `.workbench-state/published.json` |
| `approved` | Signed off. Ralph may consume it. | `wb.approve <id>` | frontmatter + `.workbench-state/approved.json` |

Rejection: `wb.reject <id> "<reason>"` returns the artifact to `draft`, logs the reason in `.workbench-state/rejected.json`. Works from any stage, including `approved`.

## Commands

| Alias | Transition | Effect |
|-------|-----------|--------|
| `wb.publish <id> <path> <type>` | `draft → published` | Flips frontmatter; appends entry to `published.json`. Type ∈ `prd, eng-spec, tdd, erd, adr, bdd, test-cases, test-spec, test-erd, epic-context`. |
| `wb.approve <id>` | `published → approved` | Flips frontmatter; moves entry to `approved.json`. |
| `wb.reject <id> "<reason>"` | any → `draft` | Records reason; clears entry from all state files. |
| `wb.published` | (read-only) | Lists artifacts awaiting approval. |
| `wb.approved` | (read-only) | Lists artifacts ralph may consume. |

## Rules for agents

- Write `status: draft` only. Never set `published` or `approved`. Human-driven.
- Never bypass the lifecycle (no direct `approved` writes).
- Ralph gate is `.workbench-state/approved.json`. Sync script filters strictly on that file.

## Downstream skill preconditions

Every downstream skill verifies its upstream is at `approved`:

| Skill | Requires at `approved` |
|-------|------------------------|
| `/prd-draft` | epic-context |
| `/eng-spec` | PRD |
| `/tdd` | engineering spec |
| `/erd` | engineering spec |
| `/adr` | engineering spec if one exists |
| `/bdd-gen` | PRD |
| `/test-cases-gen` | BDDs |
| `/test-spec` | PRD + BDDs + test cases |
| `/ralph-workspace-plan` | PRD + engineering spec + TDD + test spec |

## Concurrency

Not concurrency-safe today. Pull before a session, push after. Lockfile tracked in Plan D.

## BDD caveat

`.feature` files carry lifecycle metadata in a `# status:` header comment. `wb.publish` auto-flips YAML frontmatter only; for `.feature`, edit the header manually. Generic handler tracked in Plan D.
