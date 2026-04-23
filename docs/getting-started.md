---
title: Getting started
layout: default
---

# Getting started

## Install the devkit (once per machine)

```zsh
git clone https://github.com/amit-t/ai-devkit ~/Projects/Tools-Utilities/ai-devkit
cd ~/Projects/Tools-Utilities/ai-devkit
./install.zsh
source ~/.zshrc
```

You now have three global commands: `init.wb`, `join.wb`, `update.wb` (plus `.dev` and `.cly` variants to force Devin or Claude).

## Requirements

- `gh` CLI authenticated against GitHub (HTTPS or SSH with custom hostname — both supported).
- `git`, `rsync`, `python3`, `zsh`.
- `devin` CLI (default). `claude` CLI as fallback.

## Initiate a workbench (first collaborator, e.g. QA)

```zsh
mkdir ~/workbenches/wb-example && cd ~/workbenches/wb-example
init.wb
```

Devin asks: workspace label, epics in scope, repos to clone, roles, figma refs, optional MCPs, target GitHub org (defaults to your login). It creates a **private** repo from the `ai-workbench` template under your org, clones your service + automation repos into `repos/`, seeds `project.conf` and `EPIC-PIPELINE.md`, writes `.github/CODEOWNERS` with you listed, commits and pushes.

Share the resulting URL with your counterpart.

## Join an existing workbench (second collaborator, e.g. dev)

```zsh
cd ~/workbenches
join.wb https://github.com/<your-org>/wb-example
```

Devin asks what additional repos you want cloned for your part of the work, appends them to `project.conf`, adds you to `.github/CODEOWNERS`, commits, pushes.

## Pull template updates later

```zsh
cd ~/workbenches/wb-example
update.wb
```

One-way sync: fetches only template-owned paths (skills, scripts, CLAUDE.md, AGENTS.md, aliases.sh) from the `ai-workbench` upstream. Never touches your PRDs, specs, BDDs, etc.

## First session in a workbench

```zsh
cd ~/workbenches/wb-example
source aliases.sh    # add this line to ~/.zshrc for next time
claude .             # or: devin .
```

Try: `/epic-intake EPIC-001` to pull your first epic and start a PRD.
