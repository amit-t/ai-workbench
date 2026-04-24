---
title: /test-cases-gen
layout: default
---

[← Back to skills](../skills.html)

# /test-cases-gen

> Expand approved BDD scenarios into detailed test cases. Reviewable MD table with priority, type, automation-candidate flags.

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| QA | QA | All relevant BDDs approved | `qa/outputs/test-cases/PRD-NNN-cases.md` | `/test-spec` |

## When to use

All relevant BDDs for a PRD are approved; user wants detailed test cases.

## Prerequisites

- Every `.feature` file referenced has an approved entry (`BDD-{NNN}-{cap}`) in `.workbench-state/approved.json`.

## Protocol

1. Gather approved BDDs for the PRD — cross-reference `approved.json` with `qa/outputs/bdd/`.
2. Expand each scenario. `Scenario Outline` Examples rows → individual test cases.
3. Write `qa/outputs/test-cases/PRD-{NNN}-cases.md` — table columns:

    `TC ID | Title | Feature | Scenario | Preconditions | Test data | Steps | Expected result | Priority | Type | Automation candidate | Notes`

4. Append **Automation coverage** summary — totals, P0/P1 automated, P2 manual, `no`-flagged candidates.

## Column rules

| Column | Values |
|--------|--------|
| TC ID | `TC-{NNN}` zero-padded per PRD |
| Priority | `P0` (must-automate), `P1` (should), `P2` (manual ok) |
| Type | `functional`, `regression`, `smoke`, `performance`, `security`, `a11y` |
| Automation candidate | `yes`, `no`, `manual-only` |
| Steps | numbered, imperative, one action per step |
| Test data | JSON or k/v; synthetic only |

## Output frontmatter

```yaml
id: TC-set-{NNN}
status: draft
created: {today}
owner: {gh-user}
epic: {EPIC_ID}
prd: PRD-{NNN}
source_features:
  - PRD-{NNN}-{capability-slug}.feature
```

## Do not

- Use production data in `Test data`.
- Skip the automation-coverage summary.
- Mark everything `yes` for automation — visual / regulatory / judgment cases stay `manual-only`.

## Source

[`skills/test-cases-gen/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/test-cases-gen/SKILL.md)
