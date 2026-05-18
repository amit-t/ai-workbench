---
title: Running on WSL2 (V1)
layout: default
---

> **V1 long-form archive.** Pre-precision-pass version, preserved for engineers who prefer the dense narrative.
> New (V2) version: [../onboarding-wsl.html](../onboarding-wsl.html).

# Running ai-workbench on WSL2

Workbench supports WSL2 Ubuntu (bash 5.x with zsh installed). The end-to-end smoke runs on `ubuntu-latest` in CI, the same shell environment, so a green CI is a strong signal that local WSL2 will work.

## Prereqs

    sudo apt install -y zsh jq gh git python3 curl

## Setup

1. Install ai-ralph: `bash <(curl -fsSL https://raw.githubusercontent.com/amit-t/ai-ralph/main/install.sh)`
2. Install ai-devkit: `DEVKIT_NONINTERACTIVE=1 zsh <(curl -fsSL https://raw.githubusercontent.com/amit-t/ai-devkit/main/install.zsh) --yes`
3. Stamp a wb: `init.wb my-team` (interactive, agent-driven; needs `gh` authenticated)
4. `cd ~/wb-my-team && source aliases.sh`

The companion repos (`ai-devkit`, `ai-ralph`) are siblings of this template. Their own READMEs link back to this guide for the WSL2 path.

## Path advice

Clone everything under `$HOME` (for example, `~/projects/`), NOT `/mnt/c/`. DrvFs paths are 10x slower and break fsync semantics. `devkit doctor` warns if you run from `/mnt/`.

## Common issues

- **CRLF errors**. Repo `.gitattributes` enforces LF. If you cloned before this was added, run `git add --renormalize . && git commit -m 'chore: renormalize line endings'`.
- **`wb.publish: command not found`**. You did not `source aliases.sh` in the current shell.
- **`ralph: command not found`**. Re-source your shell rc, or run from the absolute path `~/.local/bin/ralph`.
- **WSL clock drift** breaks `date -d "$timestamp"`. Run `sudo hwclock -s` to fix.

## Verification

For a local end-to-end smoke (same flow CI runs), execute the integration test against your clone:

    bash tests/integration/smoke-wb-onboarding.sh

The script sandboxes everything under `$(mktemp -d)` and exits non-zero on any assertion failure. CI runs the GitHub Actions equivalent at `.github/workflows/smoke-wb.yml` on every push and pull request, which is the authoritative gate.
