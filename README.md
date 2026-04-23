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

## Plan-mode rule

Read `CLAUDE.md` for the session-start protocol and plan-mode rule. Summary: always explore and plan before writing code; never commit fix_plan entries without an approved PRD or engineering spec.
