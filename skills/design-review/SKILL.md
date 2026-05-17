---
name: design-review
description: 5-perspective review of a generated screen set — UX researcher, accessibility auditor, engineer, brand guardian, end-user voice. Writes review synthesis beside the screens and blocks handoff until P0 items are resolved.
category: UX Design
relevant_topics: []
---

# /design-review

## When to use

- `/design-draft` reached Step E, or
- Screens exist under `design/outputs/screens/PRD-{NNN}/` and the user wants a pre-handoff audit.

## Prerequisites

- `design/outputs/screens/PRD-{NNN}/index.md` exists with at least one screen referenced.
- Related PRD readable at `product/outputs/prds/PRD-{NNN}-*.md` — used to check flow coverage and acceptance criteria alignment.

## Steps

0. **Load steering.** No `artifact:design` scope ships in template yet; design artifacts do not yet have Layer 2 rules. Layer 0 (golden) loaded at session start and Layer 1 (`role:uxd`) loaded on UX role-switch remain in force, plus the same `artifact:prd` rules that the PRD author obeyed (run `wb.steering artifact:prd` so reviewer agents hold screens to PRD constraints, not their own opinion). If a per-workbench team has added overlay rules under `steering.local/artifacts/design/`, also run `wb.steering artifact:design`. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none by default).

1. **Load targets in parallel.**
   - PRD (problem, AC, personas, out-of-scope)
   - `design/outputs/briefs/PRD-{NNN}-brief.md` (stated visual direction)
   - `design/outputs/screens/PRD-{NNN}/index.md` and every screen file it references
   - `design/context-library/brand/*` if present
   - `design/context-library/personas/*` if present

1.4. **Precision receipt (info only, P3).** Read the design index's `precision_mode:` frontmatter field. Three states:
   - `on`  — surface as `P3 — Authored with precision_mode: on (dense by default).`
   - `off` — surface as `P3 — Authored with precision_mode: off (narrative voice).`
   - absent — surface as `P3 — Authored with precision_mode: legacy (predates Phase 3).`

   P3 is informational only — no severity, no blocking. Helps reviewers calibrate expectations.

1.5. **Grill receipt check.** Read the design index's `grilled:` frontmatter block (per `skills/grill-substrate.md` §3). Compute:
   - `grill_status: ungrilled` — block absent.
   - `grill_status: incomplete` — any `passes[].result` is not `resolved`.
   - `grill_status: complete` — block present and every `passes[].result == "resolved"`.

   When `grill_status` is `ungrilled` or `incomplete`, the synthesis step below must surface a P2 finding under the UX Researcher section:

   ```
   P2 — Ungrilled artifact — manual scrutiny recommended.
       grill_status: {ungrilled | incomplete}; passes: {summary or "absent"}.
       Re-run /design-draft grill step (or /grill-me on the design index) before handoff.
   ```

   Never blocks handoff. P2 only.

2. **Dispatch 5 reviewer subagents in parallel** (single message, 5 Task calls). Each receives: the full PRD text, the brief, the screen file, brand + personas context, and their own rubric below. Do not inline-review — the parallel dispatch keeps context lean per agent.

   **Rubrics:**

   **Reviewer 1 — UX Researcher**
   - Does the flow match how the persona thinks?
   - Cognitive load hotspots?
   - First-time user friction?
   - Output: `✅ Works · ⚠️ Concerns (severity H/M/L) · 💡 Suggestions · ❓ To validate`

   **Reviewer 2 — Accessibility Auditor (WCAG 2.1 AA)**
   - Contrast, keyboard nav, screen reader (semantic HTML / ARIA), touch targets (≥44px), focus indicators, motion safety (`prefers-reduced-motion`), form labels / errors / instructions.
   - Output: `✅ Passes · ❌ Failures (WCAG criterion + critical/major/minor) · 💡 Fixes (code)`.

   **Reviewer 3 — Engineer**
   - Component reusability, CSS complexity, responsive effort, DS alignment, perf hotspots.
   - Output: `✅ Easy · ⚠️ Concerns (effort S/M/L/XL) · 💡 Suggestions · 🔴 Blockers`.

   **Reviewer 4 — Brand Guardian**
   - Colour / typography / spacing / component style / copy voice vs brand docs.
   - Output: `✅ On-brand · ⚠️ Deviations · 💡 Corrections`.

   **Reviewer 5 — End-User Voice (persona speaks first person)**
   - "My first reaction is…", delight, confusion, questions, elevator pitch to a friend.
   - Output: `First impression · 😍 · 😕 · 🤔 · 💬`.

3. **Synthesise** into `design/outputs/handoffs/PRD-{NNN}-review.md`:

   ```markdown
   ---
   id: DESIGN-REVIEW-PRD-{NNN}
   status: draft
   prd: PRD-{NNN}
   design_index: design/outputs/screens/PRD-{NNN}/index.md
   reviewed: {today}
   reviewers: [ux, a11y, eng, brand, user]
   ---

   # Design review — PRD-{NNN}

   ## 1. UX Researcher
   {agent output verbatim}

   ## 2. Accessibility
   ...

   ## 3. Engineer
   ...

   ## 4. Brand
   ...

   ## 5. End-User Voice
   ...

   ## Synthesis
   ### Agreed across reviewers
   - ...
   ### Conflicts (where reviewers disagree)
   - ...

   ## Priority fix list
   1. 🔴 P0 — {fix} — blocks handoff
   2. 🟡 P1 — {fix}
   3. 🟢 P2 — {nice-to-have}
   ```

4. **Gate handoff.** Count P0 items. If > 0, print:

   > {N} P0 issue(s) block handoff. Run `/ds-screen-gen PRD-{NNN} --fix-p0` (or manually revise screens), then re-run `/design-review PRD-{NNN}`.

   If P0 == 0, print:

   > Review clean of P0 issues. Ready for handoff.
   > `wb.publish DESIGN-REVIEW-PRD-{NNN} design/outputs/handoffs/PRD-{NNN}-review.md design`

5. **Flags:**
   - `--quick` → run only UX + Accessibility (fastest, for iteration).
   - `--full` → all five (default; required before handoff).

## Output contract

- Creates: `design/outputs/handoffs/PRD-{NNN}-review.md` at `status: draft`.
- Read-only on the screen files themselves.
- Does not auto-publish or auto-approve.

## Do not

- Do not collapse reviewer output. Verbatim agent responses go in the synthesis — this is how trust accrues for future panels.
- Do not call handoff "clean" with open P0s, even if the user presses. The gate is on the artifact, not the conversation.
- Do not fire fewer than 5 agents when `--full` is the mode — parallel dispatch is the whole point.
