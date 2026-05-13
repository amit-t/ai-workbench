#!/usr/bin/env bash
# smoke-wb-onboarding.sh - Local mirror of .github/workflows/smoke-wb.yml.
#
# Exercises the end-to-end onboarding path:
#   stamp a wb from the template -> register a local target repo -> drop
#   fixture artifacts -> publish + approve -> wb.steering golden ->
#   ralph enable --workspace -> wb.ralph-enable-check -> wb.ralph-plan --dry-run
#
# Sandboxed under $(mktemp -d) and cleaned up on exit. macOS-aware: skips
# apt-get (assumes brew has the prereqs already) and uses Darwin-friendly date
# flags.
#
# Run from any clone of ai-workbench:
#   bash tests/integration/smoke-wb-onboarding.sh
#
# Required prereqs on PATH: zsh, jq, gh, git, python3, ralph, ralph-plan.
# If a deep dep is missing (ralph not installed) the script reports it and
# exits non-zero so CI is the authoritative gate.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WB_TEMPLATE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Sandbox + cleanup ────────────────────────────────────────────────────────
SANDBOX="$(mktemp -d -t wb-smoke-XXXXXX)"
cleanup() {
  rc=$?
  if [[ -n "${SANDBOX:-}" && -d "$SANDBOX" ]]; then
    rm -rf "$SANDBOX"
  fi
  if (( rc == 0 )); then
    echo "[smoke-wb-onboarding] PASS"
  else
    echo "[smoke-wb-onboarding] FAIL (rc=$rc)" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT

WB_ROOT="$SANDBOX/wb-wsl-smoke-local"
FAKE_TARGET="$SANDBOX/fake-target.git"

# ── Prereqs ─────────────────────────────────────────────────────────────────
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[smoke-wb-onboarding] missing prereq: $1" >&2
    case "$1" in
      ralph|ralph-plan|ralph-enable)
        echo "  install ai-ralph: bash <(curl -fsSL https://raw.githubusercontent.com/amit-t/ai-ralph/main/install.sh)" >&2
        ;;
      gh|jq)
        if [[ "$(uname -s)" == "Darwin" ]]; then
          echo "  brew install $1" >&2
        else
          echo "  sudo apt-get install -y $1" >&2
        fi
        ;;
    esac
    return 1
  fi
}

echo "[smoke-wb-onboarding] checking prereqs"
for c in zsh jq gh git python3 ralph ralph-plan ralph-enable; do
  require_cmd "$c"
done

# ── Stamp a wb from the template ────────────────────────────────────────────
echo "[smoke-wb-onboarding] stamping wb from template at $WB_ROOT"
cp -R "$WB_TEMPLATE_ROOT" "$WB_ROOT"
# Cleanse template-dev artefacts that init.wb would purge per
# .workbench-manifest.json template_dev_only.
rm -rf "$WB_ROOT/.git"
rm -f  "$WB_ROOT/SESSION-HANDOFF.md"

if [[ "$(uname -s)" == "Darwin" ]]; then
  CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
else
  CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi

sed \
  -e 's|{{LABEL}}|wsl-smoke-local|g' \
  -e 's|{{REPO_URL}}|https://example.invalid/wb-wsl-smoke-local|g' \
  -e 's|{{TEMPLATE_UPSTREAM_URL}}|https://github.com/amit-t/ai-workbench|g' \
  -e 's|{{CREATED_BY}}|local-smoke|g' \
  -e "s|{{CREATED_AT}}|$CREATED_AT|g" \
  -e 's|{{ORG}}|amit-t|g' \
  -e 's|{{EPICS_BASH_ARRAY}}|"EPIC-001"|g' \
  -e 's|{{REPOS_BASH_ENTRIES}}|  # populated by wb.register-repo|g' \
  "$WB_ROOT/project.conf.template" > "$WB_ROOT/project.conf"

bash -n "$WB_ROOT/project.conf"

# ── Register a local target repo ────────────────────────────────────────────
echo "[smoke-wb-onboarding] creating local bare target repo $FAKE_TARGET"
mkdir -p "$FAKE_TARGET"
( cd "$FAKE_TARGET" && git init --bare -q )

cd "$WB_ROOT"
# shellcheck disable=SC1091
source aliases.sh
wb.register-repo demo-repo "$FAKE_TARGET" service generic

# ── Drop fixture artifacts at status:draft ──────────────────────────────────
mkdir -p "$WB_ROOT/product/context-library/epics" "$WB_ROOT/product/outputs/prds"
cat > "$WB_ROOT/product/context-library/epics/EPIC-001.md" <<'EOF'
---
id: EPIC-001
type: epic-context
status: draft
---
# EPIC-001 smoke fixture
EOF
cat > "$WB_ROOT/product/outputs/prds/PRD-001.md" <<'EOF'
---
id: PRD-001
type: prd
status: draft
target_repos: [demo-repo]
---
# PRD-001 smoke fixture
EOF

# ── Publish + approve both ──────────────────────────────────────────────────
echo "[smoke-wb-onboarding] publish + approve EPIC-001"
wb.publish EPIC-001 product/context-library/epics/EPIC-001.md epic-context
wb.approve EPIC-001

echo "[smoke-wb-onboarding] publish + approve PRD-001"
wb.publish PRD-001 product/outputs/prds/PRD-001.md prd
wb.approve PRD-001

echo "[smoke-wb-onboarding] asserting both approved"
jq -e '.items | map(.id) | contains(["EPIC-001","PRD-001"])' \
  "$WB_ROOT/.workbench-state/approved.json" > /dev/null

# ── Steering golden ─────────────────────────────────────────────────────────
echo "[smoke-wb-onboarding] wb.steering golden"
wb.steering golden | head -20 > /dev/null

# ── ralph enable + wb.ralph-enable-check + wb.ralph-plan --dry-run ──────────
echo "[smoke-wb-onboarding] ralph-enable --workspace --non-interactive"
( cd "$WB_ROOT/repos" && ralph-enable --workspace --non-interactive )

echo "[smoke-wb-onboarding] wb.ralph-enable-check"
wb.ralph-enable-check

echo "[smoke-wb-onboarding] wb.ralph-plan --dry-run"
wb.ralph-plan --dry-run
