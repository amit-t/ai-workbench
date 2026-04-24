---
title: /eng-spec
layout: default
eyebrow: ENG
subtitle: "Engineering spec from an approved PRD — architecture, contracts, data, rollout, observability."
---

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| Eng | Engineering | PRD approved | `engineering/outputs/specs/SPEC-NNN-<slug>.md` | `/tdd`, `/erd`, `/adr`, `/ralph-workspace-plan` |

## When to Use

User has an approved PRD and wants to draft the engineering spec.

## Prerequisites

- PRD `status: approved` AND in `.workbench-state/approved.json`.
- `project.conf REPOS` populated.

## Protocol

1. Read PRD (frontmatter + all sections). Identify outcomes and constraints.
2. Read engineering context — `engineering/context-library/` stack notes; approved ADRs only from `engineering/outputs/adrs/`.
3. Pick SPEC number — scan `engineering/outputs/specs/SPEC-*.md`, max + 1, three-digit pad. Slug matches PRD slug.
4. Decide per repo: modified? yes/no with one-liner.
5. Write `engineering/outputs/specs/SPEC-{NNN}-{slug}.md` with 11 sections: Scope, Target repos, Architecture impact, API+contracts, Data model, Rollout, Observability, Failure modes, Rollback, Risks+opens, Dependencies (ADRs / other SPECs / external teams).
6. Update `EPIC-PIPELINE.md` — set PRD row's Spec column.

## Output Frontmatter

```yaml
id: SPEC-{NNN}
title: {title}
status: draft
created: {today}
owner: {gh-user}
epic: {EPIC_ID}
prd: PRD-{NNN}
target_repos:
  - {repo-1}
```

## Do Not

- Include class-level pseudocode — that's `/tdd`.
- Produce a spec without an approved PRD.

## Source

[`skills/eng-spec/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/eng-spec/SKILL.md)
