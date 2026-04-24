---
title: Skills reference
layout: default
---

# Skills reference

18 skills ship with every workbench. All outputs land at `status: draft`; promotion happens via `wb.publish` then `wb.approve`. Click a skill to expand its summary, then follow the deep-dive link for inputs, frontmatter, and examples.

## Lifecycle at a glance

```
draft ──wb.publish──▶ published ──wb.approve──▶ approved ──▶ ralph consumes
  ▲                         │                        │
  └──────wb.reject──────────┴────────────────────────┘
```

Agents write `status: draft` only. Ralph reads strictly from `.workbench-state/approved.json`.

---

## Product (PO)

<details>
<summary><strong><code>/epic-intake</code></strong> — Pull Jira epic into workbench as draft context.</summary>

- **Input:** Jira epic ID.
- **Output:** `product/context-library/epics/<EPIC-ID>.md`
- **Unblocks:** `/prd-draft` once epic-context is `approved`.

[Deep dive →](skills/epic-intake.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/epic-intake/SKILL.md)

</details>

<details>
<summary><strong><code>/prd-draft</code></strong> — PRD from approved epic.</summary>

- **Input gate:** epic-context approved.
- **Output:** `product/outputs/prds/PRD-NNN-<slug>.md`
- **Unblocks:** `/eng-spec`, `/bdd-gen`, `/design-draft`.

[Deep dive →](skills/prd-draft.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/prd-draft/SKILL.md)

</details>

<details>
<summary><strong><code>/prd-review-panel</code></strong> — 7-perspective PRD review.</summary>

- **Input:** PRD draft.
- **Output:** Review file beside PRD. Blocks `wb.approve` on any P0.
- **Reviewers:** engineer, designer, executive, legal, UX research, skeptic, customer voice.

[Deep dive →](skills/prd-review-panel.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/prd-review-panel/SKILL.md)

</details>

---

## UX Design

<details>
<summary><strong><code>/design-draft</code></strong> — End-to-end UX workflow.</summary>

- **Input gate:** PRD approved.
- **Output:** `design/outputs/<PRD-NNN>/…`
- **Orchestrates:** `/figma-pull`, `/ds-screen-gen`, `/design-review`.

[Deep dive →](skills/design-draft.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/design-draft/SKILL.md)

</details>

<details>
<summary><strong><code>/figma-pull</code></strong> — Park Figma links; optional MCP export.</summary>

- **Input:** PRD ID + Figma URL.
- **Output:** `design/context-library/figma-links.md` and optional `design/outputs/screens/PRD-NNN/`.
- **Default path:** link parking only — no network call.

[Deep dive →](skills/figma-pull.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/figma-pull/SKILL.md)

</details>

<details>
<summary><strong><code>/ds-screen-gen</code></strong> — Hi-fi HTML/JSX from design-system ref.</summary>

- **Input:** PRD + `design/context-library/design-system-ref.md`.
- **Output:** `design/outputs/screens/PRD-NNN/` — every screen in default / empty / loading / error states.

[Deep dive →](skills/ds-screen-gen.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/ds-screen-gen/SKILL.md)

</details>

<details>
<summary><strong><code>/design-review</code></strong> — 5-perspective screen review.</summary>

- **Input:** Generated screen set.
- **Reviewers:** UX researcher, a11y auditor, engineer, brand guardian, end-user voice.
- **Blocks:** handoff until P0 items resolved.

[Deep dive →](skills/design-review.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/design-review/SKILL.md)

</details>

---

## Engineering

<details>
<summary><strong><code>/eng-spec</code></strong> — Architecture, contracts, data, rollout, observability.</summary>

- **Input gate:** PRD approved.
- **Output:** `engineering/outputs/specs/SPEC-NNN-<slug>.md`
- **Unblocks:** `/tdd`, `/erd`, `/adr`, `/ralph-workspace-plan`.

[Deep dive →](skills/eng-spec.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/eng-spec/SKILL.md)

</details>

<details>
<summary><strong><code>/tdd</code></strong> — Technical design doc: file map, interfaces, failure matrix.</summary>

- **Input gate:** eng-spec approved.
- **Output:** `engineering/outputs/tdd/TDD-NNN-<slug>.md`
- **Unblocks:** `/ralph-workspace-plan`.

[Deep dive →](skills/tdd.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/tdd/SKILL.md)

</details>

<details>
<summary><strong><code>/erd</code></strong> — Mermaid ER + C4-L2 component + optional sequence.</summary>

- **Input:** SPEC (may still be draft).
- **Output:** `engineering/outputs/erd/ERD-NNN-<slug>.md`
- **Renders in GitHub without external tooling.**

[Deep dive →](skills/erd.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/erd/SKILL.md)

</details>

<details>
<summary><strong><code>/adr</code></strong> — MADR-lite Architecture Decision Record.</summary>

- **Input:** SPEC (may still be draft) or standalone.
- **Output:** `engineering/outputs/adrs/ADR-NNN-<slug>.md`
- **Sections:** context, drivers, options (≥2), decision, consequences.

[Deep dive →](skills/adr.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/adr/SKILL.md)

</details>

---

## QA

<details>
<summary><strong><code>/bdd-gen</code></strong> — Gherkin <code>.feature</code> from approved PRD.</summary>

- **Input gate:** PRD approved.
- **Output:** `qa/outputs/bdd/<epic>.feature`
- **Coverage:** happy, edge, error, security paths.

[Deep dive →](skills/bdd-gen.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/bdd-gen/SKILL.md)

</details>

<details>
<summary><strong><code>/test-cases-gen</code></strong> — Expand BDDs into detailed test-case table.</summary>

- **Input gate:** BDDs approved.
- **Output:** `qa/outputs/test-cases/<epic>.md`
- **Fields:** priority, type, automation-candidate flag.

[Deep dive →](skills/test-cases-gen.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/test-cases-gen/SKILL.md)

</details>

<details>
<summary><strong><code>/test-spec</code></strong> — QA engineering spec + test ERD.</summary>

- **Input gate:** PRD + BDDs + test cases approved.
- **Output:** `qa/outputs/test-spec/<epic>.md`, `qa/outputs/test-erd/<epic>.md`
- **Covers:** coverage matrix, automation entry, test data, environments, parallelism, flaky strategy.

[Deep dive →](skills/test-spec.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/test-spec/SKILL.md)

</details>

---

## Orchestrator (ralph)

<details>
<summary><strong><code>/ralph-workspace-plan</code></strong> — Sync context and run workspace-mode plan.</summary>

- **Input gate:** PRD + eng-spec + TDD + test-spec approved.
- **Output:** `repos/*/ai/fix_plan.md` per-repo + workbench rollup.
- **Wraps:** `scripts/ralph-plan.sh`.

[Deep dive →](skills/ralph-workspace-plan.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/ralph-workspace-plan/SKILL.md)

</details>

<details>
<summary><strong><code>/ralph-dispatch</code></strong> — Parallel ralph loops across repos.</summary>

- **Input:** Approved fix_plans in `repos/*/ai/`.
- **Output:** Per-repo ralph loop state.
- **Net-new:** cross-repo parallelism — ralph native is within-repo only.

[Deep dive →](skills/ralph-dispatch.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/ralph-dispatch/SKILL.md)

</details>

---

## Cross-cutting

<details>
<summary><strong><code>/grill-me</code></strong> — Relentless decision-tree interview on any draft.</summary>

- **Input:** Any draft artifact (epic, PRD, SPEC, TDD, BDD, design).
- **Output:** Notes inline or companion file.
- **When:** before `wb.publish`, whenever reviewer says "grill me".

[Deep dive →](skills/grill-me.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/grill-me/SKILL.md)

</details>

<details>
<summary><strong><code>/pmo-status</code></strong> — Workbench status rollup.</summary>

- **Input:** None (read-only).
- **Output:** Terminal report of epics, PRDs, specs, TDDs, BDDs, fix_plan coverage per repo, dispatch state.
- **Source of truth:** `.workbench-state/`.

[Deep dive →](skills/pmo-status.html) · [Source](https://github.com/amit-t/ai-workbench/blob/main/skills/pmo-status/SKILL.md)

</details>

---

## Hat-by-hat summary

| Hat | Skills |
|-----|--------|
| Product (PO) | `/epic-intake`, `/prd-draft`, `/prd-review-panel` |
| UX Design | `/design-draft`, `/figma-pull`, `/ds-screen-gen`, `/design-review` |
| Engineering | `/eng-spec`, `/tdd`, `/erd`, `/adr` |
| QA | `/bdd-gen`, `/test-cases-gen`, `/test-spec` |
| Orchestrator | `/ralph-workspace-plan`, `/ralph-dispatch` |
| Cross-cutting | `/grill-me`, `/pmo-status` |
