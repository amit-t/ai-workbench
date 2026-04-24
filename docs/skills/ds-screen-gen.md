---
title: /ds-screen-gen
layout: default
eyebrow: UXD
subtitle: "Hi-fi HTML or JSX screens for a PRD using the design system referenced in `design/context-library/design-system-ref.md`. Every screen ships default / empty / loading / error states."
---

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| UXD | Design gen | PRD + design-system-ref block | `design/outputs/screens/PRD-NNN/{screen}.{ext}` + `index.md` | `/design-review` |

## When to Use

- No Figma file (or `/figma-pull` returned nothing) and team needs a working preview.
- Engineer wants a prototype screen to plug into frontend stack before final design lands.

## Prerequisites

- `design/context-library/design-system-ref.md` has ≥ 1 DS block (name, repo/doc, tokens URL, primary components, framework target).
- `{PRD-NNN}` approved, OR user explicitly confirms prototyping ahead of approval.
- `design/outputs/screens/{PRD-NNN}/` writable (create if missing).

## Protocol

1. Read DS reference → extract `name`, `framework target` (drives HTML vs JSX), `primary components`, tokens URL. Multi-DS → ask which.
2. Read PRD for title, user stories, ACs, screen-naming hints. No PRD → refuse.
3. **Propose screen list before generating.** Happy path + top 2 error/empty paths. Confirm with user — don't burn tokens on 15 speculative screens.
4. Pick output format from DS block:
    - `React + TypeScript, Tailwind` → `.tsx` with Tailwind classes from token mapping.
    - `HTML + CSS` → single `.html` per screen with `<link>` to DS stylesheet or inline tokens.
    - Else → ask user for extension.
5. Generate each screen at `design/outputs/screens/PRD-{NNN}/{screen-slug}.{ext}`:
    - Import/link DS tokens + components (no re-declared tokens).
    - Show all four states (in one file with toggles, or sibling `-loading` / `-error` files). Pick one convention per PRD.
    - Semantic HTML — `<main>`, `<nav>`, `<form>` with labels. A11y is not a follow-up.
6. Write `index.md` with `status: draft` — table of screens + states.

## Output Frontmatter (`index.md`)

```yaml
id: DESIGN-PRD-{NNN}
status: draft
prd: PRD-{NNN}
source: ds-screen-gen
ds: {DS name}
framework: {framework target}
generated: {today}
```

## Do Not

- Invent DS tokens or component names. Missing components → flag in `index.md` under `## Missing components` and stop depending on them.
- Inline brand colours as hex — use DS tokens.
- Skip empty / error states. Single-state screen is a prototype at best; wastes review cycles.

## Source

[`skills/ds-screen-gen/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/ds-screen-gen/SKILL.md)
