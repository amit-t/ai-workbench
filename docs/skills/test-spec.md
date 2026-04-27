---
title: /test-spec
layout: default
eyebrow: QA
subtitle: "QA engineering spec + test ERD — coverage matrix, automation entry, test data, envs, parallelism, flaky strategy."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| QA | QA | PRD + BDDs + test cases approved | `qa/outputs/test-spec/TSD-NNN-<slug>.md` + `qa/outputs/test-erd/TERD-NNN-<slug>.md` | `/ralph-workspace-plan` |

## When to Use

Approved PRD + approved BDDs + approved test cases. User wants QA engg spec before kicking automation into ralph.

## Prerequisites

- PRD, BDDs, test-case set — all at `approved`.
- `project.conf REPOS` has at least one `role=automation-tests` entry.

## Protocol

1. Read inputs — PRD, all approved `PRD-{NNN}-*.feature`, `PRD-{NNN}-cases.md`, `qa/context-library/` conventions.
2. Identify automation repo from `project.conf REPOS` + stack hint.
3. Write `qa/outputs/test-spec/TSD-{NNN}-{slug}.md` with 11 sections: Scope, Coverage matrix (Unit / Integration / E2E / Contract / Perf / Security), Automation entry points, Test data strategy (PII synthetic-only), Environment matrix, Quality gates (P0 blocks merge), Parallelism plan (isolation strategy), Flaky-test isolation (@flaky, retry policy), Observability, Dependencies, Open questions.
4. Write `qa/outputs/test-erd/TERD-{NNN}-{slug}.md` — Mermaid `graph LR` linking PRD → Features → TCs → automation files, plus Coverage gaps section.
5. Update `EPIC-PIPELINE.md` — set Test Spec column.

## Output Frontmatter

```yaml
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
```

## Do Not

- Duplicate engineering-spec content — reference it.
- Cover unit tests here — those live with service code.

## Source

[`skills/test-spec/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/skills/test-spec/SKILL.md)
