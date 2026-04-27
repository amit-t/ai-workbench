---
title: /design-review
layout: default
eyebrow: UXD
subtitle: "5-perspective review of a generated screen set — UX researcher, accessibility auditor, engineer, brand guardian, end-user voice. Blocks handoff on any P0."
---

{% include links.html %}

| Hat | Stage | Upstream gate | Output | Blocks |
|-----|-------|---------------|--------|--------|
| UXD | Design review | `design/outputs/screens/PRD-NNN/index.md` exists | `design/outputs/handoffs/PRD-NNN-review.md` | design handoff on any P0 |

## When to Use

- `/design-draft` reached Step E, or
- Screens exist under `design/outputs/screens/PRD-{NNN}/` and user wants pre-handoff audit.

## Prerequisites

- Screen `index.md` exists with ≥ 1 screen referenced.
- Related PRD readable at `product/outputs/prds/PRD-{NNN}-*.md`.

## Reviewers (Dispatched in Parallel)

| # | Reviewer | Lens | Output shape |
|---|----------|------|--------------|
| 1 | UX Researcher | Flow match persona, cognitive load, first-time friction | `✅ Works · ⚠️ Concerns (H/M/L) · 💡 · ❓` |
| 2 | A11y Auditor (WCAG 2.1 AA) | Contrast, keyboard nav, SR/ARIA, touch targets ≥44px, focus indicators, `prefers-reduced-motion`, form labels/errors | `✅ · ❌ Failures (WCAG criterion + severity) · 💡 Fixes (code)` |
| 3 | Engineer | Reusability, CSS complexity, responsive effort, DS alignment, perf | `✅ Easy · ⚠️ (S/M/L/XL) · 💡 · 🔴 Blockers` |
| 4 | Brand Guardian | Colour / typography / spacing / style / copy voice vs brand docs | `✅ On-brand · ⚠️ Deviations · 💡` |
| 5 | End-User Voice (persona, first-person) | "My first reaction is…", delight, confusion, elevator pitch | `First impression · 😍 · 😕 · 🤔 · 💬` |

## Protocol

1. Load targets in parallel — PRD, brief, `index.md` + every screen file referenced, `design/context-library/brand/*`, `design/context-library/personas/*` (when present).
2. Dispatch 5 reviewer subagents in parallel (single message, 5 Task calls). Each gets PRD + brief + screen file + brand + personas + own rubric. Parallel dispatch keeps context lean.
3. Synthesise to `design/outputs/handoffs/PRD-{NNN}-review.md` with sections 1–5 (verbatim agent output), Synthesis (Agreed / Conflicts), Priority fix list (🔴 P0 / 🟡 P1 / 🟢 P2).
4. Gate — count P0s. > 0 → block. == 0 → clean, print publish prompt.

## Flags

- `--quick` — UX + A11y only (fastest; iteration).
- `--full` — all 5 (default; required before handoff).

## Do Not

- Collapse reviewer output. Verbatim agent responses in synthesis — trust accrues.
- Call handoff "clean" with open P0s, even if user presses. Gate is on artifact, not conversation.
- Fire fewer than 5 agents when `--full` is the mode — parallel dispatch is the point.

## Source

[`skills/design-review/SKILL.md`]({{ links.ai_workbench_repo }}/blob/main/skills/design-review/SKILL.md)
