---
title: /bdd-gen
layout: default
eyebrow: QA
subtitle: "Generate Gherkin `.feature` files from an approved PRD. Covers happy / edge / error / security paths."
---

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| QA | QA | PRD approved | `qa/outputs/bdd/PRD-NNN-<capability>.feature` | `/test-cases-gen`, `/test-spec` |

## When to Use

PRD is approved; user wants executable behavior specs.

## Prerequisites

- PRD `status: approved` AND in `.workbench-state/approved.json`.
- Optional: `qa/context-library/` with automation-stack hints (Playwright, Cypress, Cucumber, pytest-bdd). Default is stack-agnostic Gherkin.

## Protocol

1. Read approved PRD, extract ACs.
2. Group ACs into feature files — one per cohesive capability. Name: `PRD-{NNN}-{capability-slug}.feature`.
3. Write each `.feature` with a **lifecycle metadata header comment** (Gherkin has no YAML frontmatter):

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
    ```

4. **Coverage rule:** every AC → at least one scenario. Every file includes at minimum one `@happy-path`, one `@edge`, one `@error`, and one `@security` (when PRD touches a user-facing endpoint).
5. Update `EPIC-PIPELINE.md` — comma-joined BDD IDs in BDD column.

## Lifecycle Note

`wb.publish` / `wb.approve` / `wb.reject` detect `.feature` files and rewrite the `# status:` header comment (not YAML frontmatter). The header line must exist before first `wb.publish`.

## Do Not

- Write scenarios that cannot be automated without unreasonable setup. Tag `@manual` if needed.
- Include PII or real account numbers in Examples tables.
- Skip `@security` for user-facing endpoints.

## Source

[`skills/bdd-gen/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/bdd-gen/SKILL.md)
