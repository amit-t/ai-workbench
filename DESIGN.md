---
name: ai-harness-design
description: Design spec for ai-workbench template + ai-devkit CLI — unified AI harness for dev/QA collaboration over Jira epic bundles
type: project
created: 2026-04-23
author: project owner
status: draft
---

# AI Harness Design — ai-workbench + ai-devkit

## 0. One-line summary

Two repos in your org. **`ai-workbench`** is a template repo cloned per work-bundle (one or more Jira epics) that gives a dev and a QA a shared private git repo with PRD / BDD / TDD / ERD / test-case workflows, ralph workspace-mode planning, and slots for service + automation code repos. **`ai-devkit`** is a global CLI that scaffolds workbenches (`init.wb`), lets collaborators clone + extend existing workbenches (`join.wb`), and pulls template updates one-way (`update.wb`).

## 1. Motivation

Individual-contributor engineers and QAs currently split work across Jira, Confluence, service repos, automation repos, and ad-hoc prompts. They want a single harness to:

- Take one or more Jira epics, generate a PRD, engineering spec, TDD, ERD, ADRs, BDDs, test cases, test spec.
- Wear PM / architect / staff-engineer / UX hats as needed without switching tools.
- Share generated drafts with the counterpart (dev ↔ QA) via git for review and approval.
- Plan code changes across multiple service repos in a single ralph workspace-mode session.
- Dispatch parallel autonomous ralph loops across repos from one place.
- Keep the workbench private, per-bundle, and disposable — not a long-running OS.

The existing solutions (`app-hq`, `ai-fullstack-harness`, `ai-app-bios`) are the foundation. This design consolidates their best parts for the individual-contributor use case, drops OS-scope jargon, and adds a first-class QA role.

## 2. Non-goals

- Not a long-running team-wide planning OS. Each workbench is per-bundle.
- Not a CI/CD platform. Workbench does not run tests or deploys.
- Not a Jira replacement. Workbench references Jira; source of truth stays in Jira.
- No forking anywhere. Only `gh repo create --template` and explicit clones.
- No bidirectional template sync. Workbench → template is via manual PR, not automated.

## 3. Actors and roles

| Actor | In-workbench hat | Primary outputs |
|-------|------------------|-----------------|
| Dev (IC) | PO, Architect, Staff Eng, UX, Dev | PRD, engineering spec, TDD, ERD, ADRs, code |
| QA (IC) | PO, QA | PRD, BDD `.feature` files, test cases, test spec, test ERD, automation code |

Either can be the **initiator** (first to run `init.wb`). The other is the **joiner** (runs `join.wb`).

## 3.5 Artifact lifecycle

Every artifact produced inside a workbench (PRD, engineering spec, TDD, ERD, ADR, BDD feature, test cases, test spec, test ERD) carries a `status` field in YAML frontmatter and flows through three states:

| Stage | Meaning | Who sets it | Where recorded |
|-------|---------|-------------|----------------|
| `draft` | Agent wrote it. Internal to workbench. Not circulated. | Skill (e.g. `/prd-draft`) | frontmatter only |
| `published` | Human-reviewed, deemed ready for panel / counterpart review. | `wb.publish <id> <path> <type>` | frontmatter + `.workbench-state/published.json` |
| `approved` | Signed off. Ralph may ingest. | `wb.approve <id>` | frontmatter + `.workbench-state/approved.json` |

Rejection is a side path: `wb.reject <id> "<reason>"` returns the artifact to `draft`, records the reason in `.workbench-state/rejected.json`. Rejection works from any state (including `approved`).

**Rules:**
- Skills write `draft`. Skills never set `published` or `approved`.
- Transitions are strictly ordered: cannot approve without first publishing.
- Downstream skills gate on upstream `approved` (e.g. `/eng-spec` requires the parent PRD at `approved`).
- `sync-context.sh` reads `.workbench-state/approved.json` exclusively — frontmatter is not inspected at sync time. The JSON is the contract with ralph.
- Lifecycle commands are not concurrency-safe. Pull before and push after transitions.

## 4. Repo shapes

### 4.1 `ai-workbench` — template

```
ai-workbench/
  CLAUDE.md                       # session start, plan-mode, role inference
  AGENTS.md                       # shared agent constitution (Claude + Devin + Codex)
  README.md                       # what this template does + how to use init.wb
  .gitignore
  .workbench-manifest.json        # which paths are template-owned vs user-owned
  .mcp.json.template              # optional MCPs (Jira, Figma) — env-ref style
  project.conf.template           # filled in by init.wb
  EPIC-PIPELINE.md.template       # filled in by init.wb
  aliases.sh                      # wb.* commands sourced per workbench
  .github/
    CODEOWNERS                    # placeholder; init + join rewrite
  product/                        # PO hat — PRDs
    context-library/
      epics/                      # pulled Jira epic bodies (one MD per epic)
    outputs/
      prds/                       # PRDs (lifecycle tracked in .workbench-state/)
  design/                         # UX hat — figma pulls, design system refs
    context-library/
      figma-links.md
      design-system-ref.md
    outputs/
      wireframes/
      screens/
      handoffs/
  engineering/                    # Architect + Staff hat
    context-library/
    outputs/
      specs/                      # engineering spec
      tdd/                        # technical design docs
      erd/                        # entity/component diagrams
      adrs/                       # architecture decision records
  qa/                             # QA hat
    context-library/
    outputs/
      bdd/                        # Gherkin .feature files
      test-cases/                 # structured test cases (MD or CSV)
      test-spec/                  # QA equivalent of engineering spec
      test-erd/                   # test coverage model
  ralph/                          # workspace-mode ralph state
    workspace-plan.md             # human-readable rollup of per-repo fix_plans
    dispatch.log                  # parallel loop launch log
  repos/                          # gitignored — code repos cloned here
    .gitkeep
  .workbench-state/               # lifecycle state (shared via git)
    published.json                # draft → published transitions
    approved.json                 # published → approved transitions (source of truth for ralph gate)
    rejected.json                 # reason-tracked rejections
  scripts/
    sync-context.sh               # workbench → repos/{x}/ai/
    ralph-context.sh              # identical target, used by ralph-plan
    ralph-plan.sh                 # wraps ralph-plan --workspace
    ralph-loop.sh                 # cd repos/{x} && rpc.int | rpd.int | rpx.int
    ralph-dispatch.sh             # parallel launch across repos
    register-repo.sh              # append a repo entry to project.conf
  skills/                         # bundled role skills (symlinked into .claude/.agents/.devin at init)
    epic-intake/SKILL.md
    prd-draft/SKILL.md
    prd-review-panel/SKILL.md
    bdd-gen/SKILL.md
    test-cases-gen/SKILL.md
    test-spec/SKILL.md
    eng-spec/SKILL.md
    tdd/SKILL.md
    erd/SKILL.md
    adr/SKILL.md
    figma-pull/SKILL.md
    ds-screen-gen/SKILL.md
    design-draft/SKILL.md
    design-review/SKILL.md
    ralph-workspace-plan/SKILL.md
    ralph-dispatch/SKILL.md
    grill-me/SKILL.md
    pmo-status/SKILL.md
```

### 4.2 `ai-devkit` — global CLI

```
ai-devkit/
  README.md
  .gitignore
  install.zsh                       # wires all commands to ~/.local/bin + ~/.zshrc
  init-workbench/
    init.zsh                        # thin launcher
    init.prompt.md                  # Devin/Claude interview + scaffold steps
  join-workbench/
    join.zsh
    join.prompt.md
  update-workbench/
    update.zsh
    update.prompt.md                # only used if interactive conflict resolution is needed
```

### 4.3 Workbench instance

```
~/workbenches/wb-example/            ← cloned workbench instance (git repo)
  ...workbench files and folders...
  repos/
    example-service/                 ← cloned code repo (own git)
    example-automation-tests/        ← cloned code repo (own git)
```

## 5. Commands and aliases

### 5.1 Devkit (global)

| Alias | What it does | Default agent | Force variants |
|-------|-------------|---------------|----------------|
| `init.wb` | Scaffold new workbench + instance git repo | Devin | `init.wb.dev` (Devin), `init.wb.cly` (Claude) |
| `join.wb <url>` | Clone existing workbench + Devin interview for extra repos | Devin | `join.wb.dev`, `join.wb.cly` |
| `update.wb` | One-way pull of template-owned paths from `ai-workbench` | Devin | `update.wb.dev`, `update.wb.cly` |

### 5.2 Workbench (local, via `aliases.sh`)

| Alias | What it does |
|-------|-------------|
| `wb.sync-context` | Push approved workbench artifacts into each `repos/*/ai/` (reads `.workbench-state/approved.json`) |
| `wb.ralph-plan` | Run ralph workspace-mode plan; writes per-repo `.ralph/fix_plan.md` + `ralph/workspace-plan.md` |
| `wb.ralph-loop <repo> [--agent ...]` | Launch a ralph loop in one repo |
| `wb.ralph-dispatch [--repos r1,r2]` | Launch ralph loops across multiple repos in parallel |
| `wb.register-repo <name> <url> <role>` | Append a repo entry to `project.conf` and clone |
| `wb.publish <id> <path> <type>` | Transition `draft → published` (flips frontmatter + appends `published.json`) |
| `wb.approve <id>` | Transition `published → approved` (flips frontmatter + moves entry to `approved.json`) |
| `wb.reject <id> "<reason>"` | Send artifact back to `draft` with a reason in `rejected.json` (works from any state) |
| `wb.published` | List artifacts currently in `published` state (awaiting approval) |
| `wb.approved` | List artifacts currently in `approved` state (ralph-ingestable) |

## 6. Flows

### 6.1 Initiator flow (`init.wb`)

Interview (Devin by default):

1. Workspace label (lowercase slug, e.g. `example`). If blank, derive from primary epic ID + YYYYMMDD.
2. Primary epic ID. Additional epic IDs (comma separated). Jira MCP available? If yes, offer to pull epic bodies now.
3. Repos to register in this workbench — loop: name, git URL, role (`service` | `automation-tests` | `shared-lib` | `infra`), short stack hint.
4. Figma URLs (optional). Design system repo / doc URL (optional).
5. Optional MCPs to enable (Jira, Figma). Writes creds as `${ENV_VAR}` refs, not literals.
6. Target GitHub org (default: your GitHub login from `gh api user -q .login`, override to any org slug you can push to).

Execution:

```bash
gh repo create {ORG}/wb-{label} --template {ORG}/ai-workbench --private --clone
cd wb-{label}
git remote add upstream https://github.com/{ORG}/ai-workbench.git
# clone each user-listed code repo into repos/{name}/
# render project.conf, EPIC-PIPELINE.md, .mcp.json, .github/CODEOWNERS
# symlink skills/ into .claude/skills, .agents/skills, .devin/skills
# git add, commit, push
```

`.github/CODEOWNERS` after init:

```
# Auto-managed by ai-devkit — initiator + joiners appended
*  @<initiator-gh-user>
```

### 6.2 Joiner flow (`join.wb <url>`)

Interview:

1. Show registered repos from `project.conf`. Ask: additional repos? Loop name/url/role/stack-hint.
2. Confirm which epic is the joiner's focus (optional metadata on their local commits).

Execution:

```bash
git clone {url}
cd wb-{label}
# clone each new code repo into repos/{name}/
# append entries to project.conf (REPOS array)
# append @<joiner-gh-user> to .github/CODEOWNERS `*` line (idempotent)
# if upstream remote is missing, read WORKBENCH_TEMPLATE_UPSTREAM from project.conf and add it
# git add, commit, push
```

### 6.3 Update flow (`update.wb`)

Non-interactive by default. Devin used only if interactive conflict resolution is needed.

```bash
# inside a workbench
git fetch upstream main
# for each glob in .workbench-manifest.json template_owned:
#   git checkout upstream/main -- {path}
# git add those paths
# commit: "chore: sync template-owned files from ai-workbench@{sha}"
# push
```

Never touches paths in `user_owned`. Never modifies content under `product/`, `design/`, `engineering/`, `qa/`, `ralph/`, `repos/`, `.workbench-state/`, `project.conf`, `EPIC-PIPELINE.md`, `.mcp.json`, `.github/CODEOWNERS`.

## 7. Template manifest

`.workbench-manifest.json` is the source of truth for what `update.wb` is allowed to touch.

```json
{
  "version": 1,
  "template_owned": [
    "CLAUDE.md",
    "AGENTS.md",
    "README.md",
    "aliases.sh",
    ".gitignore",
    ".workbench-manifest.json",
    "scripts/**",
    "skills/**"
  ],
  "user_owned": [
    "project.conf",
    "EPIC-PIPELINE.md",
    ".mcp.json",
    ".github/CODEOWNERS",
    "product/**",
    "design/**",
    "engineering/**",
    "qa/**",
    "ralph/**",
    "repos/**",
    ".workbench-state/**"
  ]
}
```

Rules:

- Every tracked path must appear in exactly one of the two lists.
- `update.wb` only pulls `template_owned`.
- Workbench CI (future) will lint this invariant.

## 8. Pipeline file

**`EPIC-PIPELINE.md`** — hierarchical, one file at workbench root. Each epic gets an H2 section with a PRD table and a free-form notes block.

```markdown
# Workbench Pipeline

## EPIC EPIC-001 — Example refactor
Status: in-progress
Jira: https://<your-jira-domain>.atlassian.net/browse/EPIC-001
Context: product/context-library/epics/EPIC-001.md

### PRDs
| PRD | Status | Spec | BDD | TDD | ERD | Test Spec | fix_plan repos | Exec |
|-----|--------|------|-----|-----|-----|-----------|----------------|------|
| PRD-001 Example feature | approved | SPEC-001 | BDD-001 | TDD-001 | ✓ | TSD-001 | example-service, example-automation-tests | ~ |
| PRD-002 Follow-up flow | draft | — | — | — | — | — | — | — |

### Notes
- Owner: <gh-user>
- Target PI: PI3

## EPIC EPIC-002 — Example screen refresh
...

---

## Queued PRDs
| Priority | PRD | Rationale | Depends on |
|----------|-----|-----------|------------|

## Completed
| PRD | Shipped |
|-----|---------|
```

## 9. Ralph adapter

### 9.1 Contract

ai-ralph is currently single-repo. Workspace mode (PR #3 in the `<your-org>/ai-ralph` repo) is assumed to extend `ralph-plan` such that, when invoked from a workbench root, it:

- Aggregates all approved workbench context (PRDs, specs, BDDs, test specs — filtered by `.workbench-state/approved.json`; the old `product/outputs/prds/approved/` gate folder was removed in Phase 2).
- Scans `repos/*`.
- Writes per-repo `.ralph/fix_plan.md` files, one per target repo.
- Writes a workbench-level summary at `ralph/workspace-plan.md`.

The workbench ships thin adapter scripts. When PR #3 lands with its final command surface (flag name, command name), only these scripts change — skill bodies, CLAUDE.md, and everything else stay stable.

### 9.2 Adapter scripts

```
scripts/ralph-context.sh
  # Push workbench artifacts into each repos/{x}/ai/ dir per role
  #   role=service           → PRDs (approved) + specs + TDD + ERD + ADRs
  #   role=automation-tests  → PRDs (approved) + BDDs + test cases + test spec
  #   role=shared-lib        → specs + TDD + ADRs
  #   role=infra             → ADRs only
  # Filter via project.conf REPOS array

scripts/ralph-plan.sh
  # TODO(phase-2): wrap ai-ralph workspace command
  # Likely: ralph-plan --workspace (or --workbench) invoked from workbench root
  # For single-repo fallback (before PR #3 merges): iterate repos/* and run
  #   (cd repos/{x} && ralph-plan) with repo-specific context prepared by ralph-context.sh

scripts/ralph-loop.sh <repo> [--agent claude|devin|codex]
  # cd repos/{repo} && {rpc.int|rpd.int|rpx.int}
  # Pass through --live --monitor by default

scripts/ralph-dispatch.sh [--repos r1,r2,...] [--agent ...]
  # For each repo, launch ralph-loop in a background process (nohup) or tmux pane
  # Log PIDs + streams to ralph/dispatch.log
  # Status: ralph-dispatch.sh --status reads the log and git status of each worktree
```

## 10. MCP policy

- MCP config is per-workbench, stored at `.mcp.json`, gitignored. Template ships `.mcp.json.template` with env-ref placeholders.
- Claude Code auto-loads project-level `.mcp.json` when a session opens in that dir. Do not touch global MCP config.
- Default template includes no active MCP servers. Init interview asks which to enable. Typical set: Atlassian (Jira), Figma.
- Secrets are env-ref only. Example:

  ```json
  {
    "mcpServers": {
      "atlassian": {
        "command": "npx",
        "args": ["-y", "@atlassian/mcp-server"],
        "env": { "ATLASSIAN_TOKEN": "${ATLASSIAN_TOKEN}" }
      }
    }
  }
  ```

- `.mcp.json` itself is gitignored even after init writes it. Each collaborator supplies their own env vars. (We keep config tracked via `.mcp.json.template` which shows the agreed server set; each collaborator copies it to `.mcp.json` on join.)

## 11. Config files

### 11.1 `project.conf` (workbench-instance, committed)

```bash
#!/usr/bin/env bash
# Workbench configuration — written by init.wb, appended by join.wb

# --- Identity ---
WORKBENCH_LABEL="example"
WORKBENCH_REPO="https://github.com/<your-org>/wb-example"
WORKBENCH_TEMPLATE_UPSTREAM="https://github.com/<your-org>/ai-workbench"
WORKBENCH_CREATED_BY="<gh-user>"
WORKBENCH_CREATED_AT="2026-04-23"

# --- Epics in scope ---
EPICS=("EPIC-001" "EPIC-002")

# --- Managed code repos ---
# Each entry: name=<name>;url=<git_url>;role=<service|automation-tests|shared-lib|infra>;stack=<short>;added_by=<gh-user>
REPOS=(
  "name=example-service;url=https://github.com/<your-org>/example-service;role=service;stack=node-nest;added_by=<gh-user>"
  "name=example-automation-tests;url=https://github.com/<your-org>/example-automation-tests;role=automation-tests;stack=playwright;added_by=<qa-gh-user>"
)
```

### 11.2 `.gitignore` (workbench-instance)

```
# Code repos manage their own git history
repos/*
!repos/.gitkeep

# Secrets
.mcp.json

# OS junk
.DS_Store
*.swp

# Dispatch runtime
ralph/dispatch.log
```

## 12. Naming rules

- Workbench repo name must match `^wb-[a-z0-9][a-z0-9-]*$`.
- Max length 60 chars (GitHub practical limit).
- `init.wb` normalizes any user input accordingly and rejects duplicates.
- Fallback label: `wb-<primary-epic-id-lowercased>-YYYYMMDD` (e.g. `wb-epic-001-20260423`).

## 13. Security model

- Workbenches are **private** GitHub repos. Only CODEOWNERS listed accounts have push access (org defaults).
- MCP tokens stay in env vars per collaborator; never committed, never echoed in prompts.
- `.mcp.json.template` documents which MCP servers are expected but carries no secrets.
- `gh auth status` is inspected before every command that touches GitHub. HTTPS or SSH (+custom hostname alias) is respected and reused — matches `ai-app-bios` behavior.
- No force-push anywhere in devkit. No bypass of branch protections. No skipping hooks.

## 14. Two-phase build

### Phase 1 — scaffold (this session)

- Full directory trees for `ai-workbench` and `ai-devkit`.
- All config templates, manifests, README/CLAUDE/AGENTS files.
- Script skeletons with clear TODOs and safe fail-closed defaults.
- Skill stubs — frontmatter only. No bodies.
- `init.prompt.md`, `join.prompt.md`, `update.prompt.md` — minimum viable content so user can read them end-to-end. Bodies filled out to the extent needed for Phase 1 to function when dry-run.
- No git init, no GitHub operations, no network calls. Local files only.

### Phase 2 — fill in

- Skill bodies: `epic-intake`, `prd-draft`, `bdd-gen`, `test-cases-gen`, `test-spec`, `eng-spec`, `tdd`, `erd`, `adr`, `ralph-workspace-plan`, `ralph-dispatch`, `figma-pull`, `ds-screen-gen`, `design-draft`, `design-review`, plus `pmo-status` and `grill-me` copies.
- `ralph-plan.sh` and `ralph-dispatch.sh` wrapped against ai-ralph workspace mode once PR #3 is merged and the command surface is known.
- `init.prompt.md` full interview script with Jira MCP / Figma MCP branching.
- `join.prompt.md` with repo-addition loop.
- `update.zsh` polished with conflict detection and report.
- Integration tests (bats or zsh-based) for init/join/update smoke flows.

## 15. Open risks

- **Workspace-mode ralph contract uncertainty.** Until PR #3 merges, the ralph adapter can only stub its external interface. Mitigation: isolate ralph calls behind three scripts so the integration changes in one place.
- **Template-instance drift.** If a user edits a `template_owned` path locally, `update.wb` will overwrite their changes on next run. Mitigation: detect manual edits and abort with a clear error; require either reverting the path or moving the change upstream via PR to `ai-workbench`.
- **GitHub auth mode diversity.** Some collaborators use HTTPS, some use SSH with custom host aliases. Mitigation: carry over the `GIT_URL_PREFIX` detection logic verbatim from `ai-app-bios`.
- **Mac-only scripts.** Current shell scripts use `sed -i ''` (BSD sed). Linux collaborators will break. Mitigation: detect and branch, or use a python fallback.

## 16. Future work (explicitly out of scope)

- Skills quality audit (port from ai-fullstack-harness).
- Workbench quality dashboard across multiple workbenches (cross-project rollup).
- Figma MCP auto-pull on session start.
- Jira-side automation: push PRD approval status back into the epic.
- Team-wide shared skills catalog — parked, handled by existing `at-skills` + `skill-sync`.
