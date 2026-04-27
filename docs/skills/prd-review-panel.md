---
title: /prd-review-panel
layout: default
eyebrow: PO
subtitle: "7-perspective parallel review of a draft PRD. Blocks `wb.approve` if any reviewer flags a P0."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output | Blocks |
|-----|-------|---------------|--------|--------|
| PO | Product review | PRD at `draft` + epic approved | `product/outputs/prds/PRD-NNN-review.md` | `wb.approve PRD-NNN` on any P0 |

## When to Use

- PRD is at `status: draft` and author wants gap-finding before publishing.
- Author about to `wb.publish PRD-NNN` and wants panel sign-off first.

## Prerequisites

- PRD file at `product/outputs/prds/PRD-{NNN}-*.md` with `status: draft`.
- Epic-context approved in `.workbench-state/approved.json` (unapproved epic → waste; refuse).

## Reviewers (Dispatched in Parallel)

| # | Reviewer | Lens |
|---|----------|------|
| 1 | Engineering | Feasibility, dependencies, scalability, edge cases, estimate realism |
| 2 | Design | UX, interaction patterns, IA, missing states |
| 3 | Executive | Strategic fit, opportunity cost, ROI, portfolio effects |
| 4 | Legal / Compliance | Data handling, regulatory exposure, contract impact, a11y law |
| 5 | UX Research | Validation evidence, unvalidated assumptions, research gaps |
| 6 | Skeptic | Challenge every assumption, unstated risks, attack the hypothesis |
| 7 | Customer Voice | First-person persona reaction |

Every reviewer outputs: `✅ What works / ⚠️ Concerns (P0/P1/P2) / ❌ Blockers / 💡 Suggestions`. Must cite PRD section numbers (e.g. `§4 AC-2`).

## Protocol

1. Read PRD in full (problem, hypothesis, goal, stakeholders, ACs, non-goals, metrics, rollout, approach, risks).
2. Resolve `stage` from frontmatter (`kickoff | planning | xfn | solution | launch`); default `planning`.
3. Dispatch 7 reviewers in parallel (single message, 7 Task calls) — each gets full PRD + stage + context-library.
4. Synthesise to `product/outputs/prds/PRD-{NNN}-review.md` with Consensus / Disagreements / Priority fix list (🔴 P0 / 🟡 P1 / 🟢 P2).
5. Count P0. If > 0, block and instruct author to revise + re-run.

## Flags

- `--perspectives "eng,design,skeptic"` — subset mode.
- `--stage {name}` — override frontmatter stage.

## Do Not

- Collapse verbatim reviewer output — verbatim goes into the synthesis.
- Auto-approve, even with zero P0s. User calls `wb.approve`.
- Dispatch fewer than requested reviewers — run empty ones ("no material legal exposure") explicitly.
- Skip section-number citations.

## Source

[`skills/prd-review-panel/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/skills/prd-review-panel/SKILL.md)
