# Changelog

## [Unreleased]

### Phase 1 — scaffold (2026-04-23)
- Added `ai-workbench/` template tree with CLAUDE.md, AGENTS.md, manifest, scripts, 18 skill stubs.
- Added `ai-devkit/` with `init.wb`, `join.wb`, `update.wb` launchers and prompt files.
- Added `DESIGN.md` covering both repos, flows, manifest policy, ralph adapter contract.

### Phase 2 — three-stage lifecycle + critical-path skills (2026-04-23)
- Migrated to three-stage artifact lifecycle (`draft → published → approved`).
- Added `wb.publish`, `wb.approve`, `wb.reject`, `wb.published`, `wb.approved` aliases.
- Rewrote `scripts/sync-context.sh` to read `.workbench-state/approved.json` as the single source of truth.
- Removed the legacy `product/outputs/prds/approved/` gate folder.
- Filled critical-path skill bodies: `epic-intake`, `prd-draft`, `eng-spec`, `tdd`, `bdd-gen`, `test-cases-gen`, `test-spec`, `ralph-workspace-plan`, `ralph-dispatch`.
- Simplified `ai-devkit`: dropped `epic-fitness-check` and `skill-sync` references (those utilities stay in `ai-utils`).
- Added local smoke test at `ai-workbench/tests/smoke.sh` exercising the full three-stage flow.
- Hardened lifecycle commands: path-traversal guards, required artifact type validation, reject-from-approved support, frontmatter-missing errors.
- Parked: Plan B (ralph adapter finalization against PR #3) and Plan D (remaining 9 skills).

### Phase 2 — Plan D shipped (2026-04-23)
- Filled 9 remaining skill bodies: `grill-me`, `prd-review-panel`, `pmo-status`, `adr`, `erd`, `figma-pull`, `ds-screen-gen`, `design-draft`, `design-review`.
- All skills are three-stage lifecycle aware and follow the Phase 2 structure (When to use / Prerequisites / Steps / Output contract / Do not) with a concrete example in at least one step.
- Added `wb.rejected` lister for symmetry with `wb.published` / `wb.approved`.
- Added `SESSION-HANDOFF.md` + template-dev detection to `CLAUDE.md` so new sessions pick up template-dev state automatically.
- Parked, still open: `scripts/lifecycle.py` extraction, BDD `.feature` lifecycle handler, concurrency lockfile, approved-folder audit. Details in `docs/superpowers/plans/PARKED-plan-D-remaining-skills.md` (not tracked in this repo; lives in `/Users/amittiwari/Projects/harness/`).
