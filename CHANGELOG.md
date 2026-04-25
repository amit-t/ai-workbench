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

### Steering system V1 (2026-04-24)
- Added `steering/` (template-owned) and `steering.local/` (user-owned) trees with structured rule files (one markdown file per rule, YAML frontmatter). Overlay semantics: add, `supersedes: [ID]` explicit field, `<ID>.removed.md` sidecar. See `steering/README.md` for the file format and `steering/config.yaml` for the canonical scope mapping.
- Progressive disclosure in three layers: Layer 0 (golden) at session start, Layer 1 (role: dev / qa / po / uxd) on role-inference match, Layer 2 (artifact / topic) as step 0 of each skill. Loader: `scripts/steering-load.py <scope>`. Linter: `scripts/steering-lint.py`.
- Aliases: `wb.steering`, `wb.steering-refresh`, `wb.steering-lint`.
- Freshness hook: `.claude/settings.json` PostToolUse wiring re-emits Layer 0 after `update.wb`, `git pull`, `git merge`, or any Edit/Write touching `steering/**` or `steering.local/**`.
- Drift visibility: `pmo-status` shows local overrides (M1); weekly Monday GitHub Action in the template repo queries the org for repos with topic `ai-workbench` and posts a digest issue (M2, see `docs/steering/setup.md` for GitHub App install); promotion PRs from `steering.local/` to `steering/` are the M3 flow.
- Critical-path skills updated with step 0 + `relevant_topics:` frontmatter: `prd-draft`, `eng-spec`, `tdd`, `bdd-gen`, `test-cases-gen`, `test-spec`.
- Seeded content: 60 starter rule files (10 golden, 19 role, 28 artifact, 7 topic), each with Rule / Why / How to apply / Anti-pattern.
- Docs: new "Steering workflow" section in the root `README.md` (role-split between Architecture Council / QA Council / UX Council / Director of Engineering / teams); deep guide at `docs/steering/index.md`; GitHub App setup at `docs/steering/setup.md`.
- CODEOWNERS is now granular per steering directory with `{{ORG}}/<team>` placeholders (substituted at `init.wb` stamp time once the devkit follow-up lands).
- Manifest v2: `steering/`, `.claude/settings.json`, `.github/workflows/**`, `.github/CODEOWNERS` moved into `template_owned`; `steering.local/` added to `user_owned`.
- Smoke extended from 9 to 13 assertions (steering copied to every registered repo, loader non-empty output, overlay add + supersede + remove round-trip, lint pass).
- Parked in companion `ai-devkit` PR: `init.wb` must tag stamped repos with topic `ai-workbench` (required for M2 discovery); `update.wb` should print the count of local steering overrides after a pull as a local nag.

### Ralph adapter V1 (2026-04-25)
- Plan B unblocked. Workbench now wraps ai-ralph workspace mode without re-implementing any ralph internals. Ralph owns planning, the workspace loop, parallelism, and PR creation; workbench routes approved artifacts and ships team steering.
- New: `scripts/artifact-schema.json` + `scripts/validate-artifact.py`. Hooked into `scripts/lifecycle.py` at both `publish` and `approve`. Blocks missing or unregistered `target_repos` on the eight routed artifact types (prd, eng-spec, tdd, erd, bdd, test-cases, test-spec, test-erd); non-routed types (adr, epic-context) pass through.
- New: `scripts/ralph-enable-check.sh` preflights that `ralph enable --workspace` ran at `$WB_ROOT/repos/`. Called by `wb.ralph-plan` and `wb.ralph-dispatch`.
- Rewrote `scripts/ralph-plan.sh` with a mode resolver (CLI flag > env `WB_RALPH_PLAN_MODE` > `project.conf RALPH_PLAN_MODE` > auto-detect > workspace default). Workspace mode runs one `ralph-plan --workspace` call at `repos/`; per-repo mode loops `project.conf REPOS` as a fallback for older ralph installs.
- Rewrote `scripts/ralph-dispatch.sh` as a thin wrapper over `ralph --workspace --parallel N`. Default `N = min(len(REPOS), 4)`, overridable via flag / env / project.conf. `--status` wraps `gh pr list` + ralph worker log tail. Exports `WORKSPACE_ROOT` so ralph picks up the right context dir.
- Deleted `scripts/ralph-loop.sh`. Single-repo debugging is a one-liner: `(cd "$WB_ROOT/repos/<name>" && ralph --live --monitor)`.
- New: `scripts/ralph-annotate-prs.sh` for the M4 drift footer as a transitional post-hoc `gh pr edit` fallback. Retires once the ralph-side `.ralph/pr_footer.md` support is in the deployed ralph binary.
- New: `scripts/steering-overlays.py` with `--footer` / `--json` / `--list` modes. Reuses `scripts/steering-load.py` parsers; emits markdown footer classifying every `steering.local/` entry as ADD / SUPERSEDE / REMOVE.
- `scripts/sync-context.sh`: honors `target_repos:` (copies artifact only to listed repos); writes the drift footer into `$WB_ROOT/repos/.ralph/pr_footer.md` when the ralph workspace exists and overrides are present; removes the file when the overlay set empties.
- Seven skills gain `target_repos` in the output frontmatter (or Gherkin header for BDD) plus a prompt step that sources from `project.conf REPOS`: `prd-draft`, `eng-spec`, `tdd`, `erd`, `bdd-gen`, `test-cases-gen`, `test-spec`.
- Seven new steering rules enforce the requirement: `PRD-007`, `ESPEC-007`, `TDD-006`, `ERD-001`, `BDD-007`, `TC-005`, `TSPEC-006`. New `artifact:erd` scope added to `steering/config.yaml`.
- `project.conf.template` picks up ralph defaults: `RALPH_PLAN_MODE=auto`, `RALPH_PLAN_ENGINE=devin`, `RALPH_PLAN_THINKING=ultra`, `WB_RALPH_PARALLEL=""`.
- Aliases: `wb.ralph-enable-check`, `wb.ralph-annotate`. Removed `wb.ralph-loop`. Updated `wb.ralph-plan` and `wb.ralph-dispatch` wire into the rewritten scripts.
- Docs: `CLAUDE.md` adds a ralph adapter quick reference plus new hard rules (no re-implementing ralph internals; target_repos required on routed artifacts). `README.md` gains the "Multi-repo execution with ralph" section covering bootstrap, daily flow, configuration, and the M4 footer.
- Smoke extended from 13 to 22 assertions: validator blocks missing target_repos at publish; validator blocks unregistered repo names; target_repos filter drops artifacts from non-target repos; steering-overlays renders add / supersede / remove; sync-context writes pr_footer.md when `repos/.ralph/` exists; `wb.ralph-plan --dry-run` picks workspace mode by default and honors `--mode per-repo`; `wb.ralph-dispatch --dry-run` invokes `ralph --workspace --parallel N` with `WORKSPACE_ROOT`; `ralph-enable-check` blocks when workspace is not enabled.
- Companion ai-ralph PRs (on Invenco-Cloud-Systems-ICS/ai-ralph): `feat/workspace-plan-mode` (adds `ralph-plan --workspace`) and `feat/pr-footer-append` (`pr_manager.sh` appends `.ralph/pr_footer.md` to PR bodies). Both merged. With pr-footer support in the deployed ralph, the post-hoc `wb.ralph-annotate` can retire; until then it is an idempotent safety net.
- Merged on both remotes (amit-t #9, Invenco #10).
