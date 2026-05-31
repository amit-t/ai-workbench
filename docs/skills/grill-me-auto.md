---
title: /grill-me-auto
layout: default
eyebrow: Cross-Cutting
subtitle: "Batch-mode /grill-me. Same rigorous stress test, written as one collapsible markdown doc. Review async, answer in one reply."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output |
|-----|-------|---------------|--------|
| Cross-cutting | Review helper | Any draft artifact | `.grills/<YYYY-MM-DD-HHMM>-<slug>-<depth>.md` |

## When to Use

- Same triggers as `/grill-me`, but you do not want a live one-question-at-a-time interview.
- Reviewing on mobile, on a flight, or async with a teammate.
- A draft with many open branches where seeing the whole question set at once helps you spot patterns.

If you want the live interview, use `/grill-me`. For engineering-only grilling against `CONTEXT.md` / ADRs, use `/domain-grill`.

## Prerequisites

- Concrete target — prompt text, artifact path, or artifact id resolvable via `.workbench-state/`.
- Target still `status: draft`. Same rule as `/grill-me`.

## Invocation

```text
/grill-me-auto                # asks for depth, defaults to deep
/grill-me-auto deep           # pre-select
/grill-me-auto standard
/grill-me-auto quick
/Grill Me Auto                # also accepted
/grill me auto                # also accepted
```

| Depth | Coverage | Typical count |
|---|---|---|
| `deep` (default) | every branch, edge case, contradiction, code/doc cross-check | 20–40+ |
| `standard` | critical assumptions, main edge cases, obvious cross-checks | 15–25 |
| `quick` | highest-leverage deal-breakers and dead-on-arrival risks only | 5–10 |

## Protocol

1. Resolve depth. Echo it.
2. Silently read prompt, repo, `CONTEXT.md`, ADRs, touched files. Do not ask what you can read.
3. Write the grill document atomically to `.grills/<YYYY-MM-DD-HHMM>-<slug>-<depth>.md`. Stage `/.grills/` in `.gitignore` if missing.
4. Each top-level question is a collapsible `<details>` block carrying: question, *Why it matters*, labelled options (`N.A` / `N.B` / …), recommendation, alt. Conditional sub-questions (`2a`, `2b`) nest inside the parent.
5. Authored prose inside the doc is written under `precision-mode` (lead with the answer, no filler, no echo). Markdown scaffolding and security / breaking-change / data-loss caveats are exempt.
6. Hand off in one line and stop. The document is the deliverable; the agent does not summarise the questions in chat.

## Answering

Three reply paths, in this order:

1. `accept all my recommendations` (alias `ACCEPT_ALL_RECOMMENDATIONS`)
2. `accept all my alt recommendations` (alias `ACCEPT_ALL_ALT_RECOMMENDATIONS`). If Alt is `n/a`, falls back to the primary recommendation and is flagged.
3. Filled per-question block, one `N: <A|B|C|D|rec|alt>` line per question. Mix-and-match.

Agent applies the answers in one pass, updates frontmatter to `status: answered`, appends `## Resolved answers`, and asks before moving to implementation.

## Do Not

- Run on `published` or `approved` artifacts. Fork a follow-up PRD instead.
- Skip the depth step. Default `deep`, but the user controls it.
- Summarise questions in chat or paste the doc body. The file is the deliverable.

## Source

[`.agents/skills/grill-me-auto/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/.agents/skills/grill-me-auto/SKILL.md) · [`README.md`]({{ links.ai_workbench_repo }}/blob/main/.agents/skills/grill-me-auto/README.md) · [`REFERENCE.md`]({{ links.ai_workbench_repo }}/blob/main/.agents/skills/grill-me-auto/REFERENCE.md)
