# CLAUDE.md — Workbench Instructions

This file is read by Claude Code every session. Read `AGENTS.md` first (shared constitution), then this file.

---

## What this is

You are in a **workbench** — a private per-bundle git repo cloned from `ai-workbench` for a dev + QA pair working on one or more Jira epics. Your job is to help the user move from Jira epic to PRD to engineering artifacts to approved fix_plan entries in the code repos under `repos/`.

You never write production code from the workbench. Code lives in `repos/*/`, and ralph runs there with the fix_plans you helped prepare.

---

## Session Start Protocol

Every session, in this order:

0. **Template-dev detection.** If `project.conf` does NOT exist and `SESSION-HANDOFF.md` does exist at repo root, you are in the **ai-workbench template repo itself** (not a stamped workbench instance). Read `SESSION-HANDOFF.md` first and follow steps 1–8 only if they still apply to template-dev work. Otherwise continue:
1. `git pull --rebase` — workbench is shared with a collaborator; pull first.
2. **Load Layer 0 steering.** Run `wb.steering golden` (or `python3 scripts/steering-load.py golden`). Treat the merged output as hard rules for this session. Re-run whenever `update.wb`, `git pull`, `git merge`, or any edit under `steering/` or `steering.local/` occurs.
3. Read `project.conf` — workspace label, epics in scope, registered repos and their roles.
4. Read `EPIC-PIPELINE.md` — current status per epic and PRD.
5. Read `.workbench-state/published.json` — artifacts awaiting approval.
6. Read `.workbench-state/approved.json` — what ralph can consume right now.
7. Scan `product/outputs/prds/` for drafts and approved PRDs.
8. Suggest the most useful next action based on what is unfinished.

---

## Role inference (you adapt; don't ask the user to switch modes)

Before entering a role mode for the first time in a session, run `wb.steering role:<role>` to load that role's Layer 1 steering. Treat the merged output as hard rules for any work produced in that role.

| Signal | Mode | Steering to load |
|--------|------|------------------|
| Discussing a Jira epic, requirements, acceptance criteria | PO mode — produce PRDs | `wb.steering role:po` |
| Discussing layouts, components, Figma | UXD mode — pull refs, draft screens | `wb.steering role:uxd` |
| Discussing architecture, ports, services, data models | Engineering mode — eng spec / TDD / ERD / ADR | `wb.steering role:dev` |
| Discussing test coverage, BDD, scenarios, test data | QA mode — BDD / test cases / test spec | `wb.steering role:qa` |
| Discussing ralph, fix_plan, parallel loops | Orchestrator mode — workspace-plan / dispatch | (no role-specific steering; rely on Layer 0) |

## Plan-mode rule

Always present a plan before writing any code (in `repos/*`) or creating any fix_plan entry. Get explicit approval from the user. Only then execute. Artifacts under `product/`, `design/`, `engineering/`, `qa/` may be drafted without a plan. They start at `status: draft` and only move to `published` or `approved` via the human-driven `wb.publish` / `wb.approve` aliases.

## Artifact lifecycle (three stages)

Every artifact you write starts at `status: draft`. State transitions happen only via the three aliases:

| Alias | Transition | Effect |
|-------|-----------|--------|
| `wb.publish <id> <path> <type>` | `draft → published` | Sets `status: published`; appends entry to `.workbench-state/published.json`. |
| `wb.approve <id>` | `published → approved` | Sets `status: approved`; moves entry from `published.json` to `approved.json`. |
| `wb.reject <id> "<reason>"` | any stage → `draft` | Records rejection reason in `rejected.json`; clears `published.json` and `approved.json` entries. |

**Rules for agents:**

- **Write `draft` only.** Never set `status: published` or `status: approved` yourself. Those transitions are human-driven.
- **Never bypass the lifecycle.** Do not write an artifact directly with `status: approved`.
- **Ralph gate is `.workbench-state/approved.json`.** `sync-context.sh` filters only what is listed there.

**Downstream skill preconditions** (upstream must be `approved`):

| Skill | Requires at `approved` |
|-------|------------------------|
| `/prd-draft` | epic-context file (typed `epic-context`, produced by `/epic-intake`) |
| `/eng-spec` | PRD |
| `/tdd` | engineering spec |
| `/erd` | engineering spec |
| `/adr` | engineering spec if one exists; otherwise no upstream gate (ADRs can stand alone) |
| `/bdd-gen` | PRD |
| `/test-cases-gen` | BDDs (all relevant `.feature` files) |
| `/test-spec` | PRD + BDDs + test cases |
| `/ralph-workspace-plan` | PRD + engineering spec + TDD + test spec |

## Context library routing

| User asks about | Where to look |
|-----------------|--------------|
| Current epics, PRDs | `EPIC-PIPELINE.md` |
| Epic body (Jira) | `product/context-library/epics/<EPIC-ID>.md` |
| PRDs | `product/outputs/prds/` |
| Design system ref | `design/context-library/design-system-ref.md` |
| Figma links | `design/context-library/figma-links.md` |
| Engineering specs | `engineering/outputs/specs/` |
| TDDs | `engineering/outputs/tdd/` |
| ERDs | `engineering/outputs/erd/` |
| ADRs | `engineering/outputs/adrs/` |
| BDD features | `qa/outputs/bdd/` |
| Test cases | `qa/outputs/test-cases/` |
| Test spec (QA engg spec) | `qa/outputs/test-spec/` |
| Test ERD | `qa/outputs/test-erd/` |
| Registered code repos | `project.conf` REPOS array |
| Published (awaiting approval) | `.workbench-state/published.json` |
| Approved (ralph-ingestable)   | `.workbench-state/approved.json` |
| Rejections                    | `.workbench-state/rejected.json` |

## Key commands (sourced via `aliases.sh`)

```
wb.sync-context                       # push workbench outputs into repos/*/ai/
wb.ralph-enable-check                 # preflight that `ralph enable --workspace` ran
wb.ralph-plan [--mode ...] [--engine] # sync context + ralph-plan (workspace by default)
wb.ralph-plan --replan <repo>         # regen one repo's section, splice into repos/.ralph/fix_plan.md
wb.ralph-dispatch [--parallel N]      # ralph --workspace --parallel N (ralph owns the loop)
wb.ralph-dispatch --status            # open ralph PRs + tail of worker logs
wb.ralph-annotate [--since 30m]       # M4 drift footer on open ralph PRs (post-hoc fallback)
wb.register-repo <name> <url> <role>  # add code repo
wb.publish <id> <path> <type>         # draft → published  (validates target_repos)
wb.approve <id>                       # published → approved (validates target_repos)
wb.reject <id> "<reason>"             # any → draft (with reason)
wb.published                          # list awaiting approval
wb.approved                           # list ralph-ingestable
wb.steering <scope>                   # load steering (golden | role:x | artifact:x | topic:x)
wb.steering-refresh                   # reload every scope (use after steering updates mid-session)
wb.steering-lint                      # validate steering/ and steering.local/
```

## Ralph adapter (quick reference)

- Workbench wraps ai-ralph. Workbench never re-implements ralph internals — enable, loop, parallelism, and PR creation all live in ralph.
- `ralph enable --workspace` is run once at `$WB_ROOT/repos/` by `init.wb` / `join.wb`. `wb.ralph-enable-check` is the preflight.
- `wb.ralph-plan` defaults to **workspace mode** (single `ralph-plan --workspace` at `$WB_ROOT/repos/`). Falls back to per-repo looping when the installed ralph-plan does not support `--workspace`. Override with `--mode`, env `WB_RALPH_PLAN_MODE`, or `project.conf RALPH_PLAN_MODE`.
- `wb.ralph-plan --replan <repo>` regenerates only one repo's plan, then splices the resulting `## <repo>` section back into `repos/.ralph/fix_plan.md` (existing section is replaced; appended if missing). Holds an advisory `flock` on `.workbench-state/.lock` during the splice. Use this when a stakeholder change affects one repo and you do not want to redo planning for the rest.
- `wb.ralph-dispatch` = `(cd $WB_ROOT/repos && ralph --workspace --parallel N)`. Default `N = min(len(REPOS), 4)`. Override with `--parallel`, env `WB_RALPH_PARALLEL`, or `project.conf WB_RALPH_PARALLEL`.
- Single-repo debugging is a one-liner: `(cd "$WB_ROOT/repos/<name>" && ralph --live --monitor)`. Do not add a wb wrapper for this.
- **Artifact routing** flows through `target_repos:` frontmatter / Gherkin-header. Required on every PRD, eng-spec, TDD, ERD, BDD, test-cases, test-spec, test-erd. Validated at `wb.publish` and `wb.approve` via `scripts/validate-artifact.py`.
- **M4 drift footer** (ralph PRs carry a list of `steering.local/` overrides): once the ralph-side `.ralph/pr_footer.md` support lands, `sync-context.sh` writes the footer into `$WB_ROOT/repos/.ralph/pr_footer.md` and ralph picks it up automatically. Until then, `wb.ralph-annotate` edits open PR bodies as a post-hoc fallback.

## Hard rules

- Never generate a fix_plan entry for a repo without an approved PRD and (for service repos) an approved engineering spec.
- Never write into `repos/*` from a workbench Claude session. That is ralph's job.
- Never re-implement ralph internals inside workbench scripts. `repos/.ralph/` is ralph-owned; workbench only reads it (for pr_footer staging, status output) and delegates execution.
- Every PRD, eng-spec, TDD, ERD, BDD, test-cases, test-spec, and test-erd must declare `target_repos:` naming registered repos before publish. The validator blocks transitions without it.
- Never touch files under `skills/`, `scripts/`, `steering/`, `CLAUDE.md`, `AGENTS.md`, `aliases.sh`, or `.workbench-manifest.json`. Those are template-owned and rewritten by `update.wb`. Team-specific steering goes in `steering.local/` (user-owned).
- No em dashes in documents. Use commas or parentheses. Exception: code blocks preserve exact content.
- No hype words. No "leverage", "utilize", "robust", "streamline", "unlock". Plain English.

## Steering (quick reference)

- Layer 0 (golden) is loaded at session start (step 2 above).
- Layer 1 (role) is loaded on role-inference match (see role table above).
- Layer 2 (artifact / topic) is loaded as step 0 of each skill that produces that artifact, or on demand for topics.
- Do not try to merge template and overlay in your head. Always run the loader.
- See `steering/README.md` for the full system; see `steering/config.yaml` for invocation points and scope mapping.
