# Changelog

## [Unreleased]

### Plan D2, wb-side CI lint workflow seeded by `update.wb` (2026-04-29)
- `.github/workflows/wb-ci.yml`: new workflow that runs `python3 scripts/steering-lint.py` plus `python3 scripts/wb-ci-validate.py --stdin` on every PR that touches `product/`, `design/`, `engineering/`, `qa/`, `steering/`, `steering.local/`, or any of the helper scripts. Detects stamped-wb mode by the presence of `project.conf`; in the template repo itself (no `project.conf`) the artifact-validation step is a no-op so only steering-lint runs. `.github/workflows/**` is already `template_owned`, so `update.wb` seeds the workflow into every existing stamped wb on the next sync.
- `scripts/wb-ci-validate.py`: reads paths from CLI args or stdin, classifies each by directory prefix into one of `prd`, `eng-spec`, `tdd`, `erd`, `adr`, `bdd`, `test-cases`, `test-spec`, `test-erd`, `epic-context`, and runs `scripts/validate-artifact.py` on it. Skips non-artifact paths, README/INDEX docs, and paths that no longer exist in the worktree (renames). Catches missing `target_repos`, unregistered repos, and missing required fields at PR time, before `wb.publish` / `wb.approve` fires locally.
- `tests/smoke.sh`: five new assertions (9q workflow + helper present in stamped tree; 9q1 manifest still keeps `.github/workflows/**` template-owned; 9q2 classify-by-path table; 9q3 PR with bad PRD fails; 9q4 non-artifact paths are skipped; 9q5 valid PRD passes). Smoke 29/29 → 35/35.

### Plan E5, upstream-ralph `--repos <subset>` filter design doc (2026-04-29)
- `notes/upstream-ralph-v2/repos-subset-filter.md`: design doc for adding `--repos <list>` and `--exclude <list>` flags to `ralph --workspace`. Covers the four motivating scenarios (mid-refactor pin, single-service sprints, scheduled cron runs, symmetric companion to `wb.ralph-plan --replan`), the `discover_workspace_repos()` chokepoint refactor (Option A: optional second arg), cross-repo section behavior under a partial filter (skip by default; opt-in deferred), env passthrough (`RALPH_WORKSPACE_REPOS` / `RALPH_WORKSPACE_EXCLUDE`), back-compat (byte-identical output when no filter), test coverage matrix, and the workbench follow-up surface (`wb.ralph-dispatch --repos`, `WB_RALPH_DISPATCH_REPOS` knob in `project.conf.template`).
- No code changes shipped: pure design doc. Implementation moves to `ai-ralph` once accepted.
- Smoke 22/22 still green; no contract change.

### Plan F2 + F3 — README + update.wb migration (2026-04-27)
- `README.md` "Multi-repo execution with ralph" → "One-time bootstrap" section rewritten to document the six-step preflight that `init.wb` Step 3.4b and `join.wb` Step 4b run, including the `template_dev_only` purge and the `ralph-enable-check.sh` sanity check. Added a closing note that older stamped wbs can be migrated via `update.wb`.
- `ai-devkit/update-workbench/update.zsh`: post-sync block detects an old stamped wb missing `repos/.ralph/` (or whose `.ralphrc` lacks `WORKSPACE_MODE=true`) and runs `ralph enable --workspace --non-interactive --skip-tasks` at `${WB_DIR}/repos/`. Idempotent: skipped when workspace already enabled, when ralph is missing from PATH, or when ralph lacks `--workspace` support. After enable, calls `scripts/ralph-enable-check.sh` for a final verify.
- `tests/smoke.sh`: two new asserts (9o2 README mentions bootstrap command + template_dev_only + update.wb migration; 9o3 update.zsh has the migration block, ralph enable command, and WORKSPACE_MODE check). Smoke 25/25 → 27/27.

### Stamped-wb ralph bootstrap (2026-04-27, Plan F1)
- `ai-devkit/init-workbench/init.prompt.md`: Step 3.1 preflight installs `ralph` from the local `ai-ralph` clone (or upstream) when missing and verifies `--workspace` support; Step 3.4 always creates `repos/` (even when no repos register at init); new Step 3.4a purges every entry in `.workbench-manifest.json` `template_dev_only` so stamped wbs never inherit template-dev's `.ralph/PROMPT.md`, `.ralph/fix_plan.md`, `SESSION-HANDOFF.md`, or `CHANGELOG.md`; new Step 3.4b runs `ralph enable --workspace --non-interactive --skip-tasks` at `repos/` and calls `scripts/ralph-enable-check.sh` to verify.
- `ai-devkit/join-workbench/join.prompt.md`: new Step 0 preflight installs `ralph` and verifies `--workspace`; new Step 4b runs `ralph-enable-check.sh`, with idempotent `ralph enable --workspace` fallback for joiners pulling older workbenches that predate Step 3.4b.
- `ai-devkit/install.zsh`: warns when `ralph` is missing or lacks `--workspace`. Does not auto-install (init.wb / join.wb own that path so users see the install during workbench bootstrap).
- `.workbench-manifest.json`: added `.ralph/**` and `repos/.ralph/**` to `user_owned`; added new `template_dev_only` list (`SESSION-HANDOFF.md`, `CHANGELOG.md`, `.ralph/PROMPT.md`, `.ralph/fix_plan.md`) consumed by Step 3.4a.
- `CLAUDE.md`: Step 0 (template-dev detection) now flags `.ralph/PROMPT.md` + `.ralph/fix_plan.md` as template-dev only; Ralph adapter section names init.wb Step 3.4b and join.wb Step 4b as the bootstrap points and notes the `template_dev_only` purge.
- `tests/smoke.sh`: three new assertions (9o init prompt, 9o join prompt, 9p manifest) bring smoke from 22/22 to 25/25.

### Template-dev ralph self-host (2026-04-27)
- Enabled `ralph` at the template-dev root via `ralph-enable --non-interactive --skip-tasks`. Replaced the generic `.ralph/PROMPT.md` with a template-dev-oriented version (reading order, hard rules from `CLAUDE.md`, cross-repo routing for `ai-ralph` PRs, RALPH_STATUS block preserved). Seeded `.ralph/fix_plan.md` with parked Plan D and Plan E from `SESSION-HANDOFF.md`; Plan C marked non-auto-loopable.
- `.gitignore`: `.ralphrc` ignored as machine-specific config (sourced by `ralph_loop.sh`'s `load_ralphrc`). `.ralph/PROMPT.md` and `.ralph/fix_plan.md` remain tracked via the existing exception list.

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
