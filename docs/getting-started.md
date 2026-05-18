---
title: Getting Started
layout: default
eyebrow: Start Here
---

*Prefer the old long-form? See [V1 archive](./v1/getting-started.html).*

{% include links.html %}

## Install the devkit (once per machine)

```zsh
git clone {{ links.ai_devkit_repo }} ~/Projects/Tools-Utilities/ai-devkit
cd ~/Projects/Tools-Utilities/ai-devkit
./install.zsh
source ~/.zshrc
```

Adds three globals: `init.wb`, `join.wb`, `wb.upgrade`. `.dev` / `.cly` variants force Devin / Claude.

## Requirements

- `gh` CLI authenticated (HTTPS or SSH-with-custom-hostname).
- `git`, `rsync`, `python3`, `zsh`.
- `devin` CLI (default) or `claude` CLI.

## Stamp (initiator, often QA)

```zsh
mkdir ~/workbenches/wb-example && cd ~/workbenches/wb-example
init.wb
```

Devin prompts for label, epics, repos, roles, Figma refs, optional MCPs, target org (defaults to your login). Creates a **private** repo from the template, clones service + automation repos into `repos/`, seeds `project.conf` + `EPIC-PIPELINE.md`, writes `.github/CODEOWNERS` with you listed, commits, pushes. Share the resulting URL.

## Join (collaborator, often dev)

```zsh
cd ~/workbenches
join.wb https://github.com/<your-org>/wb-example
```

Devin asks what extra repos you want cloned, appends to `project.conf`, adds you to CODEOWNERS, commits, pushes.

## Pull template updates

```zsh
cd ~/workbenches/wb-example
wb.upgrade
```

One-way sync of `template_owned` paths only (skills, scripts, `CLAUDE.md`, `AGENTS.md`, `aliases.sh`). Your PRDs, specs, BDDs untouched.

## First session

```zsh
cd ~/workbenches/wb-example
source aliases.sh    # add to ~/.zshrc for next time
claude .             # or: devin .
```

Then `/epic-intake EPIC-001` to pull your first epic and start a PRD.
