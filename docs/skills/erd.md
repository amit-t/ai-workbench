---
title: /erd
layout: default
eyebrow: ENG
subtitle: "Mermaid ER + C4-level-2 component diagram + optional hot-path sequence. Renders in GitHub without external tooling."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output | Referenced by |
|-----|-------|---------------|--------|---------------|
| Eng | Engineering | SPEC exists (may still be `draft`) | `engineering/outputs/erd/ERD-NNN-<slug>.md` | TDD §Data shapes, test spec |

## When to Use

- SPEC §5 "Data model" or §3 "Architecture impact" is material.
- Cross-service data flow needs a C4-L2 view.
- Reviewer asked "where does X live" during `/grill-me`.

## Prerequisites

- Related SPEC exists at `engineering/outputs/specs/SPEC-{NNN}-<slug>.md` (may still be `draft`).
- `project.conf REPOS` populated — every diagram box must map to a repo.

## Diagram Set (Default: All Three)

| Diagram | Required when | Type |
|---------|---------------|------|
| **DB-ERD** | SPEC §5 introduces schema changes | Mermaid `erDiagram` — tables, PK/FK, cardinality |
| **C4-L2 component** | SPEC §3 lists new services or cross-service contracts | Mermaid `flowchart LR` — services, ports, adjacent systems |
| **Sequence** | Contract has > 2 hops | Mermaid `sequenceDiagram` — hot-path request flow |

## Protocol

1. Pick ERD number — scan `engineering/outputs/erd/ERD-*.md`, max + 1, three-digit pad. Slug matches SPEC where possible.
2. Ask diagram set (default all three).
3. Write `engineering/outputs/erd/ERD-{NNN}-{slug}.md` with §1 DB-ERD, §2 C4-L2 component, §3 sequence (optional), §4 change summary table, §5 migration notes (forward + rollback).
4. Back-link SPEC §5 `ERD: see …` → `See ERD-{NNN}` **only if SPEC still `draft`**.
5. Append row under epic's ERD section in `EPIC-PIPELINE.md`.

## Output Frontmatter

```yaml
id: ERD-{NNN}
title: {title}
status: draft
created: {today}
owner: {gh-user}
epic: {EPIC_ID}
related_spec: SPEC-{NNN}
```

## Do Not

- Embed screenshots — Mermaid only, so diagrams review as text in PRs.
- Invent services or tables. Every box must map to a repo in `project.conf` or an approved SPEC section.
- Produce an empty ERD (no diagram types).

## Source

[`skills/erd/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/skills/erd/SKILL.md)
