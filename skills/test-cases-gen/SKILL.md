---
name: test-cases-gen
description: Expand approved BDD scenarios into detailed test cases (status=draft). Output is a reviewable MD table with priority, type, automation-candidate flags.
category: QA
relevant_topics: [test-data]
---

# /test-cases-gen

## When to use

All relevant BDDs for a PRD are approved; user wants detailed test cases.

## Prerequisites

- For each `.feature` file referenced, there must be an approved entry in `.workbench-state/approved.json` (BDD-{NNN}-{cap}).

## Steps

0. **Load steering.** Run `wb.steering artifact:test-cases` and `wb.steering topic:test-data`. Treat the merged rulesets as hard constraints on priority and automation flags, AC coverage, and test-data handling.

1. **Gather approved BDDs for the PRD.** Cross-reference `approved.json` entries with file paths in `qa/outputs/bdd/`.

2. **Expand each scenario into test cases.** Scenario Outline Examples rows become individual test cases.

3. **Write `qa/outputs/test-cases/PRD-{NNN}-cases.md`:**

   ```markdown
   ---
   id: TC-set-{NNN}
   status: draft
   created: {today}
   owner: {gh-user}
   epic: {EPIC_ID}
   prd: PRD-{NNN}
   source_features:
     - PRD-{NNN}-{capability-slug}.feature
   ---

   # Test cases for PRD-{NNN}

   | TC ID | Title | Feature | Scenario | Preconditions | Test data | Steps | Expected result | Priority | Type | Automation candidate | Notes |
   |-------|-------|---------|----------|---------------|-----------|-------|-----------------|----------|------|---------------------|-------|
   | TC-001 | refund happy path | PRD-{NNN}-refund.feature | refund completes | user has paid | {"amount":50} | 1. POST; 2. poll | 200; state=refunded | P0 | functional | yes | — |

   ## Automation coverage

   - Total cases: N
   - P0 automated: {a}/{b}
   - P1 automated: {a}/{b}
   - P2 manual: {n}
   - Candidates flagged `no`: {list}
   ```

   **Column rules:**
   - `TC ID`: `TC-{NNN}` zero-padded per PRD.
   - `Priority`: `P0` (must-automate), `P1` (should), `P2` (manual ok).
   - `Type`: `functional`, `regression`, `smoke`, `performance`, `security`, `a11y`.
   - `Automation candidate`: `yes` / `no` / `manual-only`.
   - `Steps`: numbered, imperative, one action per step.
   - `Test data`: JSON or k/v; synthetic only.

4. **Tell the user:**

   > Test cases drafted at `qa/outputs/test-cases/PRD-{NNN}-cases.md` (status: draft). Review, then:
   > ```
   > wb.publish TC-set-{NNN} qa/outputs/test-cases/PRD-{NNN}-cases.md test-cases
   > wb.approve TC-set-{NNN}
   > ```
   > Next: `/test-spec PRD-{NNN}` once approved.

## Output contract

- Creates: `qa/outputs/test-cases/PRD-{NNN}-cases.md` with `status: draft`.

## Do not

- Do not use production data in `Test data`.
- Do not skip the automation-coverage summary.
- Do not mark everything `yes` for automation — visual / regulatory / manual-judgment cases stay `manual-only`.
