---
title: /design-draft
layout: default
---

[← Back to skills](../skills.html)

# /design-draft

> End-to-end UX workflow for an approved PRD — brief, user flow, wireframes, hi-fi screens, review, handoff. Orchestrates `/figma-pull`, `/ds-screen-gen`, `/design-review`.

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| UXD | Design | PRD approved | `design/outputs/{briefs,user-flows,wireframes,screens,handoffs}/PRD-NNN-*` | Engineering handoff |

## When to use

- PRD reached `status: approved` and UX designer (or dev pinch-hitting) wants to run the full design pass.
- Resuming a partial pass for same PRD (skip steps whose outputs exist).

## Prerequisites

- `.workbench-state/approved.json` contains the target PRD. Refuse otherwise.
- `design/context-library/design-system-ref.md` filled in (≥ 1 DS block) OR user producing DS-free wireframes only.

## Protocol — 6 steps, 6 artifacts

| # | Step | Artifact |
|---|------|----------|
| A | Brief | `design/outputs/briefs/PRD-{NNN}-brief.md` |
| B | User flow (Mermaid `flowchart`) | `design/outputs/user-flows/PRD-{NNN}-flow.md` |
| C | Wireframes (ASCII) | `design/outputs/wireframes/PRD-{NNN}-wireframes.md` |
| D | Screens — invoke `/ds-screen-gen` (DS present) or `/figma-pull` (Figma is truth) | `design/outputs/screens/PRD-{NNN}/index.md` |
| E | Review — invoke `/design-review`; P0 fails loop back to Step D | `design/outputs/handoffs/PRD-{NNN}-review.md` |
| F | Handoff (tokens, components mapping, states per screen, open items) | `design/outputs/handoffs/PRD-{NNN}-handoff.md` |

## Resume support

`--from {step}` (brief / flow / wireframes / screens / review / handoff) — jump; read prior outputs, don't regenerate.

## Publish prompts (prints verbatim at end)

```
wb.publish DESIGN-PRD-{NNN} design/outputs/screens/PRD-{NNN}/index.md design
wb.publish DESIGN-HANDOFF-PRD-{NNN} design/outputs/handoffs/PRD-{NNN}-handoff.md design
wb.approve DESIGN-PRD-{NNN}
wb.approve DESIGN-HANDOFF-PRD-{NNN}
```

## Do not

- Start without an approved PRD.
- Skip review just because P0s would delay — that's exactly when it matters.
- Silently overwrite a prior handoff. Diff and ask.

## Source

[`skills/design-draft/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/design-draft/SKILL.md)
