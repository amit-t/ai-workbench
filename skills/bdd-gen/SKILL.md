---
name: bdd-gen
description: Generate Gherkin .feature files (status=draft) from an approved PRD. Scenarios cover happy/edge/error/security paths.
category: QA
relevant_topics: [test-data]
---

# /bdd-gen

## When to use

PRD is approved; user wants executable behavior specs.

## Prerequisites

- PRD has `status: approved` AND entry in `.workbench-state/approved.json`.
- Optionally `qa/context-library/` for automation-stack hints (Playwright, Cypress, Cucumber, pytest-bdd). Default to stack-agnostic Gherkin.

## Steps

0. **Load steering.** Run `wb.steering artifact:bdd` and `wb.steering topic:test-data`. Treat the merged rulesets as hard constraints on tag selection, scenario structure, Examples-table contents, and status-header placement.

1. **Read the approved PRD.** Extract ACs.

2. **Group into feature files.** One feature file per cohesive capability. Name: `PRD-{NNN}-{capability-slug}.feature`. Identify the target automation repo(s) from `project.conf REPOS` (role=automation-tests); the Gherkin header gets `# target_repos: [...]` (validated at `wb.publish` / `wb.approve`).

3. **Write each file** with a header comment containing lifecycle metadata:

   ```gherkin
   # id: BDD-{NNN}-{capability}
   # status: draft
   # epic: {EPIC_ID}
   # prd: PRD-{NNN}
   # target_repos: [{automation-tests-repo}]
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

6. **Grill pass.** Read `skills/grill-substrate.md` (single source for stance, scratch-block format, and `grilled:` frontmatter schema). Then:

   - **Mode (per repo, Resolution Z):** for each `repo` in the BDD header's `target_repos:` (Gherkin `# target_repos:` line), use `/domain-grill` when `${WB_ROOT}/context/<repo>/CONTEXT.md` exists, otherwise fall back to `/grill-me` for that repo.
   - **Per feature file:** one grill batch per `.feature` file (a BDD set may have several files; ask the user whether to grill all in sequence or only the most recent).
   - **Prompt (Option-B with teeth, batched):**
     ```
     BDD-{NNN}-{cap} drafted at qa/outputs/bdd/PRD-{NNN}-{cap}.feature.
     Targets: automation-repo (domain-grill or grill-me), ...
     Prior grill: <none | YYYY-MM-DD depth (resolved N, parked M)>
     Run grill now? Depth? [deep|standard|quick] (default: deep)
     [Y/n/skip-this-session]
     ```
     Default Y on first run. Default n if `grilled.date` is current and artifact mtime less than or equal to `grilled.date`.
   - **Execute sequentially.** On `Y`, for each target repo: pre-stage the `bdd` stance from §1 of `grill-substrate.md` + the scratch-block format from §2, then invoke `Skill("domain-grill" | "grill-me", args=<depth>)` with `cwd=${WB_ROOT}/context/<repo>/` for domain-grill, or `cwd=${WB_ROOT}` for the fallback.
   - **Record per pass.** Gherkin files do not carry YAML frontmatter — record the `grilled:` block as additional `# grilled:` header comment lines (mirror the schema in `grill-substrate.md` §3, prefix each line with `# `). Append scratch block as Gherkin comments (`# - [resolved] ...`). Atomic write via tempfile + rename.
   - **Abort / skip / cascade-resume.** Per §4 cheat-sheet. Cascade prompt default Y. Never blocks.

7. **Tell the user:**

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

`wb.publish`, `wb.approve`, and `wb.reject` all detect `.feature` files and rewrite the `# status:` header comment (instead of YAML frontmatter). The header line must exist in the file when the first `wb.publish` runs; if it does not, the CLI fails with a clear error. Keep the `# status: draft` line at the top as shown in step 3.

## Do not

- Do not write scenarios that cannot be automated without unreasonable setup. Tag `@manual` if needed.
- Do not include PII or real account numbers in Examples tables.
- Do not skip `@security` for user-facing endpoints.
