#!/usr/bin/env bash
# ai-workbench CLI aliases
#
# Source once per shell, from any workbench:
#   source /path/to/wb-<label>/aliases.sh
#
# Every wb.* command resolves the target workbench per call, in this priority:
#   1. WB_PIN env var (set via `wb.switch <path>`, cleared via `wb.unswitch`)
#   2. Walking up from $PWD until a `project.conf` is found
#   3. The wb whose aliases.sh was sourced (single-wb back-compat)
# If none resolve, the command errors with a hint.

# Source-baked default — last-resort fallback for users who source from a
# workbench and then `cd` outside its tree. Never referenced directly outside
# of `_wb_resolve_root`.
_WB_ROOT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# ── Multi-workbench resolution ───────────────────────────────────────────────
# Resolves the active workbench root for the current call. Sets two globals
# in the caller's scope (variables cannot escape command substitution, so we
# avoid `$(...)` here):
#   __WB_ROOT_OUT       absolute path to the resolved wb root
#   _WB_RESOLVED_VIA    one of: pin | cwd | default
# Returns 0 on success; on failure prints a hint to stderr and returns 1.
_wb_resolve_root() {
  __WB_ROOT_OUT=""
  _WB_RESOLVED_VIA=""
  # 1. Explicit pin (loud failure if invalid — never silently fall through).
  if [[ -n "${WB_PIN:-}" ]]; then
    if [[ -f "$WB_PIN/project.conf" ]]; then
      __WB_ROOT_OUT="$(cd "$WB_PIN" && pwd -P)"
      _WB_RESOLVED_VIA=pin
      return 0
    fi
    echo "wb: WB_PIN=$WB_PIN is not a workbench (no project.conf)" >&2
    return 1
  fi
  # 2. Walk up from $PWD (canonicalised) looking for project.conf.
  local dir
  dir="$(pwd -P 2>/dev/null || pwd)"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/project.conf" ]]; then
      __WB_ROOT_OUT="$dir"
      _WB_RESOLVED_VIA=cwd
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  # 3. Source-baked default (works for single-wb users; skipped in template-dev
  #    clones where no project.conf sits next to aliases.sh).
  if [[ -f "$_WB_ROOT_DEFAULT/project.conf" ]]; then
    __WB_ROOT_OUT="$_WB_ROOT_DEFAULT"
    _WB_RESOLVED_VIA=default
    return 0
  fi
  cat >&2 <<'EOM'
wb: not inside a workbench tree.
  hint: cd into a wb, or run: wb.switch /path/to/wb-<label>
EOM
  return 1
}

# ── Versioning preamble helper ──────────────────────────────────────────────
# Sourced from aliases.sh by every meaningful wb.* function. Sources the
# canonical version-check lib (dropped by ai-devkit / ai-ralph installers).
# If the lib is missing, this is a silent no-op (graceful degradation for users
# who have not yet pulled the new ai-devkit installer).
_wb_check() {
  local libvc="${HOME}/.local/share/wb-versioncheck/version-check.sh"
  [[ -f "$libvc" ]] || return 0
  # shellcheck disable=SC1090
  . "$libvc"
  WB_TEMPLATE_VERSION_FILE="${WB_ROOT}/.workbench-state/template-version.json" \
    _wb_versioncheck wb || true
}

# ── Pin management ───────────────────────────────────────────────────────────
#   wb.switch <path>     Pin the active wb for this shell.
#   wb.unswitch          Clear the pin.
#   wb.where             Print resolved wb + how it was resolved.
wb.switch() {
  local arg="${1:-}"
  if [[ -z "$arg" ]]; then
    echo "usage: wb.switch <path-to-wb-root>" >&2
    return 2
  fi
  if [[ ! -d "$arg" ]]; then
    echo "wb.switch: $arg is not a directory" >&2
    return 1
  fi
  if [[ ! -f "$arg/project.conf" ]]; then
    echo "wb.switch: $arg is not a workbench (no project.conf)" >&2
    return 1
  fi
  WB_PIN="$(cd "$arg" && pwd -P)"
  export WB_PIN
  echo "pinned: $WB_PIN"
}

wb.unswitch() {
  unset WB_PIN
  echo "pin cleared"
}

wb.where() {
  _wb_resolve_root || return 1
  echo "$__WB_ROOT_OUT  (via ${_WB_RESOLVED_VIA})"
}

# ── Context sync ──────────────────────────────────────────────────────────────
wb.sync-context() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  "$WB_ROOT/scripts/sync-context.sh" "$@"
}

# ── Ralph ─────────────────────────────────────────────────────────────────────
# Workbench wraps ai-ralph; ralph owns the core loop + parallelism + PR creation.
# Single-repo debugging is a one-liner:
#   (cd "$WB_ROOT/repos/<name>" && ralph --live --monitor)
#
#   wb.ralph-enable-check           # preflight that `ralph enable --workspace` ran
#   wb.ralph-plan [flags]           # sync context + ralph-plan (workspace by default)
#   wb.ralph-dispatch [flags]       # cd repos/ && ralph --workspace --parallel N
#   wb.ralph-dispatch --status      # show open ralph PRs + tail of worker logs
#   wrd.p N M                       # shorthand: dispatch devin engine, N workers, M attempts
#
# Continuous mode (opt-in; ralph keeps N workers saturated until M attempts):
#   wb.ralph-dispatch --parallel 3 --max-tasks 30        # named M
#   wb.ralph-dispatch --parallel 3 30                    # positional M (ralph's shape)
#   wb.ralph-dispatch --parallel 3 30 --no-tabs          # force single-pane
#   wb.ralph-dispatch --parallel 3 30 --max-task-attempts 2 --respawn-delay 5
# Without M (--max-tasks / WB_RALPH_MAX_TASKS / project.conf), dispatch runs
# in V1 batch mode (byte-identical to prior behavior). Capability-gated: the
# wrapper fails fast if the installed ralph predates continuous mode.
#
# Execution engine resolution (independent of plan engine):
#   CLI --engine > WB_RALPH_ENGINE > RALPH_EXECUTION_ENGINE > RALPH_PLAN_ENGINE > devin
#   Engine -> binary: claude -> ralph, devin -> ralph-devin, codex -> ralph-codex
wb.ralph-enable-check() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  "$WB_ROOT/scripts/ralph-enable-check.sh" "$@"
}
wb.ralph-plan() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  "$WB_ROOT/scripts/ralph-plan.sh" "$@"
}
wb.ralph-dispatch() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  "$WB_ROOT/scripts/ralph-dispatch.sh" "$@"
}

# ── Ralph shorthand: workbench-ralph-devin parallel ──────────────────────────
# wrd.p N M — mirrors `rpd.p N M` (ralph-devin --parallel N M, continuous mode).
# Expands to: wb.ralph-dispatch --engine devin --parallel N --max-tasks M
# Both args required and must be positive integers; capability-gated by
# wb.ralph-dispatch (fails fast if installed ralph predates continuous mode).
wrd.p() {
  if [[ $# -ne 2 ]]; then
    echo "usage: wrd.p <parallel> <max-tasks>" >&2
    echo "  shorthand for: wb.ralph-dispatch --engine devin --parallel N --max-tasks M" >&2
    return 2
  fi
  local n="$1" m="$2"
  if ! [[ "$n" =~ ^[1-9][0-9]*$ ]] || ! [[ "$m" =~ ^[1-9][0-9]*$ ]]; then
    echo "wrd.p: both args must be positive integers (got '$n' '$m')" >&2
    return 2
  fi
  wb.ralph-dispatch --engine devin --parallel "$n" --max-tasks "$m"
}

# ── Repo management ───────────────────────────────────────────────────────────
wb.register-repo() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  "$WB_ROOT/scripts/register-repo.sh" "$@"
}

# ── Context scan (repo-context-scan integration) ─────────────────────────────
# Builds/refreshes context/<repo>/CONTEXT.md (or CONTEXT-MAP.md) and seed ADRs
# for each registered repo by invoking the repo-context-scan skill via an
# agent subprocess. Reads $DEVKIT_CLONE to locate the ai-devkit wrapper lib.
#
#   wb.rescan <repo>            # rescan one repo
#   wb.rescan --all             # rescan every project.conf REPOS entry
#   wb.rescan --aggregate-only  # regenerate context/README.md only
#   wb.rescan --force <repo>    # wipe user-authored prose, full re-scan
#   wb.rescan --agent devin|claude <repo>   # override engine
wb.rescan() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  "$WB_ROOT/scripts/wb-rescan.sh" "$@"
}

# ── Artifact lifecycle ────────────────────────────────────────────────────────
# All transitions go through scripts/lifecycle.py, which:
#   - Takes an advisory flock on .workbench-state/.lock (concurrency safe).
#   - Updates YAML frontmatter (.md etc.) OR Gherkin '# status:' header (.feature).
#   - Updates the corresponding .workbench-state/*.json ledger.
#
# Three states: draft -> published -> approved. Only these aliases (and the
# underlying CLI) should ever touch the state files.

wb.publish() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  python3 "$WB_ROOT/scripts/lifecycle.py" publish "$@"
}
wb.approve() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  python3 "$WB_ROOT/scripts/lifecycle.py" approve "$@"
}
wb.reject() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  python3 "$WB_ROOT/scripts/lifecycle.py" reject "$@"
}
wb.published() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  python3 "$WB_ROOT/scripts/lifecycle.py" list published
}
wb.approved() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  python3 "$WB_ROOT/scripts/lifecycle.py" list approved
}
wb.rejected() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  python3 "$WB_ROOT/scripts/lifecycle.py" list rejected
}

# ── Graphify ──────────────────────────────────────────────────────────────────
# Wraps the graphifyy CLI for registered repos. Detects "non-graphified" repos
# via the per-entry graphified= field in project.conf REPOS; runs `graphify
# <repo>` and flips the flag on success.
#
#   wb.graphify <repo>            # graphify one repo
#   wb.graphify --all             # every non-graphified entry
#   wb.graphify --check           # report-only (mode + per-repo status)
#   wb.graphify --install-skill   # one-time SKILL.md install into .agents/.claude
#   wb.graphify --force <repo>    # rerun even if already flagged
#   wb.graphify --no-install      # skip auto pip install of graphifyy
#
# Mode resolution: CLI (--auto / --manual) > WB_GRAPHIFY_MODE env >
# project.conf GRAPHIFY_MODE > default "auto". `auto` makes register-repo
# fire wb.graphify on every new clone; `manual` prints a recommendation.
wb.graphify() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  "$WB_ROOT/scripts/graphify-repos.sh" "$@"
}

# ── Precision ────────────────────────────────────────────────────────────────
# Resolves PRECISION_MODE for the current workbench and prints the value + source.
# Resolution order: env WB_PRECISION_MODE > project.conf PRECISION_MODE > default "on".
# Read-only; no setter. To change, edit project.conf or `export WB_PRECISION_MODE=off`.
wb.precision() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  local value="" source=""
  if [[ -n "${WB_PRECISION_MODE:-}" ]]; then
    value="$WB_PRECISION_MODE"
    source="env (WB_PRECISION_MODE)"
  else
    local pc_value
    pc_value=$(grep -E '^PRECISION_MODE=' "$WB_ROOT/project.conf" 2>/dev/null \
               | sed -E 's/^PRECISION_MODE="?([^"]*)"?$/\1/' | head -1)
    if [[ -n "$pc_value" ]]; then
      value="$pc_value"
      source="project.conf"
    else
      value="on"
      source="default"
    fi
  fi
  echo "PRECISION_MODE=$value  ($source)"
}

# ── What-to-do (WTD) ─────────────────────────────────────────────────────────
# Single-shot next-action recommender. Reads .workbench-state/, project.conf,
# and artifact frontmatter, walks the per-epic precondition chain, and prints
# the first gap as one concrete command per epic.
#
#   wb.wtd            # text report
#   wb.wtd --json     # machine-readable
wb.wtd() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  python3 "$WB_ROOT/scripts/wtd.py" "$@"
}

# ── Steering ──────────────────────────────────────────────────────────────────
# Loads merged steering rules (template + team overlay) for a scope, or all
# scopes. Agents are expected to invoke this at the invocation points declared
# in steering/config.yaml.
#
#   wb.steering golden            # Layer 0 (always)
#   wb.steering role:qa           # Layer 1 (when in QA mode)
#   wb.steering artifact:prd      # Layer 2 (when a skill produces a PRD)
#   wb.steering topic:api-design  # Layer 2 (on demand)
#   wb.steering-refresh           # reload every scope (use after steering updates)
#   wb.steering-lint              # validate steering/ + steering.local/
#   wb.steering-audit [--json|--list]
#                                 # surface team overrides: kinds, targets,
#                                 # age, last-updated, promote-suggest heuristic
wb.steering() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  python3 "$WB_ROOT/scripts/steering-load.py" "$@"
}
wb.steering-refresh() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  python3 "$WB_ROOT/scripts/steering-load.py" all
}
wb.steering-lint() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  python3 "$WB_ROOT/scripts/steering-lint.py" "$@"
}
wb.steering-audit() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  export WB_ROOT
  _wb_check
  python3 "$WB_ROOT/scripts/steering-audit.py" "$@"
}

# ── Git helpers ───────────────────────────────────────────────────────────────
wb.pull() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  ( cd "$WB_ROOT" && git pull --rebase )
}
wb.status() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  ( cd "$WB_ROOT" && git status --short )
}
wb.log() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  ( cd "$WB_ROOT" && git log --oneline -20 )
}

# ── Info ──────────────────────────────────────────────────────────────────────
wb.info() {
  _wb_resolve_root || return 1
  local WB_ROOT="$__WB_ROOT_OUT"
  echo "Workbench:    $WB_ROOT"
  echo "Resolved via: ${_WB_RESOLVED_VIA}"
  [[ -f "$WB_ROOT/project.conf" ]] && source "$WB_ROOT/project.conf" && {
    echo "  Label:      ${WORKBENCH_LABEL:-?}"
    echo "  Repo:       ${WORKBENCH_REPO:-?}"
    echo "  Epics:      ${EPICS[*]:-?}"
    echo "  Repos:      ${#REPOS[@]} registered"
    # Graphify status: count + names of non-graphified entries.
    local entry _name _flag missing=()
    for entry in "${REPOS[@]:-}"; do
      [[ -z "$entry" ]] && continue
      _name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
      _flag="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^graphified=/) print substr($i,12)}')"
      [[ -z "$_name" ]] && continue
      [[ "$_flag" == "true" ]] || missing+=("$_name")
    done
    if (( ${#missing[@]} > 0 )); then
      echo "  Graphify:   ${#missing[@]} non-graphified — ${missing[*]}"
      echo "              (run: wb.graphify --all)"
    else
      [[ ${#REPOS[@]} -gt 0 ]] && echo "  Graphify:   all repos graphified"
    fi
  }
}
