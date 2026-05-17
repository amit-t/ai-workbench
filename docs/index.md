---
title: Home
layout: default
---

{% include links.html %}

## What It Gives You

- **Shared private git repo** per bundle of one or more Jira epics.
- **Five role hats** in one place: PO, Architect, Staff Eng, UX, QA.
- **Three-stage lifecycle** for every artifact: `draft → published → approved`.
- **Single source of truth** for ralph: `.workbench-state/approved.json`.
- **Cross-repo ralph orchestration** — plan and dispatch across multiple service + automation repos.
- **One-way template updates** — pull skill improvements from the `ai-workbench` template without touching your outputs.

## Two Repos, One Story

| Repo | Role |
|------|------|
| [`ai-workbench`]({{ links.ai_workbench_repo }}) | Template. `gh repo create --template` stamps an instance per bundle. |
| [`ai-devkit`]({{ links.ai_devkit_repo }}) | Global CLI. Provides `init.wb`, `join.wb`, `update.wb`. |

## Quick Paths

- **New to this?** Start at [Getting started](./getting-started.html).
- **Don't know what step you're on?** Read [Workflows](./workflows.html) or run `wb.wtd` ([reference](./skills/wtd.html)).
- **Want the architecture?** [Architecture](./architecture.html).
- **Want to understand state transitions?** [Artifact lifecycle](./lifecycle.html).
- **Looking for a specific skill?** [Skills reference](./skills.html).
- **Ralph integration questions?** [Ralph integration](./ralph.html).
- **How steering works (golden principles, role rules, overlays)?** [Steering workflow](./steering/).
- **Update notifications + how to upgrade?** [Versioning + upgrades](./versioning.html).
- **Something unclear?** [FAQ](./faq.html).

## Typical Flow

```
Jira epic → /epic-intake → publish + approve
         → /prd-draft   → publish + approve
         → /eng-spec    → publish + approve  (dev hat)
         → /tdd         → publish + approve
         → /bdd-gen     → publish + approve  (QA hat)
         → /test-cases-gen → publish + approve
         → /test-spec   → publish + approve
         → /ralph-workspace-plan   (generates per-repo fix_plans)
         → /ralph-dispatch         (parallel autonomous execution)
```

## License

See repo license files.
