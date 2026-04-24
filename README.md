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

## Plan-mode rule

Read `CLAUDE.md` for the session-start protocol and plan-mode rule. Summary: always explore and plan before writing code; never commit fix_plan entries without an approved PRD or engineering spec.
