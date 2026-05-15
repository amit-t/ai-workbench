# ai-workbench (template)

Template repo for a workbench. You do not clone this directly. Run `init.wb` (from `ai-devkit`) which uses `gh repo create --template` to stamp a private instance under your GitHub org.

## What a workbench is

A private git repo that holds:

- PRDs for one or more Jira epics (PO hat)
- Design context + screens pulled from Figma (UX hat)
- Engineering spec, TDD, ERD, ADRs (architect + staff-eng hats)
- BDD `.feature` files, test cases, test spec, test ERD (QA hat)
- ralph workspace-mode state spanning multiple code repos
- Cloned service + automation repos inside `repos/` (gitignored)

Two collaborators (typically one dev + one QA) share the workbench and jointly drive work from epic to shipped code + passing automation.

## Quickstart (after install of ai-devkit)

Initiator:

```bash
mkdir ~/workbenches/wb-example && cd ~/workbenches/wb-example
init.wb                  # Devin-driven; use init.wb.cly to force Claude
```

Joiner:

```bash
cd ~/workbenches
join.wb https://github.com/<your-org>/wb-example
```

Pull template updates later:

```bash
cd ~/workbenches/wb-example
update.wb
```

## Working across multiple workbenches

Source `aliases.sh` once per shell from any wb (or your `~/.zshrc`). Every `wb.*` command then resolves the active workbench per call, in this priority:

1. `WB_PIN` env var (set via `wb.switch <path>`, cleared via `wb.unswitch`).
2. Walking up from `$PWD` until a directory containing `project.conf` is found.
3. The wb whose `aliases.sh` was sourced (zero-config fallback for single-wb users).

```bash
# Inspect which wb the next command will target.
wb.where
# /Users/me/workbenches/wb-gitlore  (via cwd)

# Pin a wb explicitly (survives cd's; cleared by wb.unswitch).
wb.switch ~/workbenches/wb-billing
wb.ralph-dispatch --parallel 4   # acts on wb-billing regardless of cwd
wb.unswitch
```

No need to re-source `aliases.sh` when switching workbenches.

## Directory map

See `DESIGN.md` in the harness root for the full tree and the `template_owned` / `user_owned` split.

## How skills attach

`skills/` holds the bundled skills. At `init.wb` time, `.claude/skills`, `.agents/skills`, `.devin/skills` are symlinked to this one dir. Every agent sees the same skills.

## Skills catalogue

18 skills ship with every workbench, grouped by hat. All outputs land at `status: draft`; promotion is human-driven via `wb.publish` / `wb.approve`.

| Skill | Hat | Short purpose |
|-------|-----|---------------|
| `/epic-intake` | PO | Pull Jira epic into workbench as draft context. |
| `/prd-draft` | PO | PRD from approved epic — goals, scope, NFRs, acceptance. |
| `/prd-review-panel` | PO | 7-perspective PRD review; blocks approve on P0. |
| `/design-draft` | UXD | End-to-end UX — brief → wireframes → hi-fi → handoff. |
| `/figma-pull` | UXD | Park Figma links; optional Figma-MCP export. |
| `/ds-screen-gen` | UXD | Hi-fi HTML/JSX screens using design-system ref. |
| `/design-review` | UXD | 5-perspective screen review; blocks handoff on P0. |
| `/eng-spec` | Eng | Architecture, contracts, data, rollout, observability. |
| `/tdd` | Eng | File map, interfaces, sequence diagrams, failure matrix. |
| `/erd` | Eng | Mermaid ER + C4-L2 component + hot-path sequence. |
| `/adr` | Eng | MADR-lite ADR — context, drivers, options, decision. |
| `/bdd-gen` | QA | Gherkin `.feature` — happy/edge/error/security paths. |
| `/test-cases-gen` | QA | BDDs → test-case table with priority + automation flags. |
| `/test-spec` | QA | QA engg spec + test ERD — coverage, env, flaky strategy. |
| `/ralph-workspace-plan` | Orchestrator | Sync approved context; produce per-repo fix_plans. |
| `/ralph-dispatch` | Orchestrator | Parallel ralph loops across workbench repos. |
| `/grill-me` | Cross-cutting | Relentless interview to stress-test any draft. |
| `/pmo-status` | Cross-cutting | Workbench status rollup from `.workbench-state/`. |

Deep dives — inputs, outputs, lifecycle gates, frontmatter, examples — live at **[docs/skills](https://amit-t.github.io/ai-workbench/skills.html)** with one page per skill. Skill source lives under `skills/<name>/SKILL.md`.

## Artifact lifecycle

Every artifact (PRD, eng spec, TDD, BDD, test spec, etc.) moves through three stages:

```
draft  ──wb.publish──▶  published  ──wb.approve──▶  approved  ──▶ ralph consumes
  ▲                         │                           │
  └──────wb.reject──────────┴───────────────────────────┘
```

### State lives in two places

Each transition flips both:

1. YAML frontmatter in the artifact file (`status: draft|published|approved`).
2. JSON ledger in `.workbench-state/{published,approved,rejected}.json`.

The frontmatter is per-document and human-readable. The JSON ledger is the machine index used by `sync-context.sh` and the `wb.published` / `wb.approved` / `wb.rejected` listers.

### Why three stages, not two

- `draft`: agent-written, not yet read by a human. Safe to rewrite.
- `published`: a human has read it and thinks it is worth reviewing. Queue for approval.
- `approved`: a human has signed off. Only artifacts in this state cross into `repos/*/ai/` via `wb.sync-context`. Ralph never sees drafts or published items.

The single gate for ralph is `.workbench-state/approved.json`. `sync-context.sh` filters strictly on that file.

### Upstream / downstream gates

A downstream skill refuses to run until its upstream is `approved`:

| Skill | Blocked until |
|---|---|
| `/prd-draft` | epic-context approved |
| `/eng-spec`, `/bdd-gen` | PRD approved |
| `/tdd`, `/erd` | eng-spec approved |
| `/test-cases-gen` | BDDs approved |
| `/test-spec` | PRD, BDDs, test-cases approved |
| `/ralph-workspace-plan` | PRD, eng-spec, TDD, test-spec approved |

This prevents chains of hallucination (draft PRD feeding a draft eng spec feeding draft tests feeding a bad fix_plan).

### Where dev and QA use it

Dev flow, single epic:

```bash
/epic-intake EPIC-123
wb.publish EPIC-123 product/context-library/epics/EPIC-123.md epic-context
wb.approve EPIC-123

/prd-draft EPIC-123
wb.publish PRD-EPIC-123 product/outputs/prds/EPIC-123.md prd
# if review finds gaps: wb.reject PRD-EPIC-123 "missing NFRs"  (back to draft)
wb.approve PRD-EPIC-123

/eng-spec PRD-EPIC-123
wb.publish ESPEC-EPIC-123 engineering/outputs/specs/EPIC-123.md eng-spec
wb.approve ESPEC-EPIC-123

/tdd ESPEC-EPIC-123
wb.publish TDD-EPIC-123 engineering/outputs/tdd/EPIC-123.md tdd
wb.approve TDD-EPIC-123
```

QA flow, parallel once PRD is approved:

```bash
/bdd-gen PRD-EPIC-123
wb.publish BDD-EPIC-123 qa/outputs/bdd/EPIC-123.feature bdd
wb.approve BDD-EPIC-123

/test-cases-gen BDD-EPIC-123
wb.publish TC-EPIC-123 qa/outputs/test-cases/EPIC-123.md test-cases
wb.approve TC-EPIC-123

/test-spec PRD-EPIC-123
wb.publish TSPEC-EPIC-123 qa/outputs/test-spec/EPIC-123.md test-spec
wb.approve TSPEC-EPIC-123
```

Handoff to ralph once everything is approved:

```bash
/ralph-workspace-plan
wb.sync-context          # copies only approved docs into repos/*/ai/
wb.ralph-dispatch        # ralph loops on fix_plans
```

### Inspection

```bash
wb.published    # what is awaiting human review
wb.approved     # what ralph is allowed to see
wb.rejected     # what bounced back, with reasons
```

### Rejection semantics

`wb.reject <id> "<reason>"` works from any stage (published or approved). It flips the file back to `status: draft`, clears the published and approved ledger entries, and logs the reason in `rejected.json`. This lets you yank an already-approved artifact if QA finds a gap post-approval.

### Agent rule (hard)

Agents write `status: draft` only. They never set `published` or `approved`. Those transitions are human-driven via the aliases, because approval is an accountability event and must bind to a human.

## Steering workflow

Golden principles, role-specific rules, and artifact-specific rules that the AI agents inside a workbench must follow. Authored by senior engineers and architects; consumed by every session, every role, every skill. The full system lives under `steering/` in each stamped workbench. Details: [docs/steering](https://amit-t.github.io/ai-workbench/steering/).

The system uses progressive disclosure: only a small "Layer 0" is always loaded, and role / artifact / topic steering is loaded on demand. This keeps context windows lean while letting the agent apply precise, opinionated rules when they are relevant.

```
Layer 0, Golden principles           always loaded (session start)
Layer 1, Role (dev/qa/po/uxd)        loaded on role-inference match
Layer 2, Artifact / Topic            loaded as step 0 of each skill
```

The template ships canonical steering under `steering/` (template-owned; PR back to `ai-workbench` to change). Teams layer local overrides in `steering.local/` (user-owned). The loader merges both; agents never merge in their heads.

### Responsibilities by role

**Architecture Council, Principal / Staff SWE, Director of Engineering**

- Own golden principles, role rules for dev and PO, and artifact rules for eng-spec, TDD, ERD, ADR. PRD artifact rules are jointly owned with the Director of Engineering.
- Author new rules via PRs to the `ai-workbench` template repo. `scripts/steering-lint.py` enforces frontmatter schema and ID regex; the CI workflow runs on every PR.
- Review and merge promotion PRs that port a team's `steering.local/` overlay into the template.
- Review the weekly drift digest issue in the template repo (`M2` GitHub Action). When a pattern recurs across teams, promote it upstream; when a team is silently drifting from org policy, start the conversation.
- When a rule is deprecated, keep the original file so historical references resolve; add a `supersedes: [OLD-ID]` replacement rather than deleting outright.

**QA Council**

- Own role rules for QA, and artifact rules for BDD, test-cases, test-spec. Own the `test-data` topic.
- Same PR-back-to-template flow. CODEOWNERS on `steering/roles/qa/` and `steering/artifacts/{bdd,test-cases,test-spec}/` scope QA Council review to their domain.
- Coordinate with Architecture Council on cross-cutting rules (for example, negative-path coverage, which touches both eng-spec and BDD).

**UX Council**

- Own role rules for UX. Coordinate with Product on PRD-related UX concerns.
- Same PR-back-to-template flow. CODEOWNERS on `steering/roles/uxd/`.

**Devs and QAs inside a stamped workbench**

- Read, do not author template steering directly (no forks per org policy; propose changes via PR to `ai-workbench`).
- Layer team-specific overrides into `steering.local/` when the team genuinely needs to diverge. Three operations: add a team-specific rule, supersede an upstream rule, remove an upstream rule that does not apply to your product. See `steering/README.md` for the file format.
- Use the `-LOCAL-NN` suffix on overlay rule IDs (the linter enforces this). Overlay frontmatter declares `supersedes: [ID]` or `removes: [ID]` explicitly.
- When a local override earns its stripes (applied for more than one epic, universally useful), raise a promotion PR on the template repo to move the file from `steering.local/` to `steering/` and drop the `-LOCAL` suffix. CODEOWNERS for the target directory review.
- Invoke the loader explicitly via each skill's step 0, or via `wb.steering <scope>`. Do not try to merge template and overlay in your head.
- `pmo-status` will surface any non-empty `steering.local/` in its "Steering overrides" section. Review it at session start; promote or justify.
- For a deeper view, run `wb.steering-audit`. It lists each override's kind, target template rule(s), age, last-updated date, and flags promote-suggest candidates (overrides whose scope is exercised by artifacts that span more than one epic in this workbench).

### Freshness

Steering changes upstream flow through `update.wb` into stamped workbenches. Changes mid-session (via `update.wb` or `git pull`) trigger a PostToolUse hook that re-emits Layer 0 into the agent's context, so the agent picks up fresh rules without a restart. Manual refresh: `wb.steering-refresh`.

### Tooling

```
wb.steering <scope>            # load merged rules for a scope (golden | role:x | artifact:x | topic:x)
wb.steering-refresh            # reload every scope
wb.steering-lint               # validate steering/ and steering.local/
wb.steering-audit              # markdown report of every overlay (kind, age, promote-suggest)
wb.steering-audit --json       # same data in machine-readable JSON
wb.steering-audit --list       # one-line-per-override terse view
```

### CI lint on stamped wbs

Every stamped wb ships `.github/workflows/wb-ci.yml`, seeded from the template via `update.wb` (it lives under `template_owned`). On each PR that touches `product/`, `design/`, `engineering/`, `qa/`, `steering/`, or `steering.local/` the workflow runs `python3 scripts/steering-lint.py` and then runs `python3 scripts/wb-ci-validate.py --stdin` over the diff between the PR base and head. The helper maps every changed file to one of the ten artifact types (`prd`, `eng-spec`, `tdd`, `erd`, `adr`, `bdd`, `test-cases`, `test-spec`, `test-erd`, `epic-context`) by directory prefix and runs `scripts/validate-artifact.py` on it, failing the PR if any required field (notably `target_repos`) is missing or points at an unregistered repo. The artifact step is skipped when `project.conf` is absent, so the workflow is a no-op steering-lint check inside the template repo itself.

## Multi-repo execution with ralph

The workbench wraps [ai-ralph](https://github.com/Invenco-Cloud-Systems-ICS/ai-ralph). Ralph owns the planner, the workspace loop, parallelism, and PR creation. Workbench only wraps, routes approved artifacts, and ships team steering.

### One-time bootstrap

`init.wb` and `join.wb` (in ai-devkit) both run a preflight that:

1. Installs the `ralph` binary from your local `ai-ralph` clone (or upstream) when missing.
2. Verifies `ralph --workspace` support.
3. Ensures `${WB_ROOT}/repos/` exists.
4. Purges every entry in `.workbench-manifest.json` `template_dev_only` so stamped wbs do not inherit the template's own `.ralph/PROMPT.md`, `.ralph/fix_plan.md`, `SESSION-HANDOFF.md`, or `CHANGELOG.md`.
5. Runs the workspace enable:

```bash
(cd "${WB_ROOT}/repos" && ralph enable --workspace --non-interactive --skip-tasks)
```

6. Calls `scripts/ralph-enable-check.sh` to confirm `${WB_ROOT}/repos/.ralph/` is healthy and `.ralphrc` carries `WORKSPACE_MODE=true`.

`init.wb` runs this at Step 3.4b; `join.wb` re-checks at Step 4b and idempotently re-enables if a joiner pulled an older workbench predating the bootstrap.

If you bootstrapped manually, run steps 5 and 6 yourself, then `wb.ralph-enable-check`.

Older stamped wbs that were created before this bootstrap can be migrated by running `update.wb`, which detects a missing `repos/.ralph/` and runs `ralph enable --workspace` once.

### Daily flow

```bash
# 1. Approve the chain for the epic you are working.
#    (Each skill checks target_repos on publish/approve.)
wb.publish PRD-042 product/outputs/prds/PRD-042-refund.md prd
wb.approve PRD-042
# ... spec, tdd, bdd, test-cases, test-spec...

# 2. Plan.
wb.ralph-plan
#   = sync-context → populate repos/<name>/ai/ + repos/.ralph/pr_footer.md
#   = (cd repos && ralph-plan --workspace --engine devin --thinking ultra)
#   → writes repos/.ralph/fix_plan.md with ## <repo-name> sections

# 3. Review the plan, then dispatch.
wb.ralph-dispatch
#   = (cd repos && ralph --workspace --parallel N)   # N defaults to min(len(REPOS),4)
#   → per-task worktree, commit, push, PR via ralph's own pr_manager

# 4. Watch.
wb.ralph-dispatch --status    # open PRs per repo + recent worker logs
```

### Replanning one repo

When a stakeholder change affects only one repo and you do not want to throw away the other repos' plans:

```bash
wb.ralph-plan --replan svc-a
#   = sync-context for svc-a
#   = (cd repos/svc-a && ralph-plan --engine ... --thinking ...)
#   = splice the resulting `## svc-a` section into repos/.ralph/fix_plan.md
#     (replaces existing section; appended if missing)
```

The splice runs under an advisory `flock` on `.workbench-state/.lock`, so it is safe to run while other workbench writers (publish / approve / reject) are active. `--replan` rejects an unknown repo name (`exit 2`) and is mutually exclusive with `--mode` and a positional repo argument.

### Subsetting a dispatch run

Narrow `wb.ralph-dispatch` to a subset of registered repos without rearranging directories or hand-editing `fix_plan.md`. Pairs with `--replan` for symmetric "plan one, execute one" runs.

```bash
# Allowlist: only these repos
wb.ralph-dispatch --repos api,worker

# Denylist: every repo except these
wb.ralph-dispatch --exclude web

# Combined with parallel: ralph caps parallelism at min(N, len(filtered_set))
wb.ralph-dispatch --parallel 4 --repos api,worker

# Drive from project.conf so all team members run the same scope
echo 'WB_RALPH_DISPATCH_REPOS="api,worker"' >> project.conf
wb.ralph-dispatch
```

`--repos` and `--exclude` are mutually exclusive. Names are validated against `project.conf REPOS` before pass-through, so a typo fails inside the wrapper with the registered list visible. Cross-repo tasks are skipped under any filter.

### Parallel planning

For workspaces with several repos, `wb.ralph-plan --parallel-plan N` runs up to N per-repo plan workers concurrently while keeping merged section ordering stable.

```bash
wb.ralph-plan --parallel-plan 4
#   = (cd repos && ralph-plan --workspace --engine ... --thinking ... --parallel-plan 4)
```

Resolution: CLI flag > `WB_RALPH_PLAN_PARALLEL` > `project.conf RALPH_PLAN_PARALLEL` > unset (sequential V1, byte-identical). The wrapper validates that the value is a positive integer and pre-checks that the installed `ralph-plan` advertises `--parallel-plan`; older binaries get a clear warning instead of a silent passthrough.

### Continuous dispatch

`wb.ralph-dispatch` defaults to batch mode: spawn N agents, wrapper exits when all N have stopped. **Continuous mode** keeps N workers saturated until M total task attempts have been spent (success or failure both count), or the queue drains. It is the right shape for long unattended runs over a deep workspace fix_plan.

```bash
# Named form (preferred — pairs cleanly with project.conf)
wb.ralph-dispatch --parallel 3 --max-tasks 30

# Positional form (mirrors ralph's `--parallel N M` shape byte-identically)
wb.ralph-dispatch --parallel 3 30

# Force single-pane orchestrator + 2 retries per task + 5s respawn cooldown
wb.ralph-dispatch --parallel 3 30 --no-tabs --max-task-attempts 2 --respawn-delay 5

# Drive from project.conf so the team runs the same shape
echo 'WB_RALPH_MAX_TASKS="50"' >> project.conf
wb.ralph-dispatch --parallel 4
```

Resolution for each knob: CLI flag > env > `project.conf` > unset. The wrapper capability-gates the forwarding against `ralph --help`: an older ralph that does not understand `--parallel N M` causes `wb.ralph-dispatch --max-tasks` to fail fast with a clear error, never silently downgrade to batch.

### Configuration

Set in `project.conf` (team default) or override via CLI flag / env var:

| Name | Values | Default | Notes |
|---|---|---|---|
| `RALPH_PLAN_MODE` / `--mode` / `WB_RALPH_PLAN_MODE` | auto \| workspace \| per-repo | auto | auto = use workspace if ralph-plan reports `--workspace`, else per-repo |
| `RALPH_PLAN_ENGINE` / `--engine` / `WB_RALPH_ENGINE` | devin \| claude \| codex | devin | passed to `ralph-plan` and (when recognised) `ralph` |
| `RALPH_PLAN_THINKING` / `--thinking` | default \| hard \| ultra | ultra | passed to `ralph-plan` |
| `WB_RALPH_PARALLEL` / `--parallel` | N | min(len(REPOS),4) | passed to `ralph --workspace` |
| `WB_RALPH_DISPATCH_REPOS` / `--repos` | comma list | unset | dispatch subset filter; only these registered repos run. Mutually exclusive with `--exclude`. |
| `WB_RALPH_DISPATCH_EXCLUDE` / `--exclude` | comma list | unset | dispatch denylist; every repo except these. |
| `RALPH_PLAN_PARALLEL` / `--parallel-plan` / `WB_RALPH_PLAN_PARALLEL` | N | unset | workspace planning concurrency; passes through to `ralph-plan --parallel-plan N`. |
| `WB_RALPH_MAX_TASKS` / `--max-tasks` / positional `--parallel N M` | M | unset | engages ralph's continuous mode (workers stay saturated until M attempts). |
| `WB_RALPH_MAX_TASK_ATTEMPTS` / `--max-task-attempts` | K | 1 (ralph) | per-task retry cap; task skip-listed after K failures. Inert without `--max-tasks`. |
| `WB_RALPH_RESPAWN_DELAY` / `--respawn-delay` | SEC | 0 (ralph) | cooldown between worker respawns. Inert without `--max-tasks`. |
| `WB_RALPH_DISABLE_TABS` (set `true`) / `--no-tabs` | bool | (off) | force single-pane orchestrator instead of per-worker terminal tabs. |

### `target_repos:` is required

Every PRD, eng-spec, TDD, ERD, BDD, test-cases, test-spec, and test-erd carries `target_repos: [...]` naming repos from `project.conf REPOS`. `wb.publish` and `wb.approve` both call `scripts/validate-artifact.py`, which rejects missing, empty, or unregistered target_repos. The list flows into `sync-context.sh` (only listed repos receive the artifact) and into `ralph-plan`'s `## <repo-name>` section routing.

### Steering drift footer on ralph PRs (M4)

When the team has local steering overrides under `steering.local/`, `sync-context.sh` writes a markdown footer to `$WB_ROOT/repos/.ralph/pr_footer.md`. Ralph reads that file at PR creation (via the upstream `pr-footer-append` support in `pr_manager.sh`) and appends it to every PR body. The footer file is removed when the overlay set empties.

## Plan-mode rule

Read `CLAUDE.md` for the session-start protocol and plan-mode rule. Summary: always explore and plan before writing code; never commit fix_plan entries without an approved PRD or engineering spec.

## Versioning + upgrades

ai-workbench (template) ships under semver. Stamped workbenches inherit the version they were created from in `.workbench-state/template-version.json`. Run `wb.upgrade` inside a stamped wb to pull template-owned files from upstream and refresh the stamp.

Notification banners fire automatically on `wb.publish`, `wb.approve`, `wb.ralph-plan`, etc., when the upstream template has a newer version than this wb. The check is throttled to one network call per 12h.

Full system documented in [ai-devkit/docs/versioning.md](https://github.com/amit-t/ai-devkit/blob/main/docs/versioning.md).

## Running on WSL2

WSL2 Ubuntu is a supported environment. See [`docs/onboarding-wsl.md`](docs/onboarding-wsl.md) for prereqs (`apt install zsh jq gh python3`), path advice (clone under `$HOME`, not `/mnt/c/`), and a common-issues troubleshooting list. The `.github/workflows/smoke-wb.yml` CI job runs the full onboarding flow on `ubuntu-latest` (the same shell environment as WSL2 Ubuntu); `tests/integration/smoke-wb-onboarding.sh` is its local mirror.
