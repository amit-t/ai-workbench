---
name: bdd-gen
description: Generate Gherkin .feature files (status=draft) from an approved PRD. Scenarios cover happy/edge/error/security paths.
category: QA
---

# /bdd-gen

## When to use

PRD is approved; user wants executable behavior specs.

## Prerequisites

- PRD has `status: approved` AND entry in `.workbench-state/approved.json`.
- Optionally `qa/context-library/` for automation-stack hints (Playwright, Cypress, Cucumber, pytest-bdd). Default to stack-agnostic Gherkin.

## Steps

1. **Read the approved PRD.** Extract ACs.

2. **Group into feature files.** One feature file per cohesive capability. Name: `PRD-{NNN}-{capability-slug}.feature`.

3. **Write each file** with a header comment containing lifecycle metadata:

   ```gherkin
   # id: BDD-{NNN}-{capability}
   # status: draft
   # epic: {EPIC_ID}
   # prd: PRD-{NNN}
   # created: {today}
   # owner: {gh-user}
   # language: en

   @epic-{EPIC_ID} @prd-PRD-{NNN}
   Feature: {capability title}
     As a {role}
     I want {action}
     So that {outcome}

     Background:
       Given {shared precondition}

     @happy-path
     Scenario: {one-liner}
       Given {context}
       When {event}
       Then {observable outcome}

     @edge
     Scenario Outline: {edge case}
       Given {context with <var1>}
       When {event}
       Then {outcome with <expected>}
       Examples:
         | var1 | expected |

     @error
     Scenario: {error path}
       Given {invalid context}
       When {event}
       Then {error surface}

     @security
     Scenario: {auth/permission edge}
       Given {unauthorized actor}
       When {event}
       Then {403 or refusal}
   ```

   **Coverage rule:** every AC → at least one scenario. Every feature file must include at least one `@happy-path`, one `@edge`, one `@error`, and one `@security` when the PRD touches a user-facing endpoint.

4. **Lifecycle mapping.** Because `.feature` files are Gherkin not YAML, the lifecycle metadata lives in the header comment. `wb.publish` / `wb.approve` operate on the ID (e.g. `BDD-{NNN}-{cap}`) — publish per file.

5. **Update `EPIC-PIPELINE.md`.** Set BDD column to a comma-joined list of BDD IDs or a single `BDD-{NNN}` if one feature file.

6. **Tell the user:**

   > {N} feature files written at `qa/outputs/bdd/` (status: draft in headers). Review, then publish+approve each:
   > ```
   > wb.publish BDD-{NNN}-{cap} qa/outputs/bdd/PRD-{NNN}-{cap}.feature bdd
   > wb.approve BDD-{NNN}-{cap}
   > ```
   > Next: `/test-cases-gen PRD-{NNN}` once approved.

## Output contract

- Creates: one or more `qa/outputs/bdd/PRD-{NNN}-{capability-slug}.feature` files, each with a `# status: draft` header comment.
- Modifies: `EPIC-PIPELINE.md`.

## Lifecycle note for state file

When `wb.publish` flips a `.feature` file, it must update the header comment's `# status:` line. The provided `wb.publish` uses a generic frontmatter regex that only matches YAML `status:` lines — **if you are a QA using feature files**, edit the header comment manually OR keep a companion MD sidecar if strict automation is required. The Phase 2 aliases handle YAML frontmatter; feature-file header support is tracked in Plan D.

## Do not

- Do not write scenarios that cannot be automated without unreasonable setup. Tag `@manual` if needed.
- Do not include PII or real account numbers in Examples tables.
- Do not skip `@security` for user-facing endpoints.
