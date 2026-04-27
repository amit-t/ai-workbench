---
title: /tdd
layout: default
eyebrow: ENG
subtitle: "Technical design doc — file map per repo, interfaces, sequence diagrams, failure matrix, test outline."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| Eng | Engineering | SPEC approved | `engineering/outputs/tdd/TDD-NNN-<slug>.md` | `/ralph-workspace-plan` |

## When to Use

SPEC is approved; user wants implementation-ready detail for ralph.

## Prerequisites

- SPEC `status: approved` AND in `.workbench-state/approved.json`.

## Protocol

1. Read SPEC (frontmatter + all sections).
2. For each repo in SPEC `target_repos`, identify concrete files to create or modify. Read `repos/{name}/` (read-only) for existing layout.
3. Write `engineering/outputs/tdd/TDD-{NNN}-{slug}.md` with 9 sections: Summary, File map per repo (Action / File / Purpose table), Key interfaces (ts code blocks), Sequence diagrams (Mermaid), Data shapes (ref ERD), Failure handling matrix, Test outline, Observability additions, Open questions.
4. Update `EPIC-PIPELINE.md` — set TDD column.

## Output Frontmatter

```yaml
id: TDD-{NNN}
title: {title}
status: draft
created: {today}
owner: {gh-user}
epic: {EPIC_ID}
prd: PRD-{NNN}
spec: SPEC-{NNN}
```

## File Map Table Shape

| Action | File | Purpose |
|--------|------|---------|
| Create | `src/adapters/in/http/…ts` | REST entry point |
| Modify | `src/core/services/….ts:45-120` | new method |

## Do Not

- Leave "TODO" in the file map. Ask the user if uncertain.
- Copy-paste code from `repos/*` without citing original file and line range.

## Source

[`skills/tdd/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/skills/tdd/SKILL.md)
