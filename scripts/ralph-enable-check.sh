#!/usr/bin/env bash
# ralph-enable-check.sh — Preflight that ralph workspace mode is enabled.
#
# Called at the top of wb.ralph-plan and wb.ralph-dispatch. Fails with an
# actionable message when $WB_ROOT/repos/.ralph/ is missing or not a workspace.
#
# Workspace bootstrap is a one-time step handled by init.wb / join.wb in the
# ai-devkit companion. If the user cloned the workbench manually, they can run
# the fallback command this script prints.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPOS_ROOT="$WB_ROOT/repos"

if [[ ! -d "$REPOS_ROOT" ]]; then
  cat >&2 <<EOF
ralph-enable-check: no repos/ directory at $REPOS_ROOT.

Register at least one code repo before running ralph:
  wb.register-repo <name> <git-url> <service|automation-tests|shared-lib|infra>
EOF
  exit 1
fi

if [[ ! -d "$REPOS_ROOT/.ralph" ]]; then
  cat >&2 <<EOF
ralph-enable-check: workspace not enabled for ralph.

Bootstrap is normally done by \`init.wb\` / \`join.wb\` in the ai-devkit. If you
bootstrapped this workbench manually, run:

  (cd "$REPOS_ROOT" && ralph enable --workspace)

Then re-run your wb.ralph-* command.
EOF
  exit 1
fi

if [[ -f "$REPOS_ROOT/.ralphrc" ]]; then
  if ! grep -q '^WORKSPACE_MODE=true' "$REPOS_ROOT/.ralphrc"; then
    cat >&2 <<EOF
ralph-enable-check: $REPOS_ROOT/.ralphrc is missing WORKSPACE_MODE=true.

This usually means ralph was enabled in single-repo mode. Re-enable with:

  (cd "$REPOS_ROOT" && ralph enable --workspace)
EOF
    exit 1
  fi
fi

if ! command -v ralph >/dev/null 2>&1; then
  cat >&2 <<EOF
ralph-enable-check: \`ralph\` is not on PATH.

Install from https://github.com/Invenco-Cloud-Systems-ICS/ai-ralph or run:

  ~/Projects/Tools-Utilities/ai-ralph/install.sh
EOF
  exit 1
fi

# Stale-stub guard: a stamped wb (project.conf present) must NEVER have a
# .ralph/ directory at the workbench root. The real workspace lives at
# $REPOS_ROOT/.ralph/ which we already validated above. A root .ralph/ pollutes
# ai-ralph's is_ralph_enabled check from any tool invoked at the wb root (e.g.
# bare rpd.p / ralph-devin), making them report "partial" / "not enabled".
#
# Two flavours:
#   (a) Benign stub: only the empty docs/ , docs/generated/ , logs/ scaffold
#       that older ai-ralph engines created at startup before bailing (fixed
#       upstream by the loop scaffold guard). No ralph state, nothing to lose,
#       so we auto-heal it and continue rather than blocking the user.
#   (b) Real state: a .ralphrc, fix_plan, PROMPT, session, status, etc. means
#       ralph was genuinely (mis)enabled at the wb root. We still hard-stop and
#       let the human heal it, since deleting real state would be destructive.
if [[ -f "$WB_ROOT/project.conf" && -d "$WB_ROOT/.ralph" ]]; then
  root_ralph="$WB_ROOT/.ralph"
  # Any regular file or symlink anywhere under .ralph counts as ralph state.
  # An empty (dirs-only) tree is the benign scaffold.
  ralph_state="$(find "$root_ralph" -mindepth 1 \( -type f -o -type l \) 2>/dev/null)"
  if [[ -z "$ralph_state" ]]; then
    rm -rf "$root_ralph"
    echo "ralph-enable-check: removed benign empty .ralph/ stub at $WB_ROOT (no ralph state; auto-healed)." >&2
  else
    cat >&2 <<EOF
ralph-enable-check: .ralph/ with ralph state found at $WB_ROOT (workbench root).

A stamped workbench must never have a .ralph/ at its root; the real workspace
lives at $REPOS_ROOT/.ralph/ (already validated). This root .ralph/ holds
actual ralph state (a .ralphrc, fix_plan, PROMPT, session, etc.), so ralph was
enabled directly at the workbench root by mistake. It confuses ai-ralph's
is_ralph_enabled check when any tool is invoked from the workbench root.

Heal: run \`wb.upgrade\` (ai-devkit), which backs up the stub to
.ralph.purged.<timestamp>/ and removes the source. Manual equivalent:

  mv "$WB_ROOT/.ralph" "$WB_ROOT/.ralph.purged.\$(date +%s)"
EOF
    exit 1
  fi
fi

exit 0
