#!/usr/bin/env bash
# ai-workbench CLI aliases
# Source from a workbench instance:
#   source /path/to/wb-<label>/aliases.sh

WB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# ── Context sync ──────────────────────────────────────────────────────────────
wb.sync-context() { "$WB_ROOT/scripts/sync-context.sh" "$@"; }

# ── Ralph ─────────────────────────────────────────────────────────────────────
wb.ralph-plan()     { "$WB_ROOT/scripts/ralph-plan.sh" "$@"; }
wb.ralph-loop()     { "$WB_ROOT/scripts/ralph-loop.sh" "$@"; }
wb.ralph-dispatch() { "$WB_ROOT/scripts/ralph-dispatch.sh" "$@"; }

# ── Repo management ───────────────────────────────────────────────────────────
wb.register-repo()  { "$WB_ROOT/scripts/register-repo.sh" "$@"; }

# ── Artifact lifecycle ────────────────────────────────────────────────────────
# All transitions go through scripts/lifecycle.py, which:
#   - Takes an advisory flock on .workbench-state/.lock (concurrency safe).
#   - Updates YAML frontmatter (.md etc.) OR Gherkin '# status:' header (.feature).
#   - Updates the corresponding .workbench-state/*.json ledger.
#
# Three states: draft -> published -> approved. Only these aliases (and the
# underlying CLI) should ever touch the state files.

wb.publish()  { WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" publish "$@"; }
wb.approve()  { WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" approve "$@"; }
wb.reject()   { WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" reject  "$@"; }
wb.published(){ WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" list published; }
wb.approved() { WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" list approved; }
wb.rejected() { WB_ROOT="$WB_ROOT" python3 "$WB_ROOT/scripts/lifecycle.py" list rejected; }

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
