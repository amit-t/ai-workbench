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

### Lifecycle polish (2026-04-24)
- Extracted `scripts/lifecycle.py`: single CLI with subcommands `publish | approve | reject | list` replaces three Python heredocs in `aliases.sh`. `aliases.sh` now 6 one-line shell wrappers.
- BDD `.feature` lifecycle support: CLI detects `.feature` extension and rewrites the `# status:` header comment (instead of YAML frontmatter). Updated `skills/bdd-gen/SKILL.md` to remove the old limitation note.
- Advisory `flock` on `.workbench-state/.lock` around every read-modify-write cycle, removing the last-writer-wins race for concurrent collaborators.
- `tests/smoke.sh` re-enabled the BDD round-trip case (publish flips header, approve flips again, `sync-context` routes to `role=automation-tests` only).
- Audited `grep -r "prds/approved"`: no Phase-1 stragglers remain in `skills/`, `scripts/`, or `docs/`.
- Clarified artifact lifecycle section in `README.md` (diagram, stage semantics, upstream gates, dev + QA flows, inspection aliases).
