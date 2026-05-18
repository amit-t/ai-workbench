
*Prefer the old long-form? See [V1 archive](./v1/onboarding-wsl.html).*
# Running ai-workbench on WSL2

WSL2 Ubuntu is supported (bash 5.x with zsh installed). End-to-end smoke runs on `ubuntu-latest` in CI, the same shell environment, so green CI is a strong signal local WSL2 works.

## Prereqs

    sudo apt install -y zsh jq gh git python3 curl

## Setup

1. Install ai-ralph: `bash <(curl -fsSL https://raw.githubusercontent.com/amit-t/ai-ralph/main/install.sh)`
2. Install ai-devkit: `DEVKIT_NONINTERACTIVE=1 zsh <(curl -fsSL https://raw.githubusercontent.com/amit-t/ai-devkit/main/install.zsh) --yes`
3. Stamp: `init.wb my-team` (interactive, agent-driven; needs `gh` authenticated)
4. `cd ~/wb-my-team && source aliases.sh`

Companion repos (`ai-devkit`, `ai-ralph`) are siblings of this template. Their READMEs link back here for the WSL2 path.

## Path advice

Clone under `$HOME` (e.g. `~/projects/`), NOT `/mnt/c/`. DrvFs paths are 10x slower and break fsync semantics. `devkit doctor` warns if you run from `/mnt/`.

## Common issues

- **CRLF errors**. Repo `.gitattributes` enforces LF. If cloned before that was added: `git add --renormalize . && git commit -m 'chore: renormalize line endings'`.
- **`wb.publish: command not found`**. You didn't `source aliases.sh` in this shell.
- **`ralph: command not found`**. Re-source your shell rc, or run from `~/.local/bin/ralph`.
- **WSL clock drift** breaks `date -d "$timestamp"`. Fix: `sudo hwclock -s`.

## Verification

Local end-to-end smoke (same flow CI runs):

    bash tests/integration/smoke-wb-onboarding.sh

Sandboxes everything under `$(mktemp -d)`; exits non-zero on any assertion failure. Authoritative gate is the GitHub Actions equivalent at `.github/workflows/smoke-wb.yml`, which runs on every push and PR.
