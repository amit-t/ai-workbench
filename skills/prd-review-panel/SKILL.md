---
name: prd-review-panel
description: 7-perspective parallel review of a draft PRD — engineer, designer, executive, legal, UX research, skeptic, customer voice. Writes a review file beside the PRD and blocks wb.approve if any reviewer flags a P0.
category: Product Management
relevant_topics: []
---

# /prd-review-panel

## When to use

- PRD is at `status: draft` and the author wants gap-finding before publishing.
- Author is about to run `wb.publish PRD-{NNN}` but wants panel sign-off first.

## Prerequisites

- `product/outputs/prds/PRD-{NNN}-*.md` exists with `status: draft` in frontmatter.
- Epic-context for the PRD is in `.workbench-state/approved.json`. (Reviewing a PRD with an unapproved epic is waste — refuse and tell user to approve the epic first.)
- Context-library content in `product/context-library/` is readable (strategy, research, personas) when present.

## Steps

0. **Load steering.** Run `wb.steering artifact:prd` (or `python3 scripts/steering-load.py artifact:prd`) so reviewer agents hold the PRD to the same constraints the author was meant to obey. The review must enforce those rules, not invent new ones. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none by default).

1. **Read the PRD in full.** Extract:
   - Problem, hypothesis, goal
   - User / stakeholder lists, persona refs
   - Acceptance criteria
   - Non-goals
   - Success metrics
   - Rollout plan (if present)
   - Technical approach (if present)
   - Risks, open questions

2. **Determine focus.** PRD frontmatter may carry `stage: {kickoff | planning | xfn | solution | launch}` — adjust reviewer emphasis. If no stage given, default to `planning`.

3. **Dispatch 7 reviewer subagents in parallel** (single message, 7 Task calls). Each receives the full PRD text + stage + relevant context-library excerpts. Rubrics:

   **1. Engineering** — feasibility, dependencies/integration, scalability, edge cases, estimate realism.
   **2. Design** — user experience, interaction patterns, information architecture, missing states.
   **3. Executive** — strategic fit, opportunity cost, investment vs return, portfolio effects.
   **4. Legal / Compliance** — data handling, regulatory exposure, contract impact, accessibility law.
   **5. UX Research** — validation evidence, assumptions without data, research gaps.
   **6. Skeptic** — challenge every assumption, surface unstated risks, attack the hypothesis.
   **7. Customer Voice** — first-person persona reaction to the proposed feature.

   Every reviewer outputs exactly this shape:
   ```
   ✅ What works
   ⚠️ Concerns (each tagged P0 / P1 / P2)
   ❌ Blockers
   💡 Suggestions
   ```

   Instruct reviewers to cite PRD section numbers — "§4 AC-2" beats "section about acceptance".

4. **Synthesise** to `product/outputs/prds/PRD-{NNN}-review.md`:

   ```markdown
   ---
   id: PRD-{NNN}-REVIEW
   status: draft
   prd: PRD-{NNN}
   stage: {stage}
   reviewed: {today}
   reviewers: [eng, design, exec, legal, uxr, skeptic, customer]
   ---

   # PRD review panel — PRD-{NNN}

   ## 1. Engineering
   {verbatim agent output}

   ## 2. Design
   ...
   ## 3. Executive
   ...
   ## 4. Legal
   ...
   ## 5. UX Research
   ...
   ## 6. Skeptic
   ...
   ## 7. Customer Voice
   ...

   ## Synthesis
   ### Consensus
   - ...
   ### Disagreements
   - ...
   ### Priority fix list
   1. 🔴 P0 — {fix} — blocks approval
   2. 🟡 P1 — {fix}
   3. 🟢 P2 — {nice-to-have}
   ```

5. **Block approval on open P0s.** Count P0s across reviewers. If > 0, print:

   > {N} P0 issue(s) block approval. Revise PRD and re-run `/prd-review-panel PRD-{NNN}`.

   Do not attempt to `wb.approve`. Clean reviews read:

   > Review clean of P0s. Next:
   > ```
   > wb.publish PRD-{NNN} product/outputs/prds/PRD-{NNN}-<slug>.md prd
   > wb.publish PRD-{NNN}-REVIEW product/outputs/prds/PRD-{NNN}-review.md prd
   > wb.approve PRD-{NNN}
   > ```

6. **Flags:**
   - `--perspectives "eng,design,skeptic"` → subset mode (any of the 7 names; comma-separated).
   - `--stage {name}` → override stage from frontmatter.

## Output contract

- Creates: `product/outputs/prds/PRD-{NNN}-review.md` at `status: draft`.
- Read-only on the PRD file itself.
- Does not auto-approve or auto-publish.

## Do not

- Do not collapse verbatim reviewer output.
- Do not approve the PRD automatically, even with zero P0s. The user calls `wb.approve`.
- Do not dispatch fewer than the requested reviewers — if context is missing for one (e.g. no legal docs for a minor change), still run the reviewer and have it say "no material legal exposure" explicitly.
- Do not skip citing section numbers — ungrounded critique is noise.
