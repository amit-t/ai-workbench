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

0.5. **Precision check.** Resolve `PRECISION_MODE` — env `WB_PRECISION_MODE` > `project.conf PRECISION_MODE` > default `on`. If `on`, invoke `Skill("precision-mode")` and announce one line: `Precision mode on for this run.` Carry the resolved value into the test-cases frontmatter as `precision_mode: on|off` at write time. The directive applies for the rest of this host run (artifact body, grill pass, next-steps tail). See `.agents/skills/precision-mode/SKILL.md`.

1. **Gather approved BDDs for the PRD.** Cross-reference `approved.json` entries with file paths in `qa/outputs/bdd/`. Copy `target_repos:` from the approved BDDs into the test-cases frontmatter (validated at `wb.publish` / `wb.approve`).

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
   target_repos: [{automation-tests-repo}]
   precision_mode: {on | off}
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

4. **Grill pass.** Read `skills/grill-substrate.md` (single source for stance, scratch-block format, and `grilled:` frontmatter schema). Then:

   - **Mode (per repo, Resolution Z):** for each `repo` in the test-cases `target_repos`, use `/domain-grill` when `${WB_ROOT}/context/<repo>/CONTEXT.md` exists, otherwise fall back to `/grill-me` for that repo.
   - **Prompt (Option-B with teeth, batched):**
     ```
     TC-set-{NNN} drafted at qa/outputs/test-cases/PRD-{NNN}-cases.md.
     Targets: automation-repo (domain-grill or grill-me), ...
     Prior grill: <none | YYYY-MM-DD depth (resolved N, parked M)>
     Run grill now? Depth? [deep|standard|quick] (default: deep)
     [Y/n/skip-this-session]
     ```
     Default Y on first run. Default n if `grilled.date` is current and artifact mtime less than or equal to `grilled.date`.
   - **Execute sequentially.** On `Y`, for each target repo: pre-stage the `test-cases` stance from §1 of `grill-substrate.md` + the scratch-block format from §2, then invoke `Skill("domain-grill" | "grill-me", args=<depth>)` with `cwd=${WB_ROOT}/context/<repo>/` for domain-grill, or `cwd=${WB_ROOT}` for the fallback.
   - **Record per pass.** Append scratch block + atomically extend `grilled.passes` (tempfile + rename). Per-pass durability.
   - **Abort / skip / cascade-resume.** Per §4 cheat-sheet. Cascade prompt default Y. Never blocks.

5. **Tell the user:**

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
