# ai-workbench (template)

Template for a per-bundle workbench: one private repo where a dev + QA pair drive Jira epics from PRD to shipped code via ralph. You never clone this directly. `init.wb` (from [ai-devkit](https://github.com/amit-t/ai-devkit)) stamps a private instance under your GitHub org via `gh repo create --template`.

**Deep docs:** [amit-t.github.io/ai-workbench](https://amit-t.github.io/ai-workbench/) · **V1 (pre-precision long-form) archive:** [/v1/](https://amit-t.github.io/ai-workbench/v1/)

## What a stamped workbench holds

- PRDs (PO hat)
- Design context + Figma-driven screens (UX hat)
- Eng spec, TDD, ERD, ADRs (architect / staff-eng hats)
- BDD `.feature` files, test cases, test spec, test ERD (QA hat)
- ralph workspace-mode state across multiple code repos
- Service + automation repo clones under `repos/` (gitignored)

## Quickstart

After installing ai-devkit:

```bash
# Initiator
mkdir ~/workbenches/wb-example && cd ~/workbenches/wb-example
init.wb                  # Devin-driven; use init.wb.cly to force Claude

# Joiner
cd ~/workbenches
join.wb https://github.com/<your-org>/wb-example

# Pull template updates later
wb.upgrade
```

Full walkthrough: [docs/getting-started](https://amit-t.github.io/ai-workbench/getting-started.html).

## Working across multiple workbenches

Source `aliases.sh` once per shell. Every `wb.*` command resolves the active wb per call, in this priority:

1. `WB_PIN` env (set by `wb.switch <path>`, cleared by `wb.unswitch`).
2. Walk up from `$PWD` to a dir containing `project.conf`.
3. The wb whose `aliases.sh` was sourced (single-wb fallback).

```bash
wb.where                            # show resolved wb + source
wb.switch ~/workbenches/wb-billing  # pin (survives cd)
wb.ralph-dispatch --parallel 4      # acts on wb-billing regardless of cwd
wb.unswitch                         # release pin
```

No re-sourcing needed when switching wbs.

## Skills catalogue (21)

Outputs land at `status: draft`. Promotion is human-driven via `wb.publish` / `wb.approve`. Lost in the pipeline? Run `wb.wtd` for the next concrete command, or read [Workflows](https://amit-t.github.io/ai-workbench/workflows.html) (if-this-then-that page).

| Skill | Hat | Purpose |
|-------|-----|---------|
| `/epic-intake` | PO | Pull Jira epic as draft context. |
| `/prd-draft` | PO | PRD from approved epic. |
| `/prd-review-panel` | PO | 7-perspective PRD review; blocks approve on P0. |
| `/design-draft` | UXD | End-to-end UX: brief → wireframes → hi-fi → handoff. |
| `/figma-pull` | UXD | Park Figma links; optional Figma-MCP export. |
| `/ds-screen-gen` | UXD | Hi-fi HTML/JSX screens from design-system ref. |
| `/design-review` | UXD | 5-perspective screen review; blocks handoff on P0. |
| `/eng-spec` | Eng | Architecture, contracts, data, rollout, observability. |
| `/tdd` | Eng | File map, interfaces, sequence diagrams, failure matrix. |
| `/erd` | Eng | Mermaid ER + C4-L2 + hot-path sequence. |
| `/adr` | Eng | MADR-lite ADR. |
| `/bdd-gen` | QA | Gherkin `.feature` (happy / edge / error / security). |
| `/test-cases-gen` | QA | BDDs → test-case table with priority + automation flags. |
| `/test-spec` | QA | QA engg spec + test ERD. |
| `/ralph-workspace-plan` | Orch | Sync approved context; produce per-repo fix_plans. |
| `/ralph-dispatch` | Orch | Parallel ralph loops across repos. |
| `/grill-me` | Cross | Relentless interview to stress-test a draft. |
| `/grill-me-auto` | Cross | Batch-mode `/grill-me`: all questions in one collapsible doc, answered in one reply. |
| `/pmo-status` | Cross | Workbench status rollup. |
| `/wtd` | Cross | What-To-Do: one next-action command per epic. Trimmer cousin of `/pmo-status`. |
| `/precise-readme` | Cross | Precision-mode pass on README + docs/; archives originals under `docs/v1/` with cross-banners. |

Per-skill deep dive: [docs/skills](https://amit-t.github.io/ai-workbench/skills.html). Source under `skills/<name>/SKILL.md`. Skills attach via symlinks: at `init.wb` time, `.claude/skills`, `.agents/skills`, `.devin/skills` all point at one `skills/`, so every agent sees the same set.

## Artifact lifecycle (one-line summary)

```
draft ──wb.publish──▶ published ──wb.approve──▶ approved ──▶ ralph consumes
  ▲                       │                         │
  └──────wb.reject────────┴─────────────────────────┘
```

Agents only write `status: draft`. Promotion is human-driven. Ralph's only gate is `.workbench-state/approved.json`.

Full state machine, downstream preconditions, BDD caveats: [docs/lifecycle](https://amit-t.github.io/ai-workbench/lifecycle.html).

## Multi-repo execution with ralph

The workbench wraps [ai-ralph](https://github.com/Invenco-Cloud-Systems-ICS/ai-ralph). Ralph owns the planner, workspace loop, parallelism, PR creation. Workbench only wraps, routes approved artifacts via `target_repos:`, and ships team steering.

```bash
wb.ralph-plan                    # sync context + ralph-plan --workspace
wb.ralph-plan --replan svc-a     # regen one repo's section
wb.ralph-plan --parallel-plan 4  # workspace-mode parallel planning
wb.ralph-dispatch                # ralph --workspace --parallel N
wb.ralph-dispatch --repos a,b    # subset run
wb.ralph-dispatch --status       # open PRs + worker log tails
```

Daily flow, config table, `target_repos:` validation, replan/subset semantics, drift-footer (M4): [docs/ralph](https://amit-t.github.io/ai-workbench/ralph.html).

### Stamped-wb bootstrap

`init.wb` / `join.wb` (ai-devkit) bootstrap ralph once per stamped wb: install the `ralph` binary if missing, verify `--workspace` support, `mkdir -p repos`, purge the `template_dev_only` artifacts listed in `.workbench-manifest.json` (`.ralph/PROMPT.md`, `.ralph/fix_plan.md`, `SESSION-HANDOFF.md`, `CHANGELOG.md`), then run `ralph enable --workspace --non-interactive --skip-tasks` at `repos/`. `wb.upgrade` carries a migration step that runs the same enable for old stamped wbs missing `repos/.ralph/` (idempotent).

## Graphify integration

The workbench wraps the [graphifyy](https://pypi.org/project/graphifyy/) CLI to give Devin + Claude a graph-indexed view of every registered repo. Per-repo state lives in the `graphified=<true|false>` field of each `REPOS=(...)` entry in `project.conf`. `wb.register-repo` appends `graphified=false` on add; `wb.graphify` flips to `true` on success.

```bash
wb.graphify <repo>            # build graph for one repo (graphify-out/graph.json)
wb.graphify --all             # every non-graphified repo
wb.graphify --check           # report-only: mode + per-repo status
wb.graphify --install-skill   # one-time: drop SKILL.md into .agents/.claude
```

Mode resolution: CLI (`--auto` / `--manual`) > `WB_GRAPHIFY_MODE` env > `project.conf GRAPHIFY_MODE` > default `auto`. In `auto`, `wb.register-repo` and `init.wb` / `join.wb` invoke `wb.graphify` after clone. In `manual`, they print a recommendation. Auto pip-installs `graphifyy` if absent (skip via `--no-install`).

`wb.info` surfaces non-graphified repos and recommends `wb.graphify --all`. `wb.graphify --install-skill` runs `graphify install --platform claude` (global) and copies the resulting `SKILL.md` into `$WB_ROOT/.agents/skills/graphify/` plus a `.claude/skills/graphify` symlink so both engines see the `/graphify` command locally.

## Steering

Layer 0 (golden) loads at session start. Layer 1 (role: dev/qa/po/uxd) loads on role-inference match. Layer 2 (artifact/topic) loads as step 0 of each skill. Template ships canonical rules under `steering/`; teams add overlays under `steering.local/`.

```
wb.steering <scope>          # load merged rules (golden | role:x | artifact:x | topic:x)
wb.steering-refresh          # reload every scope
wb.steering-lint             # validate steering/ + steering.local/
wb.steering-audit            # report overlays + promote-suggest
```

CI lint on stamped wbs: `.github/workflows/wb-ci.yml` runs `steering-lint.py` + `wb-ci-validate.py` on any PR touching `product/`, `design/`, `engineering/`, `qa/`, `steering/`, or `steering.local/`. Artifact step is a no-op inside the template repo (no `project.conf`).

Council ownership, promotion flow, drift digest, freshness hooks: [docs/steering](https://amit-t.github.io/ai-workbench/steering/).

## Hard rules

- No fix_plan entry for a repo without an approved PRD (and, for service repos, an approved eng-spec).
- No writes into `repos/*` from a workbench Claude/Devin session. That is ralph's job.
- No re-implementing ralph internals inside workbench scripts. `repos/.ralph/` is ralph-owned.
- Every PRD, eng-spec, TDD, ERD, BDD, test-cases, test-spec, test-erd must declare `target_repos:` before publish. Validator blocks transitions without it.
- Never touch `skills/`, `scripts/`, `steering/`, `CLAUDE.md`, `AGENTS.md`, `aliases.sh`, `.workbench-manifest.json` inside a stamped wb. Template-owned; `wb.upgrade` rewrites them. Team-specific rules live in `steering.local/`.
- No em dashes in docs (use commas or parens). No hype words ("leverage", "utilize", "robust", "streamline", "unlock").

## Plan-mode

Always plan before writing code in `repos/*` or creating a fix_plan entry. Full session-start protocol and role inference: `CLAUDE.md`.

## Versioning + upgrades

Template ships under semver. Stamped wbs inherit the version they were stamped from in `.workbench-state/template-version.json`. `wb.upgrade` pulls template-owned files from upstream and refreshes the stamp. Notification banners fire on the first meaningful `wb.*` call per 12h window when upstream is newer; fail-open if offline.

Cross-tool details, `devkit doctor`, `*.upgrade --rollback`: [ai-devkit/docs/versioning](https://github.com/amit-t/ai-devkit/blob/main/docs/versioning.md). Workbench-side: [docs/versioning](https://amit-t.github.io/ai-workbench/versioning.html).

## WSL2

Supported. Prereqs and gotchas: [docs/onboarding-wsl](docs/onboarding-wsl.md). CI runs the same flow on `ubuntu-latest` (`.github/workflows/smoke-wb.yml`); local mirror is `tests/integration/smoke-wb-onboarding.sh`.

## Directory map

Full tree + `template_owned` / `user_owned` split: `DESIGN.md` and [docs/architecture](https://amit-t.github.io/ai-workbench/architecture.html).
