---
name: ds-screen-gen
description: Generate hi-fi HTML or JSX screens for a PRD using the design system referenced in design/context-library/design-system-ref.md. Use when Figma assets are missing or a fast prototype is needed. Every screen ships with default, empty, loading, and error states.
category: UX Design
relevant_topics: []
---

# /ds-screen-gen

## When to use

- No Figma file exists (or `/figma-pull` returned nothing) and the team needs a working preview.
- Engineer wants a prototype screen to plug into the frontend stack before final design lands.

## Prerequisites

- `design/context-library/design-system-ref.md` contains at least one DS block — name, repo/doc, tokens URL, primary components, framework target. Otherwise refuse and tell the user to fill it in (example block already in the file).
- `{PRD-NNN}` is approved OR user explicitly confirms prototyping ahead of approval.
- `design/outputs/screens/{PRD-NNN}/` is writable (create if missing).

## Steps

0. **Load steering.** No `artifact:design` scope is defined yet; design artifacts do not yet have Layer 2 rules in template. Layer 0 (golden) loaded at session start and Layer 1 (`role:uxd`) loaded on UX role-switch remain in force. If a per-workbench team has added overlay rules under `steering.local/artifacts/design/`, run `wb.steering artifact:design` to pick them up. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none by default).

1. **Read the DS reference.** Parse `design/context-library/design-system-ref.md`. Extract: `name`, `framework target` (drives HTML vs JSX), `primary components`, token URL. If multiple DS blocks exist, ask the user which one.

2. **Read the PRD.** Pull title, user stories, acceptance criteria, and any screen-naming hints from `product/outputs/prds/PRD-{NNN}-*.md`. If no PRD exists, refuse.

3. **Propose a screen list.** Derive from user flow: happy path + the top 2 error/empty paths. Present to the user before generating — do not burn tokens on 15 screens speculatively.

   ```
   Proposed screens for PRD-{NNN}:
     1. sign-in-default
     2. sign-in-error-invalid-credentials
     3. sign-in-loading
   Confirm? (y / edit list)
   ```

4. **Pick output format.** From DS block:
   - `React + TypeScript, Tailwind` → write `.tsx` with Tailwind classes from the DS token mapping.
   - `HTML + CSS` → write a single `.html` per screen with a `<link>` to the DS stylesheet (or inline tokens when DS ships CSS custom properties).
   - Anything else → ask the user for the exact file extension before generating.

5. **Generate each screen.** For each, produce a file under `design/outputs/screens/PRD-{NNN}/{screen-slug}.{ext}` that:
   - imports / links the DS tokens and components (do not re-declare tokens inline).
   - shows all four states (default / empty / loading / error) — either in one file with state toggles or in sibling files (`-loading`, `-error`). Pick one convention per PRD and stick to it.
   - uses semantic HTML (`<main>`, `<nav>`, `<form>` with labels) — accessibility cannot be a follow-up.

6. **Write an index** `design/outputs/screens/PRD-{NNN}/index.md`:

   ```markdown
   ---
   id: DESIGN-PRD-{NNN}
   status: draft
   prd: PRD-{NNN}
   source: ds-screen-gen
   ds: {DS name from ref}
   framework: {framework target}
   generated: {today}
   ---

   # Screens — PRD-{NNN}

   | Screen | File | States |
   |--------|------|--------|
   | Sign-in — default | sign-in-default.tsx | default, empty, loading, error |
   ```

7. **Offer the next skill:**

   > Screens drafted for PRD-{NNN} at `design/outputs/screens/PRD-{NNN}/`.
   > Next: `/design-review PRD-{NNN}` for the 5-perspective audit, then
   > `wb.publish DESIGN-PRD-{NNN} design/outputs/screens/PRD-{NNN}/index.md design`.

## Output contract

- Creates: one file per screen under `design/outputs/screens/PRD-{NNN}/`, plus `index.md` at `status: draft`.
- Does not mutate `.workbench-state/*` — publish is a separate step.

## Do not

- Do not invent DS tokens or component names. If a required component is missing from the DS, flag it in `index.md` under a `## Missing components` section and stop generating screens that depend on it.
- Do not inline brand colours as hex — use DS tokens.
- Do not skip empty/error states. A single-state screen is a prototype at best and wastes review cycles.
