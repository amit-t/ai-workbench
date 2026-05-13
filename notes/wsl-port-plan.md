# WSL2 Port — ai-workbench (Wave 3 / thin wrapper + dev surface)

**Master plan:** `/Users/amittiwari/.claude/plans/all-scripts-in-workbench-glowing-iverson.md`
**Wave:** 3 of 3 — **thin wrapper + dev surface**. Depends on Wave 1 (devkit) PR 1b and Wave 2 (ralph) PR 2b merging first. PRs 3c/3d can run in parallel with Wave 2 PRs 2c/2d.
**Locked decisions:** WSL2 Ubuntu only; require zsh on WSL; `ubuntu-latest` = WSL proxy in CI; sequential repos + phased PRs; non-breaking for existing macOS users.

---

## Scope (this repo only)

ai-workbench is the thinnest layer: it wraps ai-ralph and uses ai-devkit's shared lib. Workbench hard rules say: never reimplement ralph internals; never write into `repos/*`; never touch template-owned files (`skills/`, `steering/`, `aliases.sh` structure, `CLAUDE.md`, `AGENTS.md`, `.workbench-manifest.json`).

In scope:
- `.gitattributes` — LF policy
- `.github/workflows/test.yml` — extend with shell-lint + remove `TODO(windows)` comment
- `.github/workflows/smoke-wb.yml` — new E2E smoke: `init.wb → wb.publish → wb.approve → wb.steering golden → wb.ralph-enable-check → wb.ralph-plan --dry-run`
- `tests/test-aliases-bash-source.sh` — verify `aliases.sh` is sourceable from both bash and zsh
- `tests/integration/smoke-wb-onboarding.sh` — local runner of the smoke flow
- `docs/onboarding-wsl.md` — WSL-specific dev guide (new)
- `README.md` — add 3-line "Running on WSL2" pointer section
- `scripts/*.sh` — shellcheck-warning cleanup if needed (no speculative rewrites)

Out of scope (HARD GUARDS):
- `aliases.sh` content/structure — already portable (`#!/usr/bin/env bash`, uses `${BASH_SOURCE[0]:-$0}`)
- `skills/`, `steering/`, `CLAUDE.md`, `AGENTS.md`, `.workbench-manifest.json` (template-owned)
- Anything under `repos/` — those are stamped wb workspaces, not workbench-template code
- Reimplementing ralph internals (wb wraps, never reimplements per memory `feedback_layering_principle`)

---

## Existing patterns to reuse (do NOT rewrite)

- `aliases.sh:6,13-20` — `WB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"`. Sourceable from bash AND zsh.
- `scripts/ralph-plan.sh:40,76,84,196,220,240` — `--dry-run` flag ALREADY EXISTS and is properly wired. Smoke job can use it directly.
- `.github/workflows/test.yml:18-19` — TODO(windows) comment is the gate to remove once Wave 1 lib lands portable.

---

## PRs in this wave

### PR 3a — `chore(ci): lint matrix + .gitattributes + drop TODO(windows)`

**Create:**
- `.gitattributes`:
  ```
  * text=auto eol=lf
  *.sh text eol=lf
  *.zsh text eol=lf
  *.py text eol=lf
  *.md text eol=lf
  *.json text eol=lf
  *.yml text eol=lf
  *.yaml text eol=lf
  *.png binary
  ```

**Modify:**
- `.github/workflows/test.yml` — add new job `shell-lint` (matrix ubuntu-latest + macos-latest):
  1. `apt-get install -y zsh shellcheck` / `brew install shellcheck`
  2. `bash -n $(git ls-files '*.sh')`
  3. `zsh -n $(git ls-files '*.zsh')` (if any; currently none in repo)
  4. `shellcheck -x -e SC1091 $(git ls-files '*.sh')`
- Replace lines 18-19 `TODO(windows)` comment with:
  ```yaml
  # Windows-via-WSL2 is covered by the ubuntu-latest matrix slot above
  # (WSL2 Ubuntu = Linux kernel + Ubuntu userspace = same shell environment).
  # Native windows-latest deferred pending team-chat survey of dev usage.
  ```

**Verification:**
- CI green on both matrix slots.
- Local: `bash -n scripts/*.sh aliases.sh tests/*.sh` exits 0.
- Local: `shellcheck -x scripts/*.sh aliases.sh` exits 0 at default severity.

**Done when:** PR merged.

---

### PR 3b — `test(aliases): verify aliases.sh sourceable from bash AND zsh`

**Create:**
- `tests/test-aliases-bash-source.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  WB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fail=0

  # 1. bash source + function visibility
  if bash -c "source '$WB_DIR/aliases.sh' && type wb.publish >/dev/null && type wb.approve >/dev/null && type wb.ralph-plan >/dev/null"; then
    echo "[ok] bash source: aliases visible"
  else
    echo "[FAIL] bash source: aliases not visible after source"
    fail=1
  fi

  # 2. zsh source + function visibility (skip if zsh missing)
  if command -v zsh >/dev/null 2>&1; then
    if zsh -c "source '$WB_DIR/aliases.sh' && type wb.publish >/dev/null && type wb.approve >/dev/null && type wb.ralph-plan >/dev/null"; then
      echo "[ok] zsh source: aliases visible"
    else
      echo "[FAIL] zsh source: aliases not visible after source"
      fail=1
    fi
  else
    echo "[skip] zsh not installed; skipping zsh source check"
  fi

  # 3. _wb_check is a no-op when version-check.sh is absent
  if bash -c "WB_TEMPLATE_VERSION_FILE=/nonexistent source '$WB_DIR/aliases.sh' && HOME=/nonexistent _wb_check 2>&1 | grep -qv 'error'"; then
    echo "[ok] _wb_check: graceful no-op when version-check missing"
  else
    echo "[FAIL] _wb_check: not graceful when version-check missing"
    fail=1
  fi

  exit "$fail"
  ```
- Add to `.github/workflows/test.yml`:
  - New step in the existing `aliases-preamble` job (or a new job): `bash tests/test-aliases-bash-source.sh`
  - Install zsh on ubuntu-latest: `sudo apt-get install -y zsh`

**Modify:** none expected — aliases.sh is already portable per audit.

**Verification:**
- New test green on both matrix slots.

**Done when:** PR merged.

---

### PR 3c — `chore(lint): shellcheck warning cleanup for wb scripts`

Target files (audit list):
- `scripts/ralph-plan.sh`
- `scripts/ralph-dispatch.sh`
- `scripts/sync-context.sh`
- `scripts/ralph-context.sh`
- `scripts/ralph-enable-check.sh`
- `scripts/register-repo.sh`
- `scripts/check-docs-links.sh`
- `scripts/steering-post-tool-hook.sh`
- `aliases.sh` (verify, do NOT restructure)
- `tests/test-aliases-preamble.sh`
- `tests/smoke.sh`

For each:
- `shellcheck -S warning -x <file>`
- Fix mechanical findings only (quoting, `$(...)` vs backticks, `[[ ]]` over `[ ]`, etc.)
- No behaviour changes

**Modify:** `.github/workflows/test.yml` — tighten shell-lint to `-S warning` after cleanup.

**Verification:**
- `shellcheck -S warning -x scripts/*.sh aliases.sh tests/*.sh` exits 0.
- Existing tests still green.

**Done when:** PR merged.

---

### PR 3d — `ci(smoke): E2E onboarding (init.wb → publish → approve → wb.ralph-plan --dry-run)`

The headline smoke.

**Create:**
- `.github/workflows/smoke-wb.yml` — `runs-on: ubuntu-latest`:
  ```yaml
  name: smoke-wb
  on: [push, pull_request]
  jobs:
    onboard-e2e:
      runs-on: ubuntu-latest
      steps:
        - name: Install prereqs
          run: sudo apt-get update && sudo apt-get install -y zsh jq gh git python3 python3-pip
        - name: Check out workbench template
          uses: actions/checkout@v4
          with:
            path: ai-workbench
        - name: Check out devkit (pinned release)
          uses: actions/checkout@v4
          with:
            repository: amit-t/ai-devkit
            ref: main          # or pin a tag once releases stabilise
            path: ai-devkit
        - name: Check out ralph (pinned release)
          uses: actions/checkout@v4
          with:
            repository: amit-t/ai-ralph
            ref: main
            path: ai-ralph
        - name: Install ralph
          run: bash ai-ralph/install.sh --yes
        - name: Install devkit
          env:
            DEVKIT_NONINTERACTIVE: "1"
          run: zsh ai-devkit/install.zsh
        - name: Stamp a fresh workbench
          run: zsh ai-devkit/init-workbench/init.zsh wsl-smoke
        - name: Drop fixture artifacts at status:draft
          run: |
            cd ~/wb-wsl-smoke
            mkdir -p product/outputs/prds engineering/outputs/specs
            cat > product/context-library/epics/EPIC-001.md <<EOF
            ---
            type: epic-context
            status: draft
            target_repos: [demo-repo]
            ---
            # EPIC-001
            EOF
            cat > product/outputs/prds/PRD-001.md <<EOF
            ---
            type: prd
            status: draft
            target_repos: [demo-repo]
            ---
            # PRD-001
            EOF
        - name: Publish + approve
          run: |
            cd ~/wb-wsl-smoke
            source aliases.sh
            wb.publish EPIC-001 product/context-library/epics/EPIC-001.md epic-context
            wb.approve EPIC-001
            wb.publish PRD-001 product/outputs/prds/PRD-001.md prd
            wb.approve PRD-001
        - name: Steering golden
          run: cd ~/wb-wsl-smoke && source aliases.sh && wb.steering golden | head -20
        - name: Ralph enable check (preflight only)
          run: cd ~/wb-wsl-smoke && source aliases.sh && (cd repos && ralph enable --workspace) && wb.ralph-enable-check
        - name: wb.ralph-plan --dry-run
          run: cd ~/wb-wsl-smoke && source aliases.sh && wb.ralph-plan --dry-run
  ```
  This is a sketch — adjust to match actual `init.wb` invocation and template paths.
- `tests/integration/smoke-wb-onboarding.sh` — local runner of the same flow against `~/wb-wsl-smoke-local`.
- `docs/onboarding-wsl.md`:
  ```markdown
  # Running ai-workbench on WSL2

  Workbench supports WSL2 Ubuntu (bash 5.x with zsh installed). The end-to-end smoke runs on `ubuntu-latest` in CI; that's the same shell environment.

  ## Prereqs

      sudo apt install -y zsh jq gh git python3 curl

  ## Setup

  1. Install ai-ralph: `bash <(curl -fsSL https://raw.githubusercontent.com/amit-t/ai-ralph/main/install.sh) --yes`
  2. Install ai-devkit: `DEVKIT_NONINTERACTIVE=1 zsh <(curl -fsSL https://raw.githubusercontent.com/amit-t/ai-devkit/main/install.zsh)`
  3. Stamp a wb: `init.wb my-team`
  4. `cd ~/wb-my-team && source aliases.sh`

  ## Path advice

  Clone everything under `$HOME` (e.g. `~/projects/`), NOT `/mnt/c/`. DrvFs paths are 10x slower and break fsync semantics. `devkit doctor` warns if you run from `/mnt/`.

  ## Common issues

  - **CRLF errors** — repo `.gitattributes` enforces LF. If you cloned before this was added, run `git add --renormalize . && git commit -m 'chore: renormalize line endings'`.
  - **`type: wb.publish: not found`** — you didn't `source aliases.sh` in the current shell.
  - **`ralph: command not found`** — re-source your shell rc, or run from the absolute path `~/.local/bin/ralph`.
  - **WSL clock drift** breaks `date -d "$timestamp"` — run `sudo hwclock -s` to fix.
  ```

**Modify:**
- `README.md` — append:
  ```markdown
  ## Running on WSL2

  WSL2 Ubuntu is a supported environment. See [`docs/onboarding-wsl.md`](docs/onboarding-wsl.md) for prereqs (`apt install zsh jq gh python3`), path advice (clone under `$HOME`, not `/mnt/c/`), and common-issues troubleshooting.
  ```

**Verification:**
- CI smoke green.
- Manual: in a fresh `docker run --rm -it ubuntu:22.04 bash` container, follow `docs/onboarding-wsl.md` step-by-step, get to a green `wb.ralph-enable-check`.

**Done when:** PR merged. Wave 3 complete. **End of project** — perform final verification across all 7 criteria in master plan.

---

## Per-PR doneness gate

- [ ] `bash -n` on all `*.sh` exits 0
- [ ] `shellcheck -x` exits 0 at current severity
- [ ] New tests green on both ubuntu-latest and macos-latest
- [ ] macos-latest CI stays green — hard rule
- [ ] Conventional Commit message; HEREDOC body; Co-Authored-By Claude line
- [ ] PR description references master plan and lists which Wave/PR

## Wave-done criterion

All four PRs merged. CI smoke green. Manual docker walkthrough of `docs/onboarding-wsl.md` produces a working stamped wb that publishes/approves a fixture and runs `wb.ralph-plan --dry-run` without error. At that point all 7 master-plan verification criteria should hold; announce in team chat.

---

## Session kickoff prompt template

When you open Claude Code in this repo (`cd ~/Projects/Tools-Utilities/ai-workbench && claude`), the first prompt should be:

> Read `notes/wsl-port-plan.md` and the master plan it references. Ultrathink, enter plan mode, then execute Wave 3 PR 3a end-to-end. Boil the ocean: complete + tested + docs + verification. When done, summarise the diff and exit. I will review the PR before kicking off PR 3b.

Subsequent prompts: same pattern, named per PR.
