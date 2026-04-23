---
title: Artifact lifecycle
layout: default
kicker: Lifecycle
eyebrow: lifecycle
tagline: Every artifact flows draft → published → approved. Agents write drafts. Humans gate the rest.
---

# Artifact lifecycle

Every artifact in a workbench (PRD, engineering spec, TDD, ERD, ADR, BDD feature, test cases, test spec, test ERD) carries a `status` field in YAML frontmatter and flows through three stages.

## Stages

| Stage | Meaning | Who sets it | Where recorded |
|-------|---------|-------------|----------------|
| `draft` | Agent wrote it. Internal. | Skill (e.g. `/prd-draft`) | frontmatter only |
| `published` | Human-reviewed, ready for panel / counterpart review. | `wb.publish <id> <path> <type>` | frontmatter + `.workbench-state/published.json` |
| `approved` | Signed off. Ralph may consume it. | `wb.approve <id>` | frontmatter + `.workbench-state/approved.json` |

Rejection is a side path: `wb.reject <id> "<reason>"` returns the artifact to `draft`, records the reason in `.workbench-state/rejected.json`. Rejection works from any stage (including `approved`).

## Commands

| Alias | Transition | Effect |
|-------|-----------|--------|
| `wb.publish <id> <path> <type>` | `draft → published` | Flips frontmatter; appends entry to `published.json`. Type must be one of: `prd, eng-spec, tdd, erd, adr, bdd, test-cases, test-spec, test-erd, epic-context`. |
| `wb.approve <id>` | `published → approved` | Flips frontmatter; moves entry to `approved.json`. |
| `wb.reject <id> "<reason>"` | any → `draft` | Records reason; clears entry from all state files. |
| `wb.published` | — | Lists artifacts awaiting approval. |
| `wb.approved` | — | Lists artifacts ralph may consume. |

## Rules for agents

- Write `draft` only. Never set `published` or `approved` — those are human-driven.
- Never bypass the lifecycle (no direct `approved` writes).
- Ralph gate is `.workbench-state/approved.json`. The sync script filters only what is listed there.

## Downstream skill preconditions

Every downstream skill must verify its upstream artifact is at `approved`:

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

## Concurrency note

Lifecycle commands are not concurrency-safe today. Pull before a session, push after. A lockfile is tracked in Plan D.

## BDD caveat

Gherkin `.feature` files carry lifecycle metadata in a `# status:` header comment. `wb.publish` only auto-flips YAML frontmatter — if you work with `.feature` files, edit the header comment manually for now. A generic handler is tracked in Plan D.
