---
name: prd-draft
description: Draft a PRD at status=draft under an approved epic. Writes product/outputs/prds/PRD-NNN-<slug>.md.
category: Product Management
relevant_topics: []
---

# /prd-draft

## When to use

An epic-context file is approved and the user wants to scope a PRD.

## Prerequisites

- Epic context file exists at `product/context-library/epics/{EPIC_ID}.md`.
- `.workbench-state/approved.json` contains `id: epic-{EPIC_ID}`. If not: stop, instruct user to run `wb.publish epic-{EPIC_ID} <path> epic-context` then `wb.approve epic-{EPIC_ID}` after review.

## Steps

0. **Load steering.** Run `wb.steering artifact:prd` (or `python3 scripts/steering-load.py artifact:prd`). Treat the merged ruleset as hard constraints on every section written below. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none for PRDs by default).

1. **Compute the next PRD number.** Scan `product/outputs/prds/PRD-*.md` (ignore any under deprecated `approved/` subfolder — it should not exist after Phase 2 migration). Take max numeric part + 1, zero-pad to three digits.

2. **Pick a slug.** Ask the user — kebab-case, 2–4 words.

3. **Gather scope inputs.** Read the epic context + any related approved PRDs. Ask:
   - What problem slice does this PRD cover? (one sentence)
   - Non-goals?
   - Scope: service change, automation change, or both?
   - **Which code repos does this PRD route to?** Offer the `project.conf REPOS` list. Pick one or more. Used as `target_repos:` frontmatter; validated at `wb.publish` and `wb.approve` — missing or unknown repo names block the transition.

4. **Write `product/outputs/prds/PRD-{NNN}-{slug}.md`:**

   ```markdown
   ---
   id: PRD-{NNN}
   title: {short title}
   status: draft
   created: {today}
   owner: {gh-user from `git config user.email` or `gh api user -q .login`}
   epic: {EPIC_ID}
   scope: {service | automation | both}
   target_repos: [{repo-1}, {repo-2}]
   ---

   # PRD-{NNN}: {title}

   ## 1. Problem

   {2-4 sentences tied to the epic. Name specific users, workflows, or systems.}

   ## 2. Goal

   {One-sentence outcome after ship.}

   ## 3. Users and stakeholders

   - Primary: {who}
   - Affected: {who else}

   ## 4. Acceptance criteria

   Given/When/Then preferred. Cover happy path + top edge cases.

   - [ ] {AC-1}
   - [ ] {AC-2}

   ## 5. Non-goals

   - {explicit}

   ## 6. Dependencies

   - Other PRDs: {list or "none"}
   - External systems: {list or "none"}
   - Design assets: {link or "none"}

   ## 7. Open questions

   - {Q1}

   ## 8. Risks

   - {R1}

   ## 9. Metrics

   - {success signal}
   ```

5. **Update `EPIC-PIPELINE.md`.** Under `## EPIC {EPIC_ID}` → `### PRDs`, append row:

   ```
   | PRD-{NNN} {title} | draft | — | — | — | — | — | — | — |
   ```

6. **Grill pass.** Read `skills/grill-substrate.md` (single source for stance, scratch-block format, and `grilled:` frontmatter schema). Then:

   - **Mode:** PRDs always grill via `/grill-me`. No per-repo split (`repo: null`).
   - **Prompt (Option-B with teeth):**
     ```
     PRD-{NNN} drafted at product/outputs/prds/PRD-{NNN}-{slug}.md.
     Prior grill: <none | YYYY-MM-DD depth (resolved N, parked M)>
     Run /grill-me now? Depth? [deep|standard|quick] (default: deep)
     [Y/n/skip-this-session]
     ```
     Default Y on first run. Default n if `grilled.date` is current and artifact mtime less than or equal to `grilled.date`.
   - **Execute.** On `Y`: pre-stage the `prd` stance from §1 of `grill-substrate.md` + the scratch-block format from §2, then invoke `Skill("grill-me", args=<depth>)`.
   - **Record.** On pass end, append the scratch block to the PRD body (after frontmatter) and atomically update the `grilled:` frontmatter block per §3 of `grill-substrate.md` (tempfile + rename).
   - **Abort / skip / cascade-resume.** Follow §4 cheat-sheet. Never blocks; outcomes flow to `wb.publish` (warning) and `prd-review-panel` (P2 finding).

7. **Tell the user next steps:**

   > PRD-{NNN} drafted at `product/outputs/prds/PRD-{NNN}-{slug}.md` (status: draft).
   > Review, then: `wb.publish PRD-{NNN} product/outputs/prds/PRD-{NNN}-{slug}.md prd`.
   > After panel review (optional: `/prd-review-panel PRD-{NNN}` once that skill exists), approve: `wb.approve PRD-{NNN}`.

## Output contract

- Creates: `product/outputs/prds/PRD-{NNN}-{slug}.md` with `status: draft`.
- Modifies: `EPIC-PIPELINE.md`.

## Do not

- Do not copy into any gate folder — the gate is `.workbench-state/approved.json`, not a directory.
- Do not span multiple epics in one PRD. If the scope leaks, stop and ask whether it should become two PRDs.
