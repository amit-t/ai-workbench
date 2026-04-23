---
name: test-spec
description: QA engineering spec at status=draft — coverage matrix, automation entry points, test data, environments, parallelism, flaky-test strategy. Also drafts the test ERD.
category: QA
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

1. **Read inputs.** PRD, all approved `qa/outputs/bdd/PRD-{NNN}-*.feature`, `qa/outputs/test-cases/PRD-{NNN}-cases.md`. Read `qa/context-library/` for existing automation conventions.

2. **Identify the automation repo.** Pull from `project.conf REPOS`. Capture name + stack hint.

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

6. **Tell the user:**

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
