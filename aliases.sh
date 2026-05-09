#!/usr/bin/env bash
# ai-workbench CLI aliases
# Source from a workbench instance:
#   source /path/to/wb-<label>/aliases.sh

WB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

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

# ── Context sync ──────────────────────────────────────────────────────────────
wb.sync-context() { _wb_check; "$WB_ROOT/scripts/sync-context.sh" "$@"; }

# ── Ralph ─────────────────────────────────────────────────────────────────────
# Workbench wraps ai-ralph; ralph owns the core loop + parallelism + PR creation.
# Single-repo debugging is a one-liner:
#   (cd "$WB_ROOT/repos/<name>" && ralph --live --monitor)
#
#   wb.ralph-enable-check           # preflight that `ralph enable --workspace` ran
#   wb.ralph-plan [flags]           # sync context + ralph-plan (workspace by default)
#   wb.ralph-dispatch [flags]       # cd repos/ && ralph --workspace --parallel N
#   wb.ralph-dispatch --status      # show open ralph PRs + tail of worker logs
wb.ralph-enable-check() { _wb_check; "$WB_ROOT/scripts/ralph-enable-check.sh" "$@"; }
wb.ralph-plan()         { _wb_check; "$WB_ROOT/scripts/ralph-plan.sh" "$@"; }
wb.ralph-dispatch()     { _wb_check; "$WB_ROOT/scripts/ralph-dispatch.sh" "$@"; }

# ── Repo management ───────────────────────────────────────────────────────────
wb.register-repo()  { _wb_check; "$WB_ROOT/scripts/register-repo.sh" "$@"; }

# ── Artifact lifecycle ────────────────────────────────────────────────────────
# All transitions go through scripts/lifecycle.py, which:
#   - Takes an advisory flock on .workbench-state/.lock (concurrency safe).
#   - Updates YAML frontmatter (.md etc.) OR Gherkin '# status:' header (.feature).
#   - Updates the corresponding .workbench-state/*.json ledger.
#
# Three states: draft -> published -> approved. Only these aliases (and the
# underlying CLI) should ever touch the state files.

wb.publish()  { _wb_check; WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" publish "$@"; }
wb.approve()  { _wb_check; WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" approve "$@"; }
wb.reject()   { _wb_check; WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" reject  "$@"; }
wb.published(){ WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" list published; }
wb.approved() { WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" list approved; }
wb.rejected() { WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" list rejected; }

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
wb.steering()         { _wb_check; WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/steering-load.py" "$@"; }
wb.steering-refresh() { _wb_check; WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/steering-load.py" all; }
wb.steering-lint()    { _wb_check; WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/steering-lint.py" "$@"; }
wb.steering-audit()   { _wb_check; WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/steering-audit.py" "$@"; }

# ── Git helpers ───────────────────────────────────────────────────────────────
wb.pull()   { (cd "$WB_ROOT" && git pull --rebase); }
wb.status() { (cd "$WB_ROOT" && git status --short); }
wb.log()    { (cd "$WB_ROOT" && git log --oneline -20); }

# ── Info ──────────────────────────────────────────────────────────────────────
wb.info() {
  echo "Workbench: $WB_ROOT"
  [[ -f "$WB_ROOT/project.conf" ]] && source "$WB_ROOT/project.conf" && {
    echo "  Label:    ${WORKBENCH_LABEL:-?}"
    echo "  Repo:     ${WORKBENCH_REPO:-?}"
    echo "  Epics:    ${EPICS[*]:-?}"
    echo "  Repos:    ${#REPOS[@]} registered"
  }
}
