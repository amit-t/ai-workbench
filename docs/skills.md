---
title: Skills reference
layout: default
kicker: Skills
eyebrow: skills
tagline: Eighteen bundled skills. Slash commands grouped by role — PO, dev, QA, UX, and agent ops.
---

# Skills reference

Every workbench ships with the skills below, bundled under `skills/` and symlinked at `init.wb` time into `.claude/skills/`, `.agents/skills/`, and `.devin/skills/`. Each is invoked as a slash command (e.g. `/prd-draft`).

Skills marked **stub** have frontmatter only — the full body lands in Plan D.

## Product Management

| Skill | Status | Description |
|-------|--------|-------------|
| [`/epic-intake`](https://github.com/amit-t/ai-workbench/blob/main/skills/epic-intake/SKILL.md) | ready | Pull a Jira epic body into `product/context-library/epics/`, stamp as draft, prep for `/prd-draft`. |
| [`/prd-draft`](https://github.com/amit-t/ai-workbench/blob/main/skills/prd-draft/SKILL.md) | ready | Draft a PRD under an approved epic at `status=draft`. |
| [`/prd-review-panel`](https://github.com/amit-t/ai-workbench/blob/main/skills/prd-review-panel/SKILL.md) | stub | Multi-perspective review of a draft PRD (engineer, QA, designer, exec, skeptic, PM, end-user). |

## Engineering

| Skill | Status | Description |
|-------|--------|-------------|
| [`/eng-spec`](https://github.com/amit-t/ai-workbench/blob/main/skills/eng-spec/SKILL.md) | ready | Engineering spec draft from an approved PRD — architecture, contracts, data, rollout, observability. |
| [`/tdd`](https://github.com/amit-t/ai-workbench/blob/main/skills/tdd/SKILL.md) | ready | Technical design document from an approved engineering spec — file map per repo, interfaces, sequence diagrams, failure matrix. |
| [`/erd`](https://github.com/amit-t/ai-workbench/blob/main/skills/erd/SKILL.md) | stub | Entity-relationship + component diagrams for the change. |
| [`/adr`](https://github.com/amit-t/ai-workbench/blob/main/skills/adr/SKILL.md) | stub | Architecture Decision Record — context, options, decision, consequences. |
| [`/ralph-workspace-plan`](https://github.com/amit-t/ai-workbench/blob/main/skills/ralph-workspace-plan/SKILL.md) | ready | Sync approved context and invoke ralph workspace-mode plan; produces per-repo fix_plans + workbench rollup. |
| [`/ralph-dispatch`](https://github.com/amit-t/ai-workbench/blob/main/skills/ralph-dispatch/SKILL.md) | ready | Launch parallel autonomous ralph loops across workbench-registered repos. |

## QA

| Skill | Status | Description |
|-------|--------|-------------|
| [`/bdd-gen`](https://github.com/amit-t/ai-workbench/blob/main/skills/bdd-gen/SKILL.md) | ready | Generate Gherkin `.feature` files from an approved PRD — happy/edge/error/security paths. |
| [`/test-cases-gen`](https://github.com/amit-t/ai-workbench/blob/main/skills/test-cases-gen/SKILL.md) | ready | Expand approved BDD scenarios into detailed test cases (priority, type, automation flags). |
| [`/test-spec`](https://github.com/amit-t/ai-workbench/blob/main/skills/test-spec/SKILL.md) | ready | QA engineering spec — coverage matrix, automation entry points, test data, environments, parallelism. Also drafts the test ERD. |

## UX Design

| Skill | Status | Description |
|-------|--------|-------------|
| [`/figma-pull`](https://github.com/amit-t/ai-workbench/blob/main/skills/figma-pull/SKILL.md) | stub | Park Figma links in `design/context-library/figma-links.md`; optional Figma MCP pull. |
| [`/ds-screen-gen`](https://github.com/amit-t/ai-workbench/blob/main/skills/ds-screen-gen/SKILL.md) | stub | Generate lightweight HTML/JSX screens using the referenced team design system. |
| [`/design-draft`](https://github.com/amit-t/ai-workbench/blob/main/skills/design-draft/SKILL.md) | stub | End-to-end UX workflow — interview, user flow, wireframes, hi-fi screens, handoff. |
| [`/design-review`](https://github.com/amit-t/ai-workbench/blob/main/skills/design-review/SKILL.md) | stub | Multi-agent design review — UX, a11y, engineering feasibility, brand, end-user. |

## Project Management / Agent Behavior

| Skill | Status | Description |
|-------|--------|-------------|
| [`/grill-me`](https://github.com/amit-t/ai-workbench/blob/main/skills/grill-me/SKILL.md) | stub | Relentless interview to stress-test a plan, PRD, spec, or design. |
| [`/pmo-status`](https://github.com/amit-t/ai-workbench/blob/main/skills/pmo-status/SKILL.md) | stub | Cross-cutting status view — epics, PRDs, specs, BDDs, fix_plan coverage, ralph dispatch state. Use at session start. |
