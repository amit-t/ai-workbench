---
name: test-spec
description: QA engineering spec at status=draft — coverage matrix, automation entry points, test data, environments, parallelism, flaky-test strategy. Also drafts the test ERD.
category: QA
relevant_topics: [test-data]
---

# /test-spec

## When to use

Approved PRD + approved BDDs + approved test cases. User wants the QA engineering spec before kicking automation into ralph.

## Prerequisites

- PRD at `approved`.
- All relevant BDDs at `approved`.
- Test-case set at `approved`.
- `project.conf REPOS` has at least one `role=automation-tests` entry.

## Steps

0. **Load steering.** Run `wb.steering artifact:test-spec` and `wb.steering topic:test-data`. Treat the merged rulesets as hard constraints on coverage targets per layer, environment matrix, flaky-test strategy, and test-ERD linkage.

0.5. **Precision check.** Resolve `PRECISION_MODE` — env `WB_PRECISION_MODE` > `project.conf PRECISION_MODE` > default `on`. If `on`, invoke `Skill("precision-mode")` and announce one line: `Precision mode on for this run.` Carry the resolved value into the TSD + TERD frontmatter as `precision_mode: on|off` at write time. The directive applies for the rest of this host run (artifact body, grill pass, next-steps tail). See `.agents/skills/precision-mode/SKILL.md`.

1. **Read inputs.** PRD, all approved `qa/outputs/bdd/PRD-{NNN}-*.feature`, `qa/outputs/test-cases/PRD-{NNN}-cases.md`. Read `qa/context-library/` for existing automation conventions.

2. **Identify the automation repo.** Pull from `project.conf REPOS` (role=automation-tests). Capture name + stack hint. Set `target_repos: [automation-repo]` in frontmatter (validated at `wb.publish` / `wb.approve`).

3. **Write `qa/outputs/test-spec/TSD-{NNN}-{slug}.md`:**

   ```markdown
   ---
   id: TSD-{NNN}
   title: {title}
   status: draft
   created: {today}
   owner: {gh-user}
   epic: {EPIC_ID}
   prd: PRD-{NNN}
   target_repos: [{automation-tests-repo}]
   precision_mode: {on | off}
   bdd_sources:
     - PRD-{NNN}-{cap-1}.feature
   test_case_sources:
     - PRD-{NNN}-cases.md
   automation_repo: {name}
   automation_stack: {stack hint}
   ---

   # TSD-{NNN}: {title}

   ## 1. Scope
   {2-3 sentences.}

   ## 2. Coverage matrix
   | Layer | In scope? | Why | Tool | Repo dir |
   |-------|-----------|-----|------|----------|
   | Unit (service-internal) | n/a | lives in service repo | | |
   | Integration | yes | contract stability | | |
   | End-to-end | yes | P0 coverage | | |
   | Contract | {y/n} | | | |
   | Performance | {y/n} | | | |
   | Security | {y/n} | | | |

   ## 3. Automation entry points
   - `e2e/…/….spec.ts` (create) — covers TC-… .
   - `integration/…/….test.ts` (create) — covers TC-… .

   ## 4. Test data strategy
   - Generation:
   - Seeding (per-suite / per-test):
   - Teardown:
   - Shared fixtures:
   - PII policy: synthetic only.

   ## 5. Environment matrix
   | Env | Stack version | Data | Parallelism | Notes |
   |-----|---------------|------|-------------|-------|

   ## 6. Quality gates
   - P0 must be green before merge.
   - P1 runs on CI; flakes tracked but non-blocking.
   - Contract tests block deploy to staging.

   ## 7. Parallelism plan
   - What runs in parallel; what cannot.
   - Isolation strategy (sharding, unique keys, tenant scoping).

   ## 8. Flaky-test isolation
   - `@flaky` tagging.
   - Retry policy per layer.
   - Flake log destination.

   ## 9. Observability
   - Dashboards, failure notifications, trend rollups.

   ## 10. Dependencies
   - Fixtures owned by:
   - External systems required:

   ## 11. Open questions
   ```

4. **Generate test ERD.** Write `qa/outputs/test-erd/TERD-{NNN}-{slug}.md`:

   ```markdown
   ---
   id: TERD-{NNN}
   parent_spec: TSD-{NNN}
   status: draft
   target_repos: [{automation-tests-repo}]
   precision_mode: {on | off}
   ---

   # Test ERD for TSD-{NNN}

   ```mermaid
   graph LR
     PRD[PRD-{NNN}] --> F1[Feature: …]
     F1 --> TC1[TC-001]
     F1 --> TC2[TC-002]
     TC1 --> E1[e2e/…spec.ts]
     TC2 --> E1
     TC1 --> I1[integration/…test.ts]
   ```

   ## Coverage gaps

   - {list any AC or TC without a target automation file}
   ```

5. **Update `EPIC-PIPELINE.md`.** Set `Test Spec` column to `TSD-{NNN}`.

6. **Grill pass.** Read `skills/grill-substrate.md` (single source for stance, scratch-block format, and `grilled:` frontmatter schema). Then:

   - **Targets:** the TSD (primary artifact) is grilled with the `test-spec` stance. The TERD is grilled separately as a follow-up pass with the `erd` stance (same depth) — ask the user whether to chain TERD grilling after TSD grilling (default Y).
   - **Mode (per repo, Resolution Z):** for each `repo` in the TSD's `target_repos`, use `/domain-grill` when `${WB_ROOT}/context/<repo>/CONTEXT.md` exists, otherwise fall back to `/grill-me` for that repo.
   - **Prompt (Option-B with teeth, batched):**
     ```
     TSD-{NNN} drafted at qa/outputs/test-spec/TSD-{NNN}-{slug}.md.
     Targets: automation-repo (domain-grill or grill-me), ...
     Prior grill: <none | YYYY-MM-DD depth (resolved N, parked M)>
     Run grill now? Depth? [deep|standard|quick] (default: deep)
     Chain TERD-{NNN} grill after? [Y/n] (default: Y)
     [Y/n/skip-this-session]
     ```
     Default Y on first run. Default n if `grilled.date` is current and artifact mtime less than or equal to `grilled.date`.
   - **Execute sequentially.** On `Y`, for each target repo: pre-stage the `test-spec` stance from §1 of `grill-substrate.md` (or `erd` stance when chaining the TERD pass) + the scratch-block format from §2, then invoke `Skill("domain-grill" | "grill-me", args=<depth>)` with `cwd=${WB_ROOT}/context/<repo>/` for domain-grill, or `cwd=${WB_ROOT}` for the fallback.
   - **Record per pass.** Append scratch block to the relevant file (TSD or TERD) + atomically extend that file's `grilled.passes` (tempfile + rename). Per-pass durability.
   - **Abort / skip / cascade-resume.** Per §4 cheat-sheet. Cascade prompt default Y. Never blocks.

7. **Tell the user:**

   > TSD-{NNN} + TERD-{NNN} drafted (status: draft). Publish and approve each:
   > ```
   > wb.publish TSD-{NNN}  qa/outputs/test-spec/TSD-{NNN}-{slug}.md  test-spec
   > wb.publish TERD-{NNN} qa/outputs/test-erd/TERD-{NNN}-{slug}.md  test-erd
   > wb.approve TSD-{NNN}
   > wb.approve TERD-{NNN}
   > ```
   > Next: `/ralph-workspace-plan` once PRD + SPEC + TDD + TSD are all approved.

## Output contract

- Creates: `qa/outputs/test-spec/TSD-{NNN}-{slug}.md`, `qa/outputs/test-erd/TERD-{NNN}-{slug}.md` — both `status: draft`.
- Modifies: `EPIC-PIPELINE.md`.

## Do not

- Do not duplicate engineering-spec content; reference it.
- Do not cover unit tests here — those live with service code.
