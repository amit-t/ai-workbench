---
title: Home
layout: default
---

## What it gives you

- **Shared private git repo** per bundle of one or more Jira epics.
- **Five role hats** in one place: PO, Architect, Staff Eng, UX, QA.
- **Three-stage lifecycle** for every artifact: `draft → published → approved`.
- **Single source of truth** for ralph: `.workbench-state/approved.json`.
- **Cross-repo ralph orchestration** — plan and dispatch across multiple service + automation repos.
- **One-way template updates** — pull skill improvements from the `ai-workbench` template without touching your outputs.

## Two repos, one story

| Repo | Role |
|------|------|
| [`ai-workbench`](https://github.com/amit-t/ai-workbench) | Template. `gh repo create --template` stamps an instance per bundle. |
| [`ai-devkit`](https://github.com/amit-t/ai-devkit) | Global CLI. Provides `init.wb`, `join.wb`, `update.wb`. |

## Quick paths

- **New to this?** Start at [Getting started](./getting-started.html).
- **Want the architecture?** [Architecture](./architecture.html).
- **Want to understand state transitions?** [Artifact lifecycle](./lifecycle.html).
- **Looking for a specific skill?** [Skills reference](./skills.html).
- **Ralph integration questions?** [Ralph integration](./ralph.html).
- **Something unclear?** [FAQ](./faq.html).

## Typical flow

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
