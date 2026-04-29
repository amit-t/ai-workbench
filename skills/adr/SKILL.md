---
name: adr
description: Architecture Decision Record at status=draft. Writes engineering/outputs/adrs/ADR-NNN-<slug>.md in the MADR-lite format — context, drivers, options, decision, consequences. Cross-links into the originating SPEC and TDD.
category: Engineering
relevant_topics: []
---

# /adr

## When to use

- While drafting or reviewing an engineering spec / TDD, a decision emerges that is larger than one spec and worth recording separately (tech choice, pattern adoption, cross-cutting contract, irreversible action).
- `/grill-me` on a SPEC flagged an unsettled architectural branch — promote that to an ADR.

## Prerequisites

- Related SPEC exists (can still be `draft`; ADR does not need an approved SPEC).
- `engineering/outputs/adrs/` exists.

## Steps

0. **Load steering.** Run `wb.steering artifact:adr` (or `python3 scripts/steering-load.py artifact:adr`). Treat the merged ruleset as hard constraints on context framing, option enumeration, decision rationale, and consequence honesty. The loader emits an empty merged blob when no `artifact:adr` rules ship yet; that is fine, the hook is in place for when the council adds them. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none by default).

1. **Pick ADR number.** Scan `engineering/outputs/adrs/ADR-*.md`, take max + 1, zero-pad to three digits.

2. **Pick a slug.** Ask the user — kebab-case, 3-6 words, decision-oriented ("use-postgres-for-audit-log" not "database").

3. **Identify drivers.** Ask the user for the 3–5 forces shaping the decision. Examples: performance budget, team skill, existing infra, SLO target, compliance, reversibility cost.

4. **Enumerate at least 2 options.** A one-option ADR is a red flag — if only one option was considered, challenge the user to articulate the rejected alternatives before writing. If nothing else was ever viable, document that explicitly.

5. **Write `engineering/outputs/adrs/ADR-{NNN}-{slug}.md`:**

   ```markdown
   ---
   id: ADR-{NNN}
   title: {decision-oriented title}
   status: draft
   created: {today}
   owner: {gh-user}
   epic: {EPIC_ID or "cross-cutting"}
   related_spec: {SPEC-NNN or "—"}
   supersedes: {ADR-NNN or "—"}
   superseded_by: —
   ---

   # ADR-{NNN}: {title}

   ## Context
   {2-4 paragraphs. State the situation, not the answer. Include constraints the reader would not know from the spec alone.}

   ## Decision drivers
   - {driver 1 — with a concrete threshold where possible}
   - {driver 2}

   ## Options considered

   ### Option A: {name}
   - Pros: {bullets}
   - Cons: {bullets}
   - Cost / effort: {S / M / L / XL + one-line rationale}

   ### Option B: {name}
   - Pros:
   - Cons:
   - Cost / effort:

   ### Option C: {name} (if applicable)
   ...

   ## Decision
   **Chosen:** Option {X}.
   **Why:** {2-3 sentences tying back to the drivers.}

   ## Consequences
   ### Positive
   - {what gets easier}
   ### Negative
   - {what gets harder — be honest}
   ### Follow-ups required
   - [ ] {action with owner}

   ## References
   - SPEC: {SPEC-NNN}
   - TDD: {TDD-NNN or "—"}
   - External: {links, RFCs, benchmarks}
   ```

6. **Cross-link.** In the related SPEC's `## 11. Dependencies → ADRs` and (if present) the TDD's "Decisions" section, add `ADR-{NNN}`. If SPEC is `approved`, do not mutate it — print a diff for the user and instruct them to publish a new revision.

7. **Update `EPIC-PIPELINE.md`.** Under the epic's `### ADRs` section (add heading if missing), append `| ADR-{NNN} {title} | draft |`.

8. **Tell the user next steps:**

   > ADR-{NNN} drafted (status: draft). Review, then:
   > ```
   > wb.publish ADR-{NNN} engineering/outputs/adrs/ADR-{NNN}-{slug}.md adr
   > wb.approve ADR-{NNN}   # after review
   > ```

## Output contract

- Creates: `engineering/outputs/adrs/ADR-{NNN}-{slug}.md` with `status: draft`.
- Modifies: `EPIC-PIPELINE.md`. Possibly related SPEC/TDD (only if they are still `draft`).

## Do not

- Do not write an ADR with one option. Force an alternative or justify its absence.
- Do not claim a decision is reversible when it is not. Name the cost of reversal.
- Do not mutate an `approved` SPEC or TDD — print the diff and let the user decide.
