---
title: /prd-draft
layout: default
eyebrow: PO
subtitle: "Draft a PRD under an approved epic — goals, users, scope, NFRs, acceptance."
---

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| PO | Product | `epic-context` approved | `product/outputs/prds/PRD-NNN-<slug>.md` | `/eng-spec`, `/bdd-gen`, `/design-draft` |

## When to Use

An epic-context file is approved and the user wants to scope a PRD.

## Prerequisites

- Epic context at `product/context-library/epics/{EPIC_ID}.md`.
- `.workbench-state/approved.json` contains `id: epic-{EPIC_ID}`. Otherwise refuse and instruct `wb.publish` + `wb.approve`.

## Protocol

1. Compute next PRD number — scan `product/outputs/prds/PRD-*.md`, max + 1, zero-padded three digits.
2. Pick slug (kebab-case, 2–4 words).
3. Gather scope: problem slice, non-goals, change surface (service / automation / both).
4. Write `product/outputs/prds/PRD-{NNN}-{slug}.md` with 9 sections: Problem, Goal, Users+Stakeholders, Acceptance criteria, Non-goals, Dependencies, Open questions, Risks, Metrics.
5. Update `EPIC-PIPELINE.md` — append PRD row.

## Output Frontmatter

```yaml
id: PRD-{NNN}
title: {short title}
status: draft
created: {today}
owner: {gh-user}
epic: {EPIC_ID}
scope: {service | automation | both}
```

## Do Not

- Copy into any gate folder — gate is `.workbench-state/approved.json`, not a directory.
- Span multiple epics in one PRD. If scope leaks, split into two.

## Source

[`skills/prd-draft/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/prd-draft/SKILL.md)
