---
title: Architecture
layout: default
eyebrow: Architecture
---

{% include links.html %}

## Problem and Motivation

Individual-contributor engineers and QAs currently split work across Jira, Confluence, service repos, automation repos, and ad-hoc prompts. They want a single harness to take one or more Jira epics, generate a PRD, engineering spec, TDD, ERD, ADRs, BDDs, test cases, and a test spec; wear PM / architect / staff-engineer / UX hats without switching tools; share generated drafts with the counterpart (dev ↔ QA) via git for review and approval; plan code changes across multiple service repos in a single ralph workspace-mode session; dispatch parallel autonomous ralph loops; and keep the workbench private, per-bundle, and disposable — not a long-running OS.

## Two-Repo Shape

The harness is two GitHub repos, independent, published under `<your-org>` (defaults to your GitHub login).

| Repo | Role | Lives at |
|------|------|----------|
| `ai-workbench` | Template. Cloned per work-bundle. Ships skills, scripts, lifecycle aliases, config templates. | `{{ links.ai_workbench_repo }}` |
| `ai-devkit` | Global CLI. Installs `init.wb`, `join.wb`, `update.wb`. | `{{ links.ai_devkit_repo }}` |

You never clone `ai-workbench` directly — `init.wb` stamps private instances from it via `gh repo create --template`.

## Workbench Directory Tree

A stamped workbench (`wb-<label>`) looks like this:

```
wb-<label>/
├── CLAUDE.md                         # session start, plan-mode, role inference
├── AGENTS.md                         # shared agent constitution (Claude + Devin + Codex)
├── README.md                         # what this template does + how to use init.wb
├── .gitignore
├── .workbench-manifest.json          # which paths are template-owned vs user-owned
├── .mcp.json.template                # optional MCPs (Jira, Figma) — env-ref style
├── project.conf                      # filled in by init.wb (identity, epics, repos)
├── EPIC-PIPELINE.md                  # pipeline rollup — one H2 per epic
├── aliases.sh                        # wb.* commands sourced per workbench
├── .github/
│   └── CODEOWNERS                    # initiator + joiners appended
├── product/
│   ├── context-library/
│   │   └── epics/                    # pulled Jira epic bodies (one MD per epic)
│   └── outputs/
│       └── prds/                     # PRDs (lifecycle tracked in .workbench-state/)
├── design/
│   ├── context-library/
│   │   ├── figma-links.md
│   │   └── design-system-ref.md
│   └── outputs/
│       ├── wireframes/
│       ├── screens/
│       └── handoffs/
├── engineering/
│   ├── context-library/
│   └── outputs/
│       ├── specs/                    # engineering spec
│       ├── tdd/                      # technical design docs
│       ├── erd/                      # entity/component diagrams
│       └── adrs/                     # architecture decision records
├── qa/
│   ├── context-library/
│   └── outputs/
│       ├── bdd/                      # Gherkin .feature files
│       ├── test-cases/               # structured test cases (MD or CSV)
│       ├── test-spec/                # QA equivalent of engineering spec
│       └── test-erd/                 # test coverage model
├── ralph/
│   ├── workspace-plan.md             # human-readable rollup of per-repo fix_plans
│   └── dispatch.log                  # parallel loop launch log (gitignored)
├── repos/                            # gitignored — code repos cloned here
│   └── .gitkeep
├── .workbench-state/                 # lifecycle state (shared via git)
│   ├── published.json                # draft → published transitions
│   ├── approved.json                 # published → approved transitions (ralph gate)
│   └── rejected.json                 # reason-tracked rejections
├── steering/                         # template-owned rule files (golden, role, artifact, topic)
├── steering.local/                   # team-owned overlays (add / supersede / remove)
├── .claude/
│   └── settings.json                 # PostToolUse hook re-emits Layer 0 steering on update
├── scripts/
│   ├── lifecycle.py                  # unified publish/approve/reject CLI with flock
│   ├── sync-context.sh               # workbench → repos/{x}/ai/, writes pr_footer.md
│   ├── ralph-context.sh              # internal alias for sync-context.sh, used by ralph-plan
│   ├── ralph-plan.sh                 # wraps `ralph-plan --workspace` with per-repo fallback
│   ├── ralph-dispatch.sh             # wraps `ralph --workspace --parallel N`
│   ├── ralph-enable-check.sh         # preflight that `ralph enable --workspace` ran
│   ├── validate-artifact.py          # blocks publish/approve when target_repos is missing
│   ├── artifact-schema.json          # JSON schema used by validate-artifact.py
│   ├── steering-load.py              # merge template + overlay rules for a scope
│   ├── steering-overlays.py          # render add/supersede/remove footer for ralph PRs
│   ├── steering-lint.py              # validate steering/ and steering.local/
│   ├── steering-post-tool-hook.sh    # Claude Code PostToolUse hook for steering freshness
│   └── register-repo.sh              # append a repo entry to project.conf
├── tests/                            # template smoke tests
│   ├── README.md
│   └── smoke.sh
└── skills/                           # symlinked into .claude/.agents/.devin at init
    ├── epic-intake/SKILL.md
    ├── prd-draft/SKILL.md
    ├── prd-review-panel/SKILL.md
    ├── bdd-gen/SKILL.md
    ├── test-cases-gen/SKILL.md
    ├── test-spec/SKILL.md
    ├── eng-spec/SKILL.md
    ├── tdd/SKILL.md
    ├── erd/SKILL.md
    ├── adr/SKILL.md
    ├── figma-pull/SKILL.md
    ├── ds-screen-gen/SKILL.md
    ├── design-draft/SKILL.md
    ├── design-review/SKILL.md
    ├── ralph-workspace-plan/SKILL.md
    ├── ralph-dispatch/SKILL.md
    ├── grill-me/SKILL.md
    └── pmo-status/SKILL.md
```

## `project.conf` — The Per-Workbench Manifest

`project.conf` is a committed shell file written by `init.wb` and extended by `join.wb`. Aliases and scripts source it.

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

## `.workbench-manifest.json` — Template-Owned vs User-Owned

Only paths in `template_owned` are touched by `update.wb`. Everything else (your PRDs, specs, BDDs, test cases, code repos, lifecycle state) is `user_owned` and never overwritten.

```json
{
  "version": 2,
  "template_owned": [
    "CLAUDE.md",
    "AGENTS.md",
    "README.md",
    "aliases.sh",
    ".gitignore",
    ".workbench-manifest.json",
    ".mcp.json.template",
    "project.conf.template",
    "EPIC-PIPELINE.md.template",
    ".claude/settings.json",
    ".github/CODEOWNERS",
    ".github/workflows/**",
    "scripts/**",
    "skills/**",
    "steering/**",
    "tests/**"
  ],
  "user_owned": [
    "project.conf",
    "EPIC-PIPELINE.md",
    ".mcp.json",
    "product/**",
    "design/**",
    "engineering/**",
    "qa/**",
    "ralph/**",
    "repos/**",
    "steering.local/**",
    ".workbench-state/**"
  ]
}
```

Rules:

- Every tracked path must appear in exactly one of the two lists.
- `update.wb` only pulls `template_owned`.
- Do not hand-edit template-owned paths in an instance — propose a PR to `ai-workbench` upstream instead.

## Lifecycle

Every generated artifact (PRD, spec, TDD, ERD, ADR, BDD, test cases, test spec) flows through `draft → published → approved`. See [Artifact lifecycle](./lifecycle.html) for the full state machine, downstream preconditions, and lifecycle commands.

## Security Model

- Workbench repos are **private**. Only CODEOWNERS-listed accounts have push access.
- MCP tokens stay in env vars per collaborator; never committed.
- `.mcp.json.template` documents the agreed MCP server set; `.mcp.json` itself is gitignored.
- `gh auth status` is inspected before every command that touches GitHub. HTTPS or SSH (with custom hostname alias) is respected.
- No force-push anywhere. No bypass of hooks or branch protections.

## Naming Rules

- Workbench repo name must match `^wb-[a-z0-9][a-z0-9-]*$`.
- Max length 60 chars.
- `init.wb` normalises input and rejects duplicates.
- Fallback label: `wb-<primary-epic-id-lowercased>-YYYYMMDD`.
