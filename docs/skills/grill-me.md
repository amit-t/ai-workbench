---
title: /grill-me
layout: default
eyebrow: CROSS-CUTTING
subtitle: "Relentless interview that stress-tests any draft artifact before approval. Walks the decision tree one branch at a time."
---

| Hat | Stage | Upstream gate | Output |
|-----|-------|---------------|--------|
| Cross-cutting | Review helper | Any draft artifact | Inline `<!-- grill-me … -->` scratch block on target |

## When to use

- User wants gaps surfaced before moving an artifact from `draft` → `published`.
- Any other skill's output feels hand-wavy.
- Prompt mentions "grill me", "stress test", "poke holes", "find gaps".

## Prerequisites

- Concrete target — path on disk or artifact id resolvable via `.workbench-state/`.
- Target still `status: draft`. Grilling after `approved` is too late — fork a follow-up PRD instead.

## Stance by artifact type

| Type | Stance |
|------|--------|
| `epic-context` | Business value, success metric, ownership, deadline reality |
| `prd` | Scope slice, AC coverage, edge cases, non-goals honesty |
| `eng-spec` | Architecture fit, contract compatibility, rollback, observability |
| `tdd` | Testability, race conditions, failure modes, public API shape |
| `bdd` / `test-cases` / `test-spec` | Traceability, negative paths, non-functional coverage |
| Design artifacts | Flow gaps, a11y, empty/error/loading states |

## Protocol

1. Load target + every referenced upstream. Missing/unapproved upstream → flag as first gap and stop.
2. Pick stance by artifact type.
3. Walk decision tree **one branch at a time**. Format: state question → state own recommended answer with one-line justification → ask user to confirm / amend / override. No batching. No hedging.
4. **Explore before asking** — if answer is on disk (`repos/`, `product/`, `engineering/`, `.workbench-state/`), read first, present finding.
5. Record findings inline in HTML comment:

    ```markdown
    <!-- grill-me session {YYYY-MM-DD}
    - [resolved] non-goal for mobile clients — explicit now at §5
    - [parked]  SLO target — deferred to spec; tracked as GRILL-1
    - [open]    rollback strategy if migration partially applied
    -->
    ```

6. Exit when every branch resolved, every `[parked]` item has owner + date, OR user types "stop grill". Summarise opens with one-line recommendations.

## Do not

- Edit artifact body during interview. Only scratch block changes.
- Continue past 20 questions without summarising and asking user whether to go deeper.
- Invent facts about upstream artifacts. Read them.

## Source

[`skills/grill-me/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/grill-me/SKILL.md)
