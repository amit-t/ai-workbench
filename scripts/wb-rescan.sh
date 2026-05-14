#!/usr/bin/env bash
# wb-rescan.sh — Build/refresh wb context for registered repos via repo-context-scan.
#
# Workbench wraps; ai-devkit owns the core. This script only:
#   1. Resolves wb root (walks up from $PWD for project.conf).
#   2. Locates the ai-devkit clone via $DEVKIT_CLONE.
#   3. Parses target list + flags.
#   4. For each target: setup → fire agent subprocess → finalize.
#   5. After all targets: aggregate.
#   6. Self-commits any changes under context/.
#
# The heavy lifting (worktree staging, defensive merge, manifest stamping,
# aggregate README) lives in $DEVKIT_CLONE/lib/wb-context-scan.zsh.
#
# Usage:
#   ./scripts/wb-rescan.sh <repo>            # rescan one repo
#   ./scripts/wb-rescan.sh --all             # rescan every REPOS entry
#   ./scripts/wb-rescan.sh --aggregate-only  # regenerate context/README.md only
#   ./scripts/wb-rescan.sh --force <repo>    # wipe user prose, full re-scan
#   ./scripts/wb-rescan.sh --agent <devin|claude> <repo>  # override engine
#   ./scripts/wb-rescan.sh -h | --help
#
# Flags combine: `wb.rescan --all --force --agent claude` is valid.
#
# Engine resolution (first match wins):
#   1. --agent X
#   2. $DEVKIT_DEFAULT_ENGINE
#   3. devin if on PATH, else claude
# Special: if $WB_SCAN_AGENT_CMD is set, engine resolution is skipped and the
# command is evaluated verbatim per repo (test hook — Phase 7 integration test).

set -euo pipefail

SCRIPT_PATH="$0"

_usage() {
  sed -n '2,28p' "$SCRIPT_PATH"
}

# Early -h/--help: print usage and exit before wb-root resolution so users
# can discover the command from anywhere.
for _arg in "$@"; do
  case "$_arg" in
    -h|--help) _usage; exit 0 ;;
  esac
done

# ── Resolve wb root by walking up for project.conf ──────────────────────────
_resolve_wb_root() {
  local dir
  dir="$(pwd -P 2>/dev/null || pwd)"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/project.conf" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

WB_ROOT="${WB_ROOT:-}"
if [[ -z "$WB_ROOT" ]]; then
  WB_ROOT="$(_resolve_wb_root || true)"
fi
if [[ -z "$WB_ROOT" || ! -f "$WB_ROOT/project.conf" ]]; then
  cat >&2 <<'EOM'
wb.rescan: not inside a workbench tree.
  hint: cd into a wb, or run: wb.switch /path/to/wb-<label>
EOM
  exit 1
fi

# ── Parse flags ─────────────────────────────────────────────────────────────
ALL=false
AGGREGATE_ONLY=false
FORCE=false
AGENT_OVERRIDE=""
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)            ALL=true; shift ;;
    --aggregate-only) AGGREGATE_ONLY=true; shift ;;
    --force)          FORCE=true; shift ;;
    --agent)
      AGENT_OVERRIDE="${2:-}"
      [[ -z "$AGENT_OVERRIDE" ]] && { echo "wb.rescan: --agent requires an argument (devin|claude)" >&2; exit 2; }
      case "$AGENT_OVERRIDE" in
        devin|claude) ;;
        *) echo "wb.rescan: invalid engine '$AGENT_OVERRIDE' (expected: devin|claude)" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    -h|--help)        _usage; exit 0 ;;
    -*)               echo "wb.rescan: unknown flag: $1" >&2; exit 2 ;;
    *)                TARGETS+=("$1"); shift ;;
  esac
done

# ── Resolve ai-devkit clone + wrapper lib ───────────────────────────────────
if [[ -z "${DEVKIT_CLONE:-}" || ! -d "${DEVKIT_CLONE}" ]]; then
  cat >&2 <<'EOM'
wb.rescan: DEVKIT_CLONE not set or invalid.
Install ai-devkit:
  git clone git@github.com:amit-t/ai-devkit.git ~/Projects/Tools-Utilities/ai-devkit
  cd ~/Projects/Tools-Utilities/ai-devkit
  zsh install.zsh
EOM
  exit 1
fi

LIB="${DEVKIT_CLONE}/lib/wb-context-scan.zsh"
if [[ ! -f "$LIB" ]]; then
  cat >&2 <<EOM
wb.rescan: missing wrapper lib at $LIB.
Update ai-devkit:
  (cd "${DEVKIT_CLONE}" && git pull && zsh install.zsh)
EOM
  exit 1
fi

# ── Engine resolution ───────────────────────────────────────────────────────
# WB_SCAN_AGENT_CMD short-circuits everything — tests set this to mock the
# agent invocation. eval'd in a subshell with cwd=SCAN_DIR; documented as a
# test hook only.
ENGINE=""
if [[ -z "${WB_SCAN_AGENT_CMD:-}" ]]; then
  if [[ -n "$AGENT_OVERRIDE" ]]; then
    ENGINE="$AGENT_OVERRIDE"
  elif [[ -n "${DEVKIT_DEFAULT_ENGINE:-}" ]]; then
    ENGINE="$DEVKIT_DEFAULT_ENGINE"
  elif command -v devin >/dev/null 2>&1; then
    ENGINE="devin"
  else
    ENGINE="claude"
  fi
fi

# ── Build target list from project.conf REPOS ───────────────────────────────
# shellcheck disable=SC1091
source "$WB_ROOT/project.conf"

_all_repo_names() {
  local entry name
  for entry in "${REPOS[@]}"; do
    name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
    [[ -n "$name" ]] && printf '%s\n' "$name"
  done
}

if [[ "$AGGREGATE_ONLY" == "true" ]]; then
  # No targets needed — go straight to aggregate.
  TARGETS=()
elif [[ "$ALL" == "true" ]]; then
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "wb.rescan: --all given with explicit repo arg(s); honoring --all (ignoring positional)." >&2
  fi
  TARGETS=()
  while IFS= read -r n; do TARGETS+=("$n"); done < <(_all_repo_names)
fi

if [[ "$AGGREGATE_ONLY" != "true" && ${#TARGETS[@]} -eq 0 ]]; then
  echo "wb.rescan: no target repo(s). Pass a <repo> arg or --all (or --aggregate-only)." >&2
  _usage >&2
  exit 2
fi

# ── Per-repo scan ───────────────────────────────────────────────────────────
FAILED_REPOS=()
OK_REPOS=()

_run_agent() {
  # $1 = SCAN_DIR
  # Returns 0 if agent succeeded, nonzero otherwise. On failure, prints the
  # last 200 chars of stderr to stdout for the caller to capture.
  local scan_dir="$1"
  local stderr_log
  stderr_log="$(mktemp -t wb-rescan-stderr.XXXXXX)"

  local rc=0
  if [[ -n "${WB_SCAN_AGENT_CMD:-}" ]]; then
    # Test path: eval the command verbatim inside the scan dir.
    # eval is intentional — tests need to inject shell snippets (e.g.
    # `touch CONTEXT.md && echo done`). Not reachable in production paths.
    ( cd "$scan_dir" && eval "$WB_SCAN_AGENT_CMD" ) 2>"$stderr_log" || rc=$?
  else
    local prompt
    prompt="Invoke /repo-context-scan in this directory. Return one paragraph summarizing term count + ADR count + any blockers. Do NOT modify files outside this cwd. Do NOT make commits."
    # Non-interactive (-p) mode defaults to read-only permissions for both
    # engines. Without an explicit permission flag the agent cannot write the
    # CONTEXT.md / docs/adr/* files that repo-context-scan produces, so every
    # real-LLM scan would land as `status: scan-failed` with reason "Write was
    # blocked by the session's non-interactive permission mode". Pass the
    # widest-allow flag each engine offers; safety is bounded by the worktree
    # because finalize harvests only specific paths and removes scan_dir
    # afterwards.
    case "$ENGINE" in
      claude)
        if ! command -v claude >/dev/null 2>&1; then
          echo "wb.rescan: \`claude\` not on PATH. Install claude-code or pass --agent devin." >&2
          rc=127
        else
          ( cd "$scan_dir" && claude --permission-mode acceptEdits -p "$prompt" ) 2>"$stderr_log" || rc=$?
        fi
        ;;
      devin)
        if ! command -v devin >/dev/null 2>&1; then
          echo "wb.rescan: \`devin\` not on PATH. Install devin CLI or pass --agent claude." >&2
          rc=127
        else
          # devin's flag parser requires --permission-mode to precede -p,
          # otherwise the prompt is consumed as the flag's value and the
          # CLI errors out with "Usage: devin [OPTIONS] [-- <PROMPT>...]".
          ( cd "$scan_dir" && devin --permission-mode dangerous -p "$prompt" ) 2>"$stderr_log" || rc=$?
        fi
        ;;
      *)
        echo "wb.rescan: unsupported engine '$ENGINE'" >&2
        rc=2
        ;;
    esac
  fi

  if [[ $rc -ne 0 ]]; then
    # Tail of stderr → caller. Trim to last 200 chars to keep finalize args sane.
    local tail
    tail="$(tail -c 200 "$stderr_log" 2>/dev/null || true)"
    rm -f "$stderr_log"
    printf '%s' "$tail"
    return $rc
  fi
  rm -f "$stderr_log"
  return 0
}

if [[ "$AGGREGATE_ONLY" != "true" ]]; then
  echo "[wb.rescan] wb_root=$WB_ROOT engine=${WB_SCAN_AGENT_CMD:+test-mock}${ENGINE:-} targets=${TARGETS[*]}"
  for repo in "${TARGETS[@]}"; do
    echo "── $repo ──"

    # setup → SCAN_DIR
    # The lib emits a single line `SCAN_DIR=<abs-path>` on stdout. Capture
    # it, then strip the `SCAN_DIR=` prefix so downstream code holds a real
    # filesystem path. Without the strip, `-d "$SCAN_DIR"` would always be
    # false and every run would skip with "setup returned invalid SCAN_DIR".
    SETUP_OUT=""
    if ! SETUP_OUT="$(zsh "$LIB" setup "$WB_ROOT" "$repo")"; then
      echo "  setup failed for $repo — skipping" >&2
      FAILED_REPOS+=("$repo")
      continue
    fi
    if [[ "$SETUP_OUT" != SCAN_DIR=* ]]; then
      echo "  setup did not emit SCAN_DIR= line for $repo — skipping" >&2
      echo "  setup stdout: $SETUP_OUT" >&2
      FAILED_REPOS+=("$repo")
      continue
    fi
    SCAN_DIR="${SETUP_OUT#SCAN_DIR=}"
    if [[ -z "$SCAN_DIR" || ! -d "$SCAN_DIR" ]]; then
      echo "  setup returned invalid SCAN_DIR for $repo — skipping" >&2
      FAILED_REPOS+=("$repo")
      continue
    fi
    echo "  setup → $SCAN_DIR"

    # --force: pre-wipe existing CONTEXT prose so the skill regenerates fresh.
    # Defensive merge in finalize still preserves user-authored YAML keys.
    if [[ "$FORCE" == "true" ]]; then
      rm -f "$WB_ROOT/context/$repo/CONTEXT.md" \
            "$WB_ROOT/context/$repo/CONTEXT-MAP.md" 2>/dev/null || true
      echo "  --force: wiped context/$repo/CONTEXT*.md"
    fi

    # Fire the agent.
    FAIL_REASON=""
    if ! FAIL_REASON="$(_run_agent "$SCAN_DIR")"; then
      echo "  agent failed for $repo: ${FAIL_REASON:-<no stderr captured>}" >&2
    fi

    # finalize (always — picks up partial output, writes stub on empty).
    if [[ -n "$FAIL_REASON" ]]; then
      zsh "$LIB" finalize "$WB_ROOT" "$repo" --fail-reason "$FAIL_REASON" \
        || { echo "  finalize failed for $repo" >&2; FAILED_REPOS+=("$repo"); continue; }
    else
      zsh "$LIB" finalize "$WB_ROOT" "$repo" \
        || { echo "  finalize failed for $repo" >&2; FAILED_REPOS+=("$repo"); continue; }
    fi

    OK_REPOS+=("$repo")
  done
fi

# ── Aggregate ───────────────────────────────────────────────────────────────
echo "── aggregate ──"
if ! zsh "$LIB" aggregate "$WB_ROOT"; then
  echo "wb.rescan: aggregate failed" >&2
  exit 1
fi

# ── Self-commit ─────────────────────────────────────────────────────────────
COMMIT_MADE=false
if [[ -d "$WB_ROOT/.git" ]]; then
  if (cd "$WB_ROOT" && git diff --quiet -- context/ && git diff --cached --quiet -- context/ && [[ -z "$(git status --porcelain -- context/)" ]]); then
    echo "[wb.rescan] no changes under context/ — skipping commit"
  else
    if [[ "$AGGREGATE_ONLY" == "true" ]]; then
      commit_subject="chore: rescan context (aggregate-only)"
    elif [[ ${#OK_REPOS[@]} -gt 0 ]]; then
      commit_subject="chore: rescan context for ${OK_REPOS[*]}"
    else
      commit_subject="chore: rescan context (no successful repos — stubs only)"
    fi
    ( cd "$WB_ROOT" && git add context/ && git commit -m "$commit_subject" ) \
      && COMMIT_MADE=true \
      || echo "wb.rescan: git commit failed (continuing)" >&2
  fi
else
  echo "[wb.rescan] $WB_ROOT is not a git repo — skipping commit"
fi

# ── Summary banner ──────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " wb.rescan summary"
echo "═══════════════════════════════════════════════════════════════"
if [[ ${#OK_REPOS[@]} -gt 0 ]]; then
  echo "  OK:     ${OK_REPOS[*]}"
fi
if [[ ${#FAILED_REPOS[@]} -gt 0 ]]; then
  echo "  FAILED: ${FAILED_REPOS[*]}  (stubs written; re-run after fixing)"
fi
if [[ "$COMMIT_MADE" == "true" ]]; then
  echo ""
  echo "  Committed changes under context/. Review then push:"
  echo "    (cd $WB_ROOT && git diff HEAD~ && git push)"
fi
echo "═══════════════════════════════════════════════════════════════"

# Exit nonzero only if every requested repo failed.
if [[ "$AGGREGATE_ONLY" != "true" && ${#OK_REPOS[@]} -eq 0 && ${#FAILED_REPOS[@]} -gt 0 ]]; then
  exit 1
fi
exit 0
