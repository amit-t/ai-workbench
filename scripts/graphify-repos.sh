#!/usr/bin/env bash
# graphify-repos.sh — Wrap graphifyy CLI for registered repos.
#
# Detects "non-graphified" repos via the per-entry `graphified=` field in
# project.conf REPOS. Runs `graphify <repo>` per non-graphified repo and
# flips the flag to `true` on success.
#
# This wrapper does NOT re-implement graphify internals. graphify owns:
#   - graph building (`graphify <path>` builds graphify-out/graph.json)
#   - SKILL.md generation (`graphify install` copies SKILL.md to platform dir)
# We own: detection, sequencing, REPOS-flag flip, dual-write SKILL.md into
# the wb's .agents/.claude skill trees so Devin + Claude see /graphify locally.
#
# Usage:
#   ./scripts/graphify-repos.sh <repo>           # graphify one repo
#   ./scripts/graphify-repos.sh --all            # every non-graphified entry
#   ./scripts/graphify-repos.sh --check          # report-only; no install/run
#   ./scripts/graphify-repos.sh --install-skill  # one-time SKILL.md install
#   ./scripts/graphify-repos.sh --force <repo>   # rerun even if flagged true
#   ./scripts/graphify-repos.sh --no-install     # skip auto pip install
#   ./scripts/graphify-repos.sh -h | --help
#
# Mode resolution (CLI > env > project.conf > default "auto"):
#   --auto / --manual            highest priority (CLI override)
#   WB_GRAPHIFY_MODE             env override
#   project.conf GRAPHIFY_MODE   per-wb default
#   default                      "auto"
#
# Test hook:
#   WB_GRAPHIFY_CMD=<shell>      eval'd verbatim inside the repo dir instead
#                                of invoking the graphify CLI. Used by
#                                tests/test-graphify.sh.

set -euo pipefail

SCRIPT_PATH="$0"

_usage() { sed -n '2,33p' "$SCRIPT_PATH"; }

# Early -h/--help before wb-root resolution so users can discover it anywhere.
for _arg in "$@"; do
  case "$_arg" in -h|--help) _usage; exit 0 ;; esac
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
wb.graphify: not inside a workbench tree.
  hint: cd into a wb, or run: wb.switch /path/to/wb-<label>
EOM
  exit 1
fi

# ── Parse flags ─────────────────────────────────────────────────────────────
ALL=false
CHECK=false
INSTALL_SKILL=false
FORCE=false
NO_INSTALL=false
MODE_OVERRIDE=""
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)            ALL=true; shift ;;
    --check)          CHECK=true; shift ;;
    --install-skill)  INSTALL_SKILL=true; shift ;;
    --force)          FORCE=true; shift ;;
    --no-install)     NO_INSTALL=true; shift ;;
    --auto)           MODE_OVERRIDE="auto";   shift ;;
    --manual)         MODE_OVERRIDE="manual"; shift ;;
    -h|--help)        _usage; exit 0 ;;
    -*)               echo "wb.graphify: unknown flag: $1" >&2; exit 2 ;;
    *)                TARGETS+=("$1"); shift ;;
  esac
done

# ── Resolve mode (informational; does not block any operation) ──────────────
_resolve_mode() {
  if [[ -n "$MODE_OVERRIDE" ]]; then
    echo "$MODE_OVERRIDE cli"
    return 0
  fi
  if [[ -n "${WB_GRAPHIFY_MODE:-}" ]]; then
    echo "$WB_GRAPHIFY_MODE env"
    return 0
  fi
  local pc
  pc=$(grep -E '^GRAPHIFY_MODE=' "$WB_ROOT/project.conf" 2>/dev/null \
       | sed -E 's/^GRAPHIFY_MODE="?([^"]*)"?$/\1/' | head -1)
  if [[ -n "$pc" ]]; then
    echo "$pc project.conf"
    return 0
  fi
  echo "auto default"
}

read -r MODE MODE_SOURCE <<<"$(_resolve_mode)"

# ── Parse REPOS from project.conf ───────────────────────────────────────────
# Emits one line per repo: "<name>|<graphified>" where graphified is
# "true" | "false" | "unset" (legacy entries without the field).
_list_repos() {
  # shellcheck disable=SC1091
  source "$WB_ROOT/project.conf"
  local entry name flag
  for entry in "${REPOS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    name="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^name=/) print substr($i,6)}')"
    [[ -z "$name" ]] && continue
    flag="$(echo "$entry" | awk -F';' '{for(i=1;i<=NF;i++) if ($i ~ /^graphified=/) print substr($i,12)}')"
    [[ -z "$flag" ]] && flag="unset"
    printf '%s|%s\n' "$name" "$flag"
  done
}

# Repo dir, by convention.
_repo_dir() { printf '%s\n' "$WB_ROOT/repos/$1"; }

# ── Mutate REPOS entry: set graphified=<value> for <name> ───────────────────
# Uses python for safe regex + atomic rewrite. Locks via flock when available.
_set_graphified() {
  local name="$1" value="$2"
  local lock="$WB_ROOT/.workbench-state/.lock"
  [[ -d "$WB_ROOT/.workbench-state" ]] || mkdir -p "$WB_ROOT/.workbench-state"
  [[ -f "$lock" ]] || : > "$lock"
  _do_set() {
    python3 - "$WB_ROOT/project.conf" "$name" "$value" <<'PYEOF'
import sys, re, os, tempfile
conf, name, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(conf) as f: content = f.read()
m = re.search(r'REPOS=\((.*?)\)', content, re.DOTALL)
if not m:
    sys.stderr.write("graphify-repos: REPOS=( ... ) block not found in project.conf\n")
    sys.exit(1)
inner = m.group(1)
lines = inner.splitlines()
out = []
hit = False
name_re = re.compile(rf'(^|[;"\s])name={re.escape(name)}(;|"|$)')
for ln in lines:
    if name_re.search(ln):
        if 'graphified=' in ln:
            ln = re.sub(r'graphified=(true|false|unset)', f'graphified={value}', ln)
        else:
            ln = re.sub(r'"\s*$', f';graphified={value}"', ln, count=1)
        hit = True
    out.append(ln)
if not hit:
    sys.stderr.write(f"graphify-repos: no REPOS entry named {name}\n")
    sys.exit(1)
new_inner = "\n".join(out)
content = content[:m.start(1)] + new_inner + content[m.end(1):]
tmp_fd, tmp = tempfile.mkstemp(dir=os.path.dirname(conf), prefix=".project.conf.")
with os.fdopen(tmp_fd, 'w') as f: f.write(content)
os.replace(tmp, conf)
PYEOF
  }
  if command -v flock >/dev/null 2>&1; then
    flock "$lock" bash -c "$(declare -f _do_set); _do_set" || return $?
  else
    _do_set || return $?
  fi
}

# ── Run graphify CLI (or test mock) inside <repo_dir> ───────────────────────
_run_graphify_one() {
  local name="$1"
  local repo_dir
  repo_dir="$(_repo_dir "$name")"
  if [[ ! -d "$repo_dir" ]]; then
    echo "  $name: repos/$name/ missing; clone it first (wb.register-repo)." >&2
    return 1
  fi
  if [[ -n "${WB_GRAPHIFY_CMD:-}" ]]; then
    # Test path: eval the command verbatim in the repo dir.
    ( cd "$repo_dir" && eval "$WB_GRAPHIFY_CMD" )
    return $?
  fi
  if ! command -v graphify >/dev/null 2>&1; then
    cat >&2 <<'EOM'
wb.graphify: `graphify` CLI not on PATH.
  install: pip install graphifyy && graphify install
  rerun:   wb.graphify <repo>
EOM
    return 127
  fi
  ( cd "$repo_dir" && graphify . )
}

# ── Ensure graphify CLI present (auto-pip-install unless --no-install) ──────
_ensure_cli() {
  command -v graphify >/dev/null 2>&1 && return 0
  [[ -n "${WB_GRAPHIFY_CMD:-}" ]] && return 0
  if [[ "$NO_INSTALL" == "true" ]]; then
    cat >&2 <<'EOM'
wb.graphify: `graphify` CLI not on PATH and --no-install was passed.
  install: pip install graphifyy && graphify install
EOM
    return 127
  fi
  if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
    cat >&2 <<'EOM'
wb.graphify: pip not on PATH; cannot auto-install graphifyy.
  install: pip install graphifyy && graphify install
EOM
    return 127
  fi
  echo "wb.graphify: installing graphifyy via pip..."
  if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user graphifyy || return $?
  else
    pip install --user graphifyy || return $?
  fi
  command -v graphify >/dev/null 2>&1 || {
    cat >&2 <<'EOM'
wb.graphify: graphifyy installed but `graphify` not on PATH.
  add ~/.local/bin to PATH and re-run.
EOM
    return 127
  }
}

# ── Install SKILL.md into wb-local agent trees ──────────────────────────────
_install_skill() {
  mkdir -p "$WB_ROOT/.agents/skills/graphify" "$WB_ROOT/.claude/skills"
  if [[ -n "${WB_GRAPHIFY_CMD:-}" ]]; then
    # Test path: eval the command at wb root (test mock may write SKILL.md).
    ( cd "$WB_ROOT" && eval "$WB_GRAPHIFY_CMD" )
    return $?
  fi
  if ! command -v graphify >/dev/null 2>&1; then
    cat >&2 <<'EOM'
wb.graphify: `graphify` CLI not on PATH; cannot run `graphify install`.
  install: pip install graphifyy && graphify install
EOM
    return 127
  fi
  # Run global Claude install (writes ~/.claude/skills/graphify/SKILL.md).
  graphify install --platform claude || return $?
  # Copy the produced SKILL.md into wb-local .agents/ so Devin sees it too.
  local src="$HOME/.claude/skills/graphify/SKILL.md"
  if [[ -f "$src" ]]; then
    cp "$src" "$WB_ROOT/.agents/skills/graphify/SKILL.md"
    # Symlink for .claude tree (idempotent).
    if [[ ! -e "$WB_ROOT/.claude/skills/graphify" ]]; then
      ln -s "../../.agents/skills/graphify" "$WB_ROOT/.claude/skills/graphify"
    fi
    echo "wb.graphify: installed SKILL.md -> .agents/skills/graphify/ (+ .claude symlink)"
  else
    echo "wb.graphify: warning — graphify install ran but $src not found" >&2
  fi
}

# ── --check: report-only ────────────────────────────────────────────────────
if [[ "$CHECK" == "true" ]]; then
  echo "GRAPHIFY_MODE=$MODE  ($MODE_SOURCE)"
  echo "Per-repo status:"
  while IFS='|' read -r name flag; do
    case "$flag" in
      true)             status="graphified" ;;
      false|unset)      status="not graphified (missing)" ;;
      *)                status="unknown ($flag)" ;;
    esac
    printf '  %-24s  %s\n' "$name" "$status"
  done < <(_list_repos)
  exit 0
fi

# ── --install-skill ─────────────────────────────────────────────────────────
if [[ "$INSTALL_SKILL" == "true" ]]; then
  _install_skill
  exit $?
fi

# ── Resolve target list ─────────────────────────────────────────────────────
if [[ "$ALL" == "true" ]]; then
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "wb.graphify: --all given with explicit repo arg(s); honoring --all." >&2
  fi
  TARGETS=()
  while IFS='|' read -r name flag; do
    if [[ "$FORCE" == "true" || "$flag" != "true" ]]; then
      TARGETS+=("$name")
    fi
  done < <(_list_repos)
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  if [[ "$ALL" == "true" ]]; then
    echo "wb.graphify: all repos already graphified. Use --force to rerun."
    exit 0
  fi
  echo "wb.graphify: no target repo. Pass <repo> or --all." >&2
  _usage >&2
  exit 2
fi

# Pre-flight: ensure CLI (single time, regardless of target count).
_ensure_cli || exit $?

# ── Per-repo execution ──────────────────────────────────────────────────────
OK=()
SKIPPED=()
FAILED=()

# Bash 3.2 (system bash on macOS) has no `declare -A`, so look up by re-grep
# of the cached _list_repos output. The list is small (rarely > 10 entries).
_REPO_FLAGS_CACHE="$(_list_repos)"
_lookup_flag() {
  local q="$1" line
  while IFS='' read -r line; do
    [[ -z "$line" ]] && continue
    [[ "${line%%|*}" == "$q" ]] && { printf '%s\n' "${line#*|}"; return 0; }
  done <<<"$_REPO_FLAGS_CACHE"
  return 1
}

for name in "${TARGETS[@]}"; do
  flag="$(_lookup_flag "$name" || true)"
  if [[ -z "$flag" ]]; then
    echo "── $name ── (not in project.conf REPOS — skipping)"
    SKIPPED+=("$name")
    continue
  fi
  if [[ "$flag" == "true" && "$FORCE" != "true" ]]; then
    echo "── $name ── already graphified (skip; --force to rerun)"
    SKIPPED+=("$name")
    continue
  fi
  echo "── $name ── running /graphify"
  if _run_graphify_one "$name"; then
    _set_graphified "$name" true \
      && { OK+=("$name"); echo "  $name: ok (flipped to graphified=true)"; } \
      || { FAILED+=("$name"); echo "  $name: graphify ran but flag flip failed" >&2; }
  else
    FAILED+=("$name")
    echo "  $name: graphify failed" >&2
  fi
done

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "── graphify summary ──"
echo "  mode:    $MODE ($MODE_SOURCE)"
[[ ${#OK[@]}      -gt 0 ]] && echo "  ok:      ${OK[*]}"
[[ ${#SKIPPED[@]} -gt 0 ]] && echo "  skipped: ${SKIPPED[*]}"
[[ ${#FAILED[@]}  -gt 0 ]] && echo "  failed:  ${FAILED[*]}"

if [[ ${#FAILED[@]} -gt 0 && ${#OK[@]} -eq 0 ]]; then
  exit 1
fi
exit 0
