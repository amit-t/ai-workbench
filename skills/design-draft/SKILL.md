---
name: design-draft
description: End-to-end UX workflow for an approved PRD — brief, user flow, wireframes, hi-fi screens, review, handoff. Orchestrates sub-skills (/figma-pull, /ds-screen-gen, /design-review) and produces one design artifact per PRD ready for wb.publish.
category: UX Design
relevant_topics: []
---

# /design-draft

## When to use

- A PRD has reached `status: approved` and the UX designer (or a dev pinch-hitting) wants to run the full design pass.
- Resuming a partial design pass for the same PRD (skip steps whose outputs already exist).

## Prerequisites

- `.workbench-state/approved.json` contains the target PRD id. Refuse otherwise; tell the user to run `wb.approve PRD-{NNN}` first.
- `design/context-library/design-system-ref.md` is filled in (one DS block minimum) OR the user will be producing DS-free wireframes only.

## Steps

0. **Load steering.** No `artifact:design` scope ships in template yet; design artifacts do not yet have Layer 2 rules. Layer 0 (golden) loaded at session start and Layer 1 (`role:uxd`) loaded on UX role-switch remain in force. If a per-workbench team has added overlay rules under `steering.local/artifacts/design/`, run `wb.steering artifact:design` to pick them up. Sub-skills (`/figma-pull`, `/ds-screen-gen`, `/design-review`) each run their own step 0 when invoked. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none by default).

1. **Locate the PRD.** Read `product/outputs/prds/PRD-{NNN}-*.md`. Extract: title, user stories, personas, acceptance criteria, explicit out-of-scope.

2. **Set up output scaffold.** Ensure these dirs exist: `design/outputs/briefs/`, `design/outputs/user-flows/`, `design/outputs/wireframes/`, `design/outputs/screens/PRD-{NNN}/`, `design/outputs/handoffs/`.

3. **Step A — Brief.** Ask only for gaps the PRD does not answer:
   - visual direction adjectives (2-4 words)
   - mode (light / dark / both)
   - hard constraints not in PRD

   Write `design/outputs/briefs/PRD-{NNN}-brief.md`. If it already exists, print and ask: use existing, or revise?

4. **Step B — User flow.** Map happy path + key edges (rate-limit, partial-auth, disabled-account, offline). Write `design/outputs/user-flows/PRD-{NNN}-flow.md` with a Mermaid `flowchart`. Skip if the file exists and user confirms current.

5. **Step C — Wireframes.** ASCII wireframes per screen in the flow. Focus on information hierarchy and nav, not colour. Write `design/outputs/wireframes/PRD-{NNN}-wireframes.md`.

6. **Step D — Screens.** Invoke `/ds-screen-gen PRD-{NNN}` if a DS is in use, else `/figma-pull PRD-{NNN}` if Figma is the source of truth. Both end with `design/outputs/screens/PRD-{NNN}/index.md` at `status: draft`.

7. **Step E — Review.** Invoke `/design-review PRD-{NNN}`. Block advancement if any P0 items come back — loop back to Step D to regenerate affected screens.

8. **Step F — Handoff.** Write `design/outputs/handoffs/PRD-{NNN}-handoff.md`:

   ```markdown
   ---
   id: DESIGN-HANDOFF-PRD-{NNN}
   status: draft
   prd: PRD-{NNN}
   design_index: design/outputs/screens/PRD-{NNN}/index.md
   review: design/outputs/handoffs/PRD-{NNN}-review.md
   owner: {gh-user}
   ---

   # Handoff — PRD-{NNN}

   ## Screens
   - {list linking into screens/}

   ## Tokens
   - Primary / secondary / semantic colours (named, not hex)
   - Type scale
   - Spacing scale

   ## Components mapping
   | HTML/JSX component | DS component | Notes |

   ## States per screen
   | Screen | Default | Empty | Loading | Error | Success |

   ## Open items
   - [ ] {item with owner}
   ```

9. **Resume support.** If the user passes `--from {step}` (brief / flow / wireframes / screens / review / handoff), jump to that step and only re-read prior outputs — do not regenerate them.

10. **Publish prompts.** At the end, print exactly:

    ```
    Design pass complete for PRD-{NNN}.

    Publish steps (run when ready):
      wb.publish DESIGN-PRD-{NNN} design/outputs/screens/PRD-{NNN}/index.md design
      wb.publish DESIGN-HANDOFF-PRD-{NNN} design/outputs/handoffs/PRD-{NNN}-handoff.md design
      wb.approve DESIGN-PRD-{NNN}
      wb.approve DESIGN-HANDOFF-PRD-{NNN}
    ```

    Do not auto-publish.

## Output contract

- Creates (all at `status: draft`): brief, flow, wireframes, screens dir + index.md, design-review output, handoff.
- Does not modify `.workbench-state/*`.
- Modifies `EPIC-PIPELINE.md` only if there is a Design column for this PRD — update with `~` (draft present).

## Do not

- Do not start without an approved PRD.
- Do not skip the review step just because a P0 would delay the pass — that is exactly when it matters.
- Do not silently overwrite a prior handoff. Diff and ask.
