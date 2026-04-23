---
name: grill-me
description: Relentless interview that stress-tests a draft epic, PRD, spec, TDD, BDD, or design before approval. Walks the decision tree; resolves one branch at a time. Invoked by user explicitly or when reviewer asks "grill me".
category: Agent Behavior
---

# /grill-me

## When to use

- User wants gaps surfaced before moving an artifact from `draft` to `published`.
- Output of any other skill feels hand-wavy and the author wants it pressure-tested.
- Mentions of "grill me", "stress test", "poke holes", or "find gaps" in the prompt.

## Prerequisites

- A concrete target artifact. Either the path on disk or the artifact id plus `.workbench-state/`-resolvable location.
- The target is still `status: draft` (grilling after `approved` is too late — fork a follow-up PRD instead).

## Steps

1. **Load target.** Read the full artifact plus every referenced upstream artifact (epic-context for a PRD, PRD for a SPEC, SPEC for a TDD, etc.). If an upstream is missing or unapproved, flag it as the first gap and stop — grilling a PRD whose epic is unapproved wastes the session.

2. **Pick stance by artifact type.**
   - `epic-context` → business value, success metric, ownership, deadline reality.
   - `prd` → scope slice, acceptance criteria coverage, edge cases, non-goals honesty.
   - `eng-spec` → architecture fit, contract compatibility, rollback plan, observability.
   - `tdd` → testability, race conditions, failure modes, public API shape.
   - `bdd` / `test-cases` / `test-spec` → traceability, negative paths, non-functional coverage.
   - `design` artifacts → flow gaps, accessibility, empty/error/loading states.

3. **Walk the decision tree one branch at a time.** For each question: state the question, state your own recommended answer with a one-line justification, then ask the user to confirm, amend, or override. Do not batch. Do not accept hedging as an answer — push until the branch is resolved or explicitly parked.

4. **Explore instead of asking when the answer is on disk.** If a question can be resolved by reading a file in `repos/`, `product/`, `engineering/`, or `.workbench-state/`, read it first and present the finding instead of asking.

5. **Record findings inline** in a scratch block at the top of the artifact under an HTML comment, e.g.:

   ```markdown
   <!-- grill-me session {YYYY-MM-DD}
   - [resolved] non-goal for mobile clients — explicit now at §5
   - [parked]  SLO target — deferred to spec; tracked as GRILL-1
   - [open]    rollback strategy if migration partially applied
   -->
   ```

6. **Exit criteria.** End when: every branch resolved, every `[parked]` item has an owner + date, OR user types "stop grill". Summarise open items with a one-line recommendation each.

## Example question (for a PRD)

> **Q1 — Scope bleed.** Section 1 says "all authenticated users" but §4 AC-2 limits to admins. My read: the PRD is an admin-only slice and §1 should narrow. Agree, or is there a user-tier dimension I'm missing?

## Output contract

- Modifies (optional): adds a scratch `<!-- grill-me ... -->` block to the target artifact.
- Does not change `status`. Grilling never auto-publishes or auto-approves.

## Do not

- Do not edit the artifact body during the interview. Only the scratch block changes.
- Do not continue past 20 questions without summarising and asking the user whether to go deeper.
- Do not invent facts about upstream artifacts. Read them.
