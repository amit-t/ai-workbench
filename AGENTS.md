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
2. Read `project.conf` and `EPIC-PIPELINE.md`.
3. Read `.workbench-state/published.json` (awaiting approval) and `.workbench-state/approved.json` (ralph-ingestable).
4. Report open items and suggest next action.

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

## Ralph rules

- Never generate a fix_plan entry without an approved PRD (for automation repos: plus approved test spec; for service repos: plus approved engineering spec).
- Ralph always runs from a code repo's cwd, never from the workbench root.
- Workspace-mode planning (writes per-repo `.ralph/fix_plan.md`) is invoked via `wb.ralph-plan`; execution is per-repo via `wb.ralph-loop` or `wb.ralph-dispatch`.

## Template discipline

- `update.wb` rewrites `template_owned` paths from the upstream template. Do not hand-edit those paths.
- If an agent wants to improve a template-owned path, it must propose a PR to the upstream `ai-workbench` repo, not edit the path in this instance.

## Safety

- No force-push.
- Never bypass hooks or code-owner review on the workbench repo.
- MCP credentials live in environment variables, never in `.mcp.json` as literals, never in logs.
- Never write to a code repo under `repos/*` without ralph.

## Voice rules

- Plain English. Short sentences.
- No em dashes.
- No buzzwords (leverage, utilize, robust, streamline, delve, unlock).
- Use code blocks for code; do not wrap code in prose.
