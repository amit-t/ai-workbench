---
title: /adr
layout: default
---

[← Back to skills](../skills.html)

# /adr

> MADR-lite Architecture Decision Record — context, drivers, options, decision, consequences. Cross-links SPEC + TDD.

| Hat | Stage | Upstream gate | Output | Cited from |
|-----|-------|---------------|--------|------------|
| Eng | Engineering | SPEC exists (may be draft) OR standalone | `engineering/outputs/adrs/ADR-NNN-<slug>.md` | SPEC §11 Dependencies → ADRs, TDD §Decisions |

## When to use

- While drafting / reviewing a SPEC or TDD, a decision emerges that is larger than one spec (tech choice, pattern adoption, cross-cutting contract, irreversible action).
- `/grill-me` on a SPEC flagged an unsettled architectural branch — promote to ADR.

## Prerequisites

- Related SPEC exists (can still be `draft`; ADR does **not** need an approved SPEC).
- `engineering/outputs/adrs/` exists.

## Protocol

1. Pick ADR number — scan `engineering/outputs/adrs/ADR-*.md`, max + 1, three-digit pad.
2. Pick slug — kebab-case, 3–6 words, decision-oriented (`use-postgres-for-audit-log` not `database`).
3. Identify drivers — 3–5 forces. Include concrete thresholds where possible (e.g. `p99 < 50ms`).
4. Enumerate at least 2 options. One-option ADRs are refused — force alternatives or justify absence.
5. Write `engineering/outputs/adrs/ADR-{NNN}-{slug}.md` with Context, Decision drivers, Options considered (≥2, each with Pros / Cons / Cost), Decision (+ why), Consequences (positive, negative, follow-ups), References.
6. Cross-link SPEC §11 and TDD §Decisions. If upstream `approved`, **print diff only** — do not mutate.
7. Update `EPIC-PIPELINE.md` under epic's `### ADRs` section.

## Output frontmatter

```yaml
id: ADR-{NNN}
title: {decision-oriented title}
status: draft
created: {today}
owner: {gh-user}
epic: {EPIC_ID or "cross-cutting"}
related_spec: {SPEC-NNN or "—"}
supersedes: {ADR-NNN or "—"}
superseded_by: —
```

## Do not

- Write an ADR with one option. Force an alternative or explicitly justify its absence.
- Claim a decision is reversible without naming the cost of reversal.
- Mutate an `approved` SPEC or TDD — print the diff and let the user decide.

## Source

[`skills/adr/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/adr/SKILL.md)
