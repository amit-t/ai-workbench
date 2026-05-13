---
title: Multi-workbench resolution for wb.* aliases
status: draft
date: 2026-05-13
owner: amit-t
relates_to:
  - aliases.sh
  - scripts/ralph-dispatch.sh
  - scripts/ralph-plan.sh
  - tests/test-aliases-preamble.sh
---

# Multi-workbench resolution for `wb.*` aliases

## Problem

`aliases.sh` bakes `WB_ROOT` at source time:

```sh
WB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
```

When a user maintains more than one stamped workbench (or sources `aliases.sh` from `ai-workbench/` template-dev clone), every `wb.*` call targets the wb that was sourced — even when the user is `cd`'d into a different wb. Reproducer:

```
$ source /Users/amittiwari/Projects/Tools-Utilities/ai-workbench/aliases.sh
$ cd /Users/amittiwari/Projects/Tools-Utilities/wb-gitlore
$ wb.ralph-dispatch --parallel 10
project.conf not found at /Users/amittiwari/Projects/Tools-Utilities/ai-workbench
```

The current workaround (`source the other wb's aliases.sh`) does not scale beyond one wb per shell, and the user has to remember to re-source whenever they switch context. This forces a 1:1 shell-per-wb discipline that defeats parallel-wb workflows.

## Goal

Make every `wb.*` alias resolve the target workbench dynamically per call. A single sourced `aliases.sh` must serve every stamped wb on the machine, regardless of how many wbs exist or which one the user is currently in.

## Non-goals

- Persistent registry of known workbenches (no `~/.config/wb/registry`). YAGNI until label-resolution is requested.
- Label-style argument for `wb.switch` (no `wb.switch gitlore`). Path-only V1. Add later if needed.
- Cross-shell pin persistence. Pin is shell-local via `WB_PIN` env var; intentional.
- Changing scripts under `scripts/`. They already self-derive `WB_ROOT` from `${SCRIPT_DIR}/..`; alias-level resolution is the only fix needed.

## Resolution algorithm

A new shell helper `_wb_resolve_root` is invoked at the top of every meaningful `wb.*` function. It writes the resolved absolute path to stdout, or exits non-zero with an error on stderr.

Priority order:

1. **Pin** — if `WB_PIN` is non-empty:
   - If `$WB_PIN/project.conf` exists → echo `$(cd "$WB_PIN" && pwd -P)`, return 0.
   - Else → error: `WB_PIN=… is not a workbench (no project.conf)` and return 1. Loud failure — never silently fall through to cwd; an explicit pin that points at a broken path is a user error worth flagging.
2. **CWD walk-up** — starting at `pwd -P`, walk up the directory tree (parent at each step, stop at `/`):
   - If any ancestor contains `project.conf` → echo that ancestor, return 0.
3. **Source-baked default** — if `$_WB_ROOT_DEFAULT/project.conf` exists (set once at source time from `BASH_SOURCE`) → echo it, return 0. Preserves zero-config behaviour for single-wb users and template-dev sessions where the template's own `aliases.sh` has no `project.conf` next to it (in that case default is skipped).
4. **Error** — exit 1 with:
   ```
   not inside a workbench tree.
     hint: cd into a wb, or run: wb.switch /path/to/wb-<label>
   ```

The resolved path is captured per call into a function-local `WB_ROOT` and exported into the environment so:
- Wrapped scripts under `$WB_ROOT/scripts/` are invoked with the correct path.
- Python helpers that read `WB_ROOT` from env (e.g. `lifecycle.py`, `steering-load.py`) see the resolved value.
- `_wb_check` (version-check preamble) targets the resolved wb, not the source-time default.

## Public API (new aliases)

| Alias | Behaviour |
|-------|-----------|
| `wb.switch <path>` | `<path>` must be a directory containing `project.conf`. Exports `WB_PIN="$(cd <path> && pwd -P)"`. Prints `pinned: <abs-path>`. On failure: `wb.switch: <path> is not a workbench (no project.conf)`. |
| `wb.unswitch` | `unset WB_PIN`. Prints `pin cleared`. |
| `wb.where` | Runs the resolver, prints `<abs-path>  (via pin\|cwd\|default)`. If resolution fails, exits 1 with the same hint as the resolver. Diagnostic command for "which wb am I about to act on?" |

`wb.info` extended: prints the resolution source line (`Resolved via: pin|cwd|default`) under the existing `Workbench:` line.

## Internal shape (`aliases.sh` diff sketch)

```sh
# Captured at source time, used only as last-resort fallback.
_WB_ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

_wb_resolve_root() {
  # Pin
  if [[ -n "${WB_PIN:-}" ]]; then
    if [[ -f "$WB_PIN/project.conf" ]]; then
      ( cd "$WB_PIN" && pwd -P )
      _WB_RESOLVED_VIA=pin
      return 0
    fi
    echo "WB_PIN=$WB_PIN is not a workbench (no project.conf)" >&2
    return 1
  fi
  # CWD walk-up
  local dir; dir="$(pwd -P)"
  while [[ "$dir" != "/" && -n "$dir" ]]; do
    if [[ -f "$dir/project.conf" ]]; then
      echo "$dir"
      _WB_RESOLVED_VIA=cwd
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  # Source-baked default
  if [[ -f "$_WB_ROOT_DEFAULT/project.conf" ]]; then
    echo "$_WB_ROOT_DEFAULT"
    _WB_RESOLVED_VIA=default
    return 0
  fi
  cat >&2 <<'EOM'
wb: not inside a workbench tree.
  hint: cd into a wb, or run: wb.switch /path/to/wb-<label>
EOM
  return 1
}
```

Each wrapper becomes:

```sh
wb.sync-context() {
  local WB_ROOT; WB_ROOT="$(_wb_resolve_root)" || return 1
  export WB_ROOT
  _wb_check
  "$WB_ROOT/scripts/sync-context.sh" "$@"
}
```

Same shape for `wb.ralph-enable-check`, `wb.ralph-plan`, `wb.ralph-dispatch`, `wb.register-repo`, `wb.publish`, `wb.approve`, `wb.reject`, `wb.published`, `wb.approved`, `wb.rejected`, `wb.steering*`, `wb.pull`, `wb.status`, `wb.log`, `wb.info`.

## Edge cases

| Case | Behaviour |
|------|-----------|
| Symlinked path inside a wb (`cd /tmp/symlink-to-wb-gitlore`) | `pwd -P` canonicalises; walk-up sees the real ancestor. |
| Nested workbenches (wb-A's `repos/` contains wb-B by accident) | Innermost wins. Walk-up returns first ancestor with `project.conf`. Documented in `CLAUDE.md`. |
| `WB_PIN` set to relative path | Validated via `cd "$WB_PIN" && pwd -P`; if `cd` fails the validation fails loudly. |
| `WB_PIN` valid but `project.conf` deleted later | Each call re-validates; first call after deletion errors. No stale resolution. |
| `pwd` is `/` (impossible in practice but bounded) | Loop terminates, falls through to default or error. |
| Sourcing `aliases.sh` from template-dev clone (no `project.conf` next to it) | `_WB_ROOT_DEFAULT` exists but step 3 is skipped (no `project.conf`); error message points user to `wb.switch` or `cd`. |
| User exports `WB_ROOT` manually pre-source (old back-door) | Ignored. The function-local `WB_ROOT` shadows it. Test harness `test-aliases-preamble.sh` is updated to use `WB_PIN` instead. |

## Tests

### Resolver unit tests — new `tests/test-wb-resolve-root.sh`

Source `aliases.sh` once, then run subshells exercising:

1. `WB_PIN` valid → resolves to pin path, `_WB_RESOLVED_VIA=pin`.
2. `WB_PIN` invalid → resolver errors loudly, exit 1.
3. No pin, `cd` into fake wb root → resolves via cwd.
4. No pin, `cd` into nested subdir of fake wb → walks up, resolves.
5. No pin, `cd` into nested wb-inside-wb → innermost wins.
6. No pin, `cd` outside any wb, default valid → resolves via default.
7. No pin, `cd` outside any wb, default invalid (template-dev case) → exit 1 with hint.
8. Symlinked path → resolves to canonical wb root via `pwd -P`.
9. `wb.switch <good-path>` exports `WB_PIN`, `wb.where` reports `pin`.
10. `wb.switch <bad-path>` exits 1, leaves `WB_PIN` unset.
11. `wb.unswitch` clears `WB_PIN`.

### Update `test-aliases-preamble.sh`

Replace the `WB_ROOT=…` overrides with `WB_PIN=…`. Functionally equivalent for the test's purpose (validating that the version-check preamble fires and the target script runs). Documented in the file header.

### `tests/smoke.sh`

No new asserts required — the stamped-wb flow inherently runs from the stamped tree, so cwd-walk-up resolves correctly. Existing 35/35 must remain green.

## Documentation updates

| File | Change |
|------|--------|
| `CLAUDE.md` | New "Multi-workbench resolution" subsection under "Key commands"; document `wb.switch` / `wb.unswitch` / `wb.where`, mention `WB_PIN`, nested-wb rule. |
| `README.md` | Add to wb commands list; brief explanation of the resolution priority. |
| `CHANGELOG.md` | `### Multi-workbench resolution (2026-05-13)` entry under unreleased. |
| `SESSION-HANDOFF.md` | "What shipped" entry mentioning the resolver + new aliases + test additions. |
| `version.json` | release-please will bump on merge from the Conventional Commit. Do not edit manually. |

## Migration

`aliases.sh` is `template_owned` in `.workbench-manifest.json`. Stamped wbs receive the new resolver on next `wb.upgrade` (formerly `update.wb`). No data migration required — existing single-wb users keep working because step 3 (source-baked default) still resolves to their wb when cwd is outside any wb tree, and step 2 (cwd walk-up) wins inside the wb. The only behaviour change for back-compat is the `WB_ROOT` env-var override no longer being honoured; the test harness is the only known consumer.

## Risk + rollback

- **Risk:** function-local `WB_ROOT` shadows callers who relied on `export WB_ROOT=…` pre-source. Search of internal use shows only the test harness; updated in this change.
- **Risk:** walk-up performance on deep paths. Bounded by FS depth (typical <20 levels). One `[[ -f ]]` per level. Negligible.
- **Rollback:** revert the PR. Source-time `WB_ROOT="$(…)"` line returns. No state lives in `.workbench-state/` from this change, so rollback is clean.

## Out of scope (parked)

- Bash → zsh portability of `aliases.sh`. The user's portability memory says shared layer must stay bash- and Windows-shell-portable. Resolver uses only POSIX-ish builtins (`pwd -P`, `[[ -f ]]`, `cd`); fine under bash and git-bash.
- Auto-registration of stamped wbs on `init.wb`. Reconsider if registry is added.
- A `wb.list` command that scans `$HOME/Projects/**/wb-*/project.conf`. Cheap to add later, not needed for the bug fix.
