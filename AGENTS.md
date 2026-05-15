# AGENTS.md — Shared Workbench Constitution

All coding agents (Claude, Devin, Codex) read this file. Agent-specific overlays live in `CLAUDE.md`, `.devin/CONFIG.md`, `.codex/CONFIG.md` if present.

---

## What this workbench is

A private git repo cloned per work-bundle (one or more Jira epics), shared by a dev + QA pair. Its role is planning and artifact generation (PRD, spec, TDD, ERD, ADR, BDD, test cases, test spec) plus orchestration of ralph loops over code repos cloned into `repos/`.

## What this workbench is NOT

- A code editor. Production code lives in `repos/*/`.
- A CI system. No tests run from the workbench.
- A Jira replacement. Jira is the source of truth for epics and acceptance criteria.

## Session protocol (all agents)

1. `git pull --rebase` — shared repo.
2. Load Layer 0 steering: run `python3 scripts/steering-load.py golden` (or `wb.steering golden`). Treat the merged output as hard rules for the session. Re-run whenever `update.wb`, `git pull`, `git merge`, or any edit under `steering/` or `steering.local/` occurs.
3. Read `project.conf` and `EPIC-PIPELINE.md`.
4. Read `.workbench-state/published.json` (awaiting approval) and `.workbench-state/approved.json` (ralph-ingestable).
5. Report open items and suggest next action.

When an agent adopts a role (PO / dev / QA / UXD), it must first run `python3 scripts/steering-load.py role:<role>` and treat that output as hard rules for any work produced in that role. When a skill produces an artifact (prd, eng-spec, tdd, bdd, test-cases, test-spec, ...), the skill's own step 0 loads `artifact:<type>` steering. Skills may additionally declare `relevant_topics:` in their frontmatter; if so, the loader is invoked once per topic.

## Artifact lifecycle (three stages)

Every agent-authored artifact carries a `status:` field in YAML frontmatter and flows:

```
draft  ──(wb.publish)──▶  published  ──(wb.approve)──▶  approved
  ▲                                                        │
  └────────────(wb.reject, any stage)──────────────────────┘
```

- Agents write `draft` only.
- Humans transition via `wb.publish`, `wb.approve`, `wb.reject`.
- Ralph gate: only entries in `.workbench-state/approved.json` are synced into `repos/*/ai/` by `sync-context.sh`.
- Rejections are logged to `.workbench-state/rejected.json` with a reason.
- Downstream skills (e.g. `/eng-spec`) must verify upstream `approved` state before running.

Each draft-producing skill (`prd-draft`, `design-draft`, `eng-spec`, `tdd`, `erd`, `adr`, `bdd-gen`, `test-cases-gen`, `test-spec`) prompts for a grill pass between writing the artifact and printing its "next steps" tail. Product and design hosts use `/grill-me`. Engineering hosts default to `/domain-grill` per `target_repo` (falling back to `/grill-me` per repo when `${WB_ROOT}/context/<repo>/CONTEXT.md` is absent). Outcomes are recorded in a `grilled:` frontmatter block per `skills/grill-substrate.md`. Skipping is allowed and never blocks `wb.publish`; reviewers see a P2 finding when the receipt is missing or incomplete.

## Ralph rules

- Never generate a fix_plan entry without an approved PRD (for automation repos: plus approved test spec; for service repos: plus approved engineering spec).
- Ralph always runs from a code repo's cwd, never from the workbench root.
- Workspace-mode planning (writes per-repo `.ralph/fix_plan.md`) is invoked via `wb.ralph-plan`. Execution is via `wb.ralph-dispatch` (cross-repo parallelism via `ralph --workspace --parallel N`); for single-repo debugging drop the wrapper: `(cd "$WB_ROOT/repos/<name>" && ralph --live --monitor)`.

## Template discipline

- `update.wb` rewrites `template_owned` paths from the upstream template. Do not hand-edit those paths.
- If an agent wants to improve a template-owned path (including anything under `steering/`), it must propose a PR to the upstream `ai-workbench` repo, not edit the path in this instance.
- Team-specific steering goes in `steering.local/` (user-owned). See `steering/README.md` for the overlay format (add, supersede, remove).

## Safety

- No force-push.
- Never bypass hooks or code-owner review on the workbench repo.
- MCP credentials live in environment variables, never in `.mcp.json` as literals, never in logs.
- Never write to a code repo under `repos/*` without ralph.

## Versioning (agent-relevant only)

- Existing alias `update.wb` has been renamed to `wb.upgrade` (canonical). Old name still works via deprecation shim, use `wb.upgrade` in suggestions.
- `*.upgrade` family for global tools: `wb.upgrade` (this stamped wb), `devkit.upgrade` (global ai-devkit clone), `ralph.upgrade` (global ai-ralph clone). One-step doctor: `devkit doctor`.
- Never edit `version.json` manually unless explicitly asked. release-please auto-bumps from Conventional Commit messages on merge to main.
- When introducing peer-version requirements (e.g., a wb feature that requires ralph >= X), edit the `requires` field in `version.json` in the same PR, that field is human-maintained.

## Voice rules

- Plain English. Short sentences.
- No em dashes.
- No buzzwords (leverage, utilize, robust, streamline, delve, unlock).
- Use code blocks for code; do not wrap code in prose.
