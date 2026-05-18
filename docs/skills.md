---
title: Skills Reference
layout: default
eyebrow: Skills
subtitle: "19 skills, one panel per hat. Lost in the pipeline? Run `wb.wtd` ([ref](skills/wtd.html)) or read [Workflows](workflows.html)."
---

*Prefer the old long-form? See [V1 archive](./v1/skills.html).*

## Lifecycle at a glance

```
draft ──wb.publish──▶ published ──wb.approve──▶ approved ──▶ ralph consumes
  ▲                         │                        │
  └──────wb.reject──────────┴────────────────────────┘
```

Agents write `status: draft` only. Ralph reads strictly from `.workbench-state/approved.json`.

---

## Browse by hat

<details markdown="1">
<summary><strong>Product (PO)</strong> · 3 skills · epic intake → PRD draft → PRD review panel</summary>

| Skill | Purpose | Input gate |
|---|---|---|
| [`/epic-intake`](skills/epic-intake.html) | Pull Jira epic as draft context | none (entry point) |
| [`/prd-draft`](skills/prd-draft.html) | PRD from approved epic | epic-context approved |
| [`/prd-review-panel`](skills/prd-review-panel.html) | 7-perspective PRD review; blocks approve on P0 | PRD draft |

</details>

<details markdown="1">
<summary><strong>UX Design</strong> · 4 skills · orchestrator + Figma + screen gen + review</summary>

| Skill | Purpose | Input gate |
|---|---|---|
| [`/design-draft`](skills/design-draft.html) | End-to-end UX; orchestrates the three below | PRD approved |
| [`/figma-pull`](skills/figma-pull.html) | Park Figma links; optional MCP export | PRD ID + Figma URL |
| [`/ds-screen-gen`](skills/ds-screen-gen.html) | Hi-fi HTML/JSX from design-system ref (default / empty / loading / error states) | PRD + design-system ref |
| [`/design-review`](skills/design-review.html) | 5-perspective screen review; blocks handoff on P0 | generated screen set |

</details>

<details markdown="1">
<summary><strong>Engineering</strong> · 4 skills · spec → TDD → ERD → ADR</summary>

| Skill | Purpose | Input gate |
|---|---|---|
| [`/eng-spec`](skills/eng-spec.html) | Architecture, contracts, data, rollout, observability | PRD approved |
| [`/tdd`](skills/tdd.html) | Technical design doc: file map, interfaces, failure matrix | eng-spec approved |
| [`/erd`](skills/erd.html) | Mermaid ER + C4-L2 + optional sequence (renders in GitHub) | SPEC (may be draft) |
| [`/adr`](skills/adr.html) | MADR-lite Architecture Decision Record | SPEC if exists, else none |

</details>

<details markdown="1">
<summary><strong>QA</strong> · 3 skills · BDDs → test cases → test spec</summary>

| Skill | Purpose | Input gate |
|---|---|---|
| [`/bdd-gen`](skills/bdd-gen.html) | Gherkin `.feature` (happy / edge / error / security) | PRD approved |
| [`/test-cases-gen`](skills/test-cases-gen.html) | BDDs → priority / type / automation-flag table | BDDs approved |
| [`/test-spec`](skills/test-spec.html) | QA engg spec + test ERD: coverage, data, envs, flaky strategy | PRD + BDDs + test cases approved |

</details>

<details markdown="1">
<summary><strong>Orchestrator (Ralph)</strong> · 2 skills · workspace plan → parallel dispatch</summary>

| Skill | Purpose | Input gate |
|---|---|---|
| [`/ralph-workspace-plan`](skills/ralph-workspace-plan.html) | Sync context, run workspace-mode plan, write per-repo `fix_plan.md` | PRD + eng-spec + TDD + test-spec approved |
| [`/ralph-dispatch`](skills/ralph-dispatch.html) | Parallel ralph loops across repos (cross-repo; ralph-native is within-repo) | approved fix_plans in `repos/*/ai/` |

</details>

<details markdown="1">
<summary><strong>Cross-Cutting</strong> · 3 skills · grill-me + PMO status + WTD</summary>

| Skill | Purpose | Input gate |
|---|---|---|
| [`/grill-me`](skills/grill-me.html) | Relentless decision-tree interview on any draft before publish | any draft artifact |
| [`/pmo-status`](skills/pmo-status.html) | Terminal rollup of epics, PRDs, specs, TDDs, BDDs, fix_plan coverage, dispatch state | none (read-only) |
| [`/wtd`](skills/wtd.html) | What-To-Do — single next command per epic; the trimmer cousin of pmo-status | none (read-only) |

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
| Cross-cutting | `/grill-me`, `/pmo-status`, `/wtd` |
