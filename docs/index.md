---
title: Home
layout: default
---

*Prefer the old long-form? See [V1 archive](./v1/).*

{% include links.html %}

A per-bundle workbench: one private repo where a dev + QA pair carry one or more Jira epics from PRD to shipped code via ralph.

## What you get

- **Private git repo per bundle**, shared between two collaborators.
- **Five role hats** in one place: PO, Architect, Staff Eng, UX, QA.
- **Three-stage lifecycle** for every artifact: `draft → published → approved`.
- **Single ralph gate**: `.workbench-state/approved.json`.
- **Cross-repo orchestration**: workspace-mode plan + parallel dispatch.
- **One-way template updates**: pull skill improvements without touching your outputs.

## Two repos

| Repo | Role |
|------|------|
| [`ai-workbench`]({{ links.ai_workbench_repo }}) | Template. `init.wb` stamps a private instance per bundle. |
| [`ai-devkit`]({{ links.ai_devkit_repo }}) | Global CLI: `init.wb`, `join.wb`, `wb.upgrade`. |

## Where to go

- New here → [Getting started](./getting-started.html)
- Lost in the pipeline → [Workflows](./workflows.html) or `wb.wtd` ([ref](./skills/wtd.html))
- Architecture / tree / manifests → [Architecture](./architecture.html)
- State transitions → [Artifact lifecycle](./lifecycle.html)
- Skills (19) → [Skills reference](./skills.html)
- Ralph integration → [Ralph](./ralph.html)
- Steering (golden / role / overlays) → [Steering workflow](./steering/)
- Upgrades + notifications → [Versioning](./versioning.html)
- Stuck → [FAQ](./faq.html)

## Typical flow

```
Jira epic → /epic-intake → publish + approve
         → /prd-draft   → publish + approve
         → /eng-spec    → publish + approve   (dev hat)
         → /tdd         → publish + approve
         → /bdd-gen     → publish + approve   (QA hat)
         → /test-cases-gen → publish + approve
         → /test-spec   → publish + approve
         → /ralph-workspace-plan
         → /ralph-dispatch
```

## License

See repo license files.
