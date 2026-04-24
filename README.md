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

### Freshness

Steering changes upstream flow through `update.wb` into stamped workbenches. Changes mid-session (via `update.wb` or `git pull`) trigger a PostToolUse hook that re-emits Layer 0 into the agent's context, so the agent picks up fresh rules without a restart. Manual refresh: `wb.steering-refresh`.

### Tooling

```
wb.steering <scope>     # load merged rules for a scope (golden | role:x | artifact:x | topic:x)
wb.steering-refresh     # reload every scope
wb.steering-lint        # validate steering/ and steering.local/
```

## Plan-mode rule

Read `CLAUDE.md` for the session-start protocol and plan-mode rule. Summary: always explore and plan before writing code; never commit fix_plan entries without an approved PRD or engineering spec.
