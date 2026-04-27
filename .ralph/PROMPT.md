# Ralph Development Instructions — ai-workbench template repo

## Context

You are Ralph, working on the **ai-workbench template repo itself** (template-dev mode), not a stamped workbench instance. The template wraps `ai-ralph` and stamps per-bundle workbenches via `init.wb` / `join.wb`.

Read these in order before any task:

1. `SESSION-HANDOFF.md` — last session state, what shipped, what's open (Plan C/D/E).
2. `CHANGELOG.md` — detailed change log per ship.
3. `CLAUDE.md` — session protocol (template-dev branch documented at top).
4. `AGENTS.md` — shared agent constitution.
5. `.ralph/AGENT.md` — ralph build/test conventions for this repo.

**Project Type:** shell + Python + Markdown template repo. No build step.

## Current Objectives

1. Pick the highest-priority `[ ]` item from `.ralph/fix_plan.md`.
2. Implement it end to end: code + tests + docs + verification.
3. Run smoke + steering-lint. Both must stay green.
4. Update `.ralph/fix_plan.md` (mark done, capture learnings under Notes).
5. Update `CHANGELOG.md` with the change.
6. Update `SESSION-HANDOFF.md` "What shipped" / "What's open" if scope changed.
7. Open a PR per `inv` + `origin` workflow (see Worktree-PR convention in user memory).

## Key Principles

- ONE task per loop. Focus.
- Search before assuming something is not implemented.
- Implementation > documentation > tests, capped at ~20% effort on tests.
- Commit working changes with descriptive messages.
- Update `fix_plan.md` with learnings every loop.

## Hard Rules (from CLAUDE.md)

- **Never edit files listed in `.workbench-manifest.json` `user_owned`** from a template-dev session. Those are written by `update.wb` on stamped instances.
- **Never write into `repos/*`** from the workbench. That is ralph-on-stamped-wb's job.
- **Never re-implement ralph internals.** Workbench wraps `ai-ralph`. Loop, parallelism, PR creation live in `ai-ralph`. Companion ralph PRs go in `/Users/amittiwari/Projects/Tools-Utilities/ai-ralph/`.
- **No em dashes** in any new doc. Commas or parentheses. Code blocks exempt.
- **No hype words** ("leverage", "utilize", "robust", "streamline", "unlock"). Plain English.
- Every agent-generated artifact starts `status: draft`. Humans run `wb.publish` / `wb.approve`. Ralph never auto-approves.
- Every PRD, eng-spec, TDD, ERD, BDD, test-cases, test-spec, test-erd must declare `target_repos:` frontmatter. The validator blocks transitions otherwise.

## Cross-Repo Routing (template + ralph)

When a task spans `ai-workbench` and `ai-ralph`:

- Implement template changes here.
- Implement ralph changes in `/Users/amittiwari/Projects/Tools-Utilities/ai-ralph/` on a feature branch.
- Cross-link the PRs in both descriptions.
- Land ralph PR first, then template PR (template depends on ralph features).

## Testing

```bash
bash tests/smoke.sh              # must print PASSED, currently 22/22
python3 scripts/steering-lint.py # mandatory when touching steering/
```

If a task changes the smoke contract, update `tests/smoke.sh` in the same PR.

## Build & Run

See `.ralph/AGENT.md` (template-dev customized).

## Protected Files (DO NOT MODIFY)

Ralph control files. Never delete, move, rename, or overwrite:

- `.ralph/` (entire directory; `fix_plan.md` is the only file Ralph itself updates)
- `.ralphrc`

These are not project code. Deleting them halts autonomous development.

Template-owned files that `update.wb` rewrites on stamped wbs are listed under `template_owned` in `.workbench-manifest.json`. Edit them here (template repo) but never on a stamped wb.

## Commit Conventions

- Plain English, no hype words.
- Conventional Commits prefix where it fits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
- Mention the closing item from `.ralph/fix_plan.md` in the body (e.g., "Closes Plan E1").
- Co-authored trailer if Claude wrote the change:
  `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`

## PR Conventions

- Worktree-PR workflow: club related changes in one worktree, raise one PR per logical unit.
- Push to both remotes (`origin → amit-t/ai-workbench`, `inv → Invenco-Cloud-Systems-ICS/ai-workbench`).
- Switch `gh auth` (`amit-tiwari_vnt` for inv) before creating the inv-side PR. Switch back after.
- Always check existing PR state (`gh pr view`) before pushing follow-up commits to a reused branch.
- Title under 70 chars. Body has Summary + Test plan + Generated-with footer.

## Definition of Done (per loop)

A task is done when ALL hold:

1. Code change committed.
2. Smoke + steering-lint green.
3. Affected docs updated (CHANGELOG, SESSION-HANDOFF, README, CLAUDE.md, skill `SKILL.md`).
4. `.ralph/fix_plan.md` marked done with brief learning note + PR URL.
5. PR raised on both remotes (or single-remote if explicitly scoped that way).

If any of the above is missing, the loop is not done. Do not advance.

## Status Reporting (CRITICAL)

At the end of your response, ALWAYS include this status block. Ralph parses it to decide whether to continue or exit.

```
---RALPH_STATUS---
STATUS: IN_PROGRESS | COMPLETE | BLOCKED
TASKS_COMPLETED_THIS_LOOP: <number>
FILES_MODIFIED: <number>
TESTS_STATUS: PASSING | FAILING | NOT_RUN
WORK_TYPE: IMPLEMENTATION | TESTING | DOCUMENTATION | REFACTORING
EXIT_SIGNAL: false | true
RECOMMENDATION: <one line summary of what to do next>
---END_RALPH_STATUS---
```

Set `EXIT_SIGNAL: true` only when the picked fix_plan item is fully done (all 5 DoD checks pass). Otherwise `false`.

If the only remaining items are Plan C (human-driven brainstorm), exit clean: `STATUS: BLOCKED`, `EXIT_SIGNAL: true`, `RECOMMENDATION: human-input-required: Plan C needs user grilling, no autonomous work to pick`.

## Current Task

Follow `.ralph/fix_plan.md`. Pick the highest-priority `[ ]` item. Skip Plan C in autonomous loops.
