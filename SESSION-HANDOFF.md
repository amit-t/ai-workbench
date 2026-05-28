# Session handoff — ai-workbench template development

> This file is for **template-development work on the ai-workbench repo itself**, not for stamped workbench instances. If you are in a stamped workbench (one created by `init.wb`), ignore this file.
>
> **New Claude Code session starting here?** Read this top-to-bottom before doing anything. Then read `CHANGELOG.md` for detail on what has shipped.

**Last session:** 2026-05-27 (handoff refresh only). **Last shipping session:** 2026-05-19 — `wrd.p` devin-parallel shorthand (PR #53) + release 1.6.0 cut (#54). Releases 1.1.0 → 1.6.0 all auto-cut by release-please between 2026-05-13 and 2026-05-19; full delta documented in `## What shipped` below.
**Branch:** `main` (clean, synced with `origin/main`). `dev` archived for now; all post-2026-04-29 work merged through main.
**Previous handoff anchor:** 2026-04-29 (Plan D1/D2/D3/D4 + E1/E5 + F1/F2/F3 all shipped).
**Smoke:** green (76 assertions). R1 regression fixed 2026-05-28 (README `### Stamped-wb bootstrap` subsection re-added + smoke 9o2 regex widened to accept `wb.upgrade`). Not yet committed/pushed.
**Remotes:** `origin → amit-t/ai-workbench`, `inv → Invenco-Cloud-Systems-ICS/ai-workbench`.
**Commit identity in use:** `user.name=amit-t`, `user.email=tiwari.m.amit@gmail.com` (personal). Set local `user.email=amit.tiwari@invenco.com` before committing if you want Invenco attribution on template-dev commits.
**Main branch protection:** PR required, admin bypass enabled, no force-push, no deletion.
**gh accounts:** two logged in (`amit-t` active by default, `amit-tiwari_vnt` for Invenco). Use `gh auth switch -u amit-tiwari_vnt` before any PR create/merge on `Invenco-Cloud-Systems-ICS/ai-workbench`, and switch back after.

---

## What shipped

### Release 1.6.0 — `wrd.p` devin-parallel shorthand (2026-05-19)
- `aliases.sh`: new `wrd.p N M` shorthand → `wb.ralph-dispatch --engine devin --parallel N --max-tasks M`. Mirrors ralph's positional `--parallel N M` continuous-mode form. Pairs with the existing `rpd.p` ai-ralph shorthand. PR #53. release-please cut tag v1.6.0 (#54).

### Release 1.5.0 — dispatch engine routing + continuous mode + stub purge + docs (2026-05-18)

Multi-feature release. Headline items:

- **Dispatch engine binary routing + plan/exec split** (`a0b77a2` / inv `ab86496`). `wb.ralph-dispatch --engine <claude|devin|codex>` now maps to the right binary (`ralph` / `ralph-devin` / `ralph-codex`). Plan engine and exec engine are independently selectable so you can run plan=claude exec=devin (or any mix). Resolution: CLI > env > `project.conf` > default devin. `aliases.sh`, `project.conf.template`, smoke updated.
- **Continuous-mode dispatch passthrough** (`3cc85e2`). `wb.ralph-dispatch --parallel N --max-tasks M` (or positional `N M`) forwards to ralph's continuous mode — workers stay saturated up to N concurrent until M attempts spent. Extra knobs `--max-task-attempts`, `--respawn-delay`, `--no-tabs`. Capability-gated: dispatch fails fast if installed ralph predates the flag.
- **Wb-root `.ralph/` stub purge** (`8ba2d69` / inv `02ed649`). `.workbench-manifest.json` `template_dev_only` extended to cover the full stub stack; `wb.upgrade` backs up to `.ralph.purged.<timestamp>/`. `ralph-enable-check` now refuses if a wb-root stub is present in a stamped wb. Closes a class of "ralph runs against the wrong workspace" bugs from old wbs.
- **`/wtd` what-to-do recommender + workflows GH-Pages page** (PR #43/#44). New skill suggests the highest-leverage next action given current wb state (epics, pipeline, approvals, in-flight branches). Workflows page on the site documents the canonical sequences.
- **`/precise-readme` skill + per-skill GH-Pages catalogue** (PRs #47/#48). Skill applies precision-mode pass to a project's README; site now exposes `docs/skills/<name>.html` per-skill pages and a catalogue index.
- **`workflows.md` precision-mode pass** (PRs #49/#50). Dense workflows reference.
- **Precision-mode pass on README + V1 archive** (PRs #45/#46). Whole README rewritten under precision-mode; V1 README preserved at `/v1/`. ⚠️ Side-effect: dropped three strings the smoke test asserts on (see R1).
- **Jekyll site hardening** (`8464e07`, `2af774b`, `e72b66a`, `215f8ef`). Cross-owner link guard tightened to URL-only; `superpowers/{plans,specs}` excluded from build then re-allowed in guards; CNAME synced from inv.
- **CI smoke-wb mimics init.wb template_dev_only purge on stamp** (`3f30c4e`). Catches regressions where stamped wbs would inherit template-dev artifacts.

release-please cut tag v1.5.0 (#51).

### Release 1.4.0 — precision-mode skill + wire into 9 draft hosts (2026-05-15)
- `skills/precision-mode/SKILL.md` installed via `.claude/skills/precision-mode/`. Universal "lead-with-answer, no filler, structure over prose" directive applied to artifact body, grill session, and next-steps tail across 9 draft-producing hosts.
- Resolution: env `WB_PRECISION_MODE` > `project.conf PRECISION_MODE` > default `on`. `wb.precision` alias prints resolved value + source. Carried into artifact frontmatter as `precision_mode: on|off` (Gherkin: `# precision_mode: on|off`).
- Review panels surface as P3 info hint; no enforcement.
- PRs #40/#41. release-please cut tag v1.4.0 (#42).

### Release 1.3.0 — implicit grill into 9 draft skills + grill workflows (2026-05-15)
- Shared substrate `skills/grill-substrate.md` (per-artifact stance, scratch-block format, `grilled:` frontmatter schema) packaged.
- Depth-aware generic grill skills installed: `.claude/skills/grill-me/`, `.claude/skills/domain-grill/`.
- 9 draft-producing skills now run an implicit grill step before publishing draft. Skipping permitted; `wb.publish` warns when receipt is missing; review-panels add P2 finding.
- PRs #37/#38 + inv companion #49/#50. release-please cut tag v1.3.0 (#39).

### Release 1.2.1 — `wb.rescan` brick fix (2026-05-14)
- `wb.rescan` was bricked by permission-mode, flag order, and stdout leak issues. Fixed in PR #35. release-please cut tag v1.2.1 (#36).

### Release 1.2.0 — repo-context-scan auto-run + `wb.rescan` (2026-05-13/14)
- `wb.rescan` alias added: re-runs the context scan against `repos/*/` to refresh `engineering/context-library/`. PR #27 (dev) → #33 (main).
- Context scan auto-run wired into `wb.sync-context` so newly-approved artifacts trigger a context refresh.
- release-please cut tag v1.2.0 (#34).

### Release 1.1.0 — multi-wb resolution + WSL port + versioning template (2026-05-13)
- **WSL/Windows port hardening** (PRs #28/#29/#30/#31). Shell-lint matrix (bash + zsh) on macOS + ubuntu, `.gitattributes` line-ending hygiene, dropped `TODO(windows)` markers, shellcheck warning cleanup across `scripts/` + `tests/`, `tests/smoke.sh` E2E onboarding (init.wb → publish → approve → `wb.ralph-plan --dry-run`), CI tightened to warning severity. Three repos ported (workbench, devkit, ralph); 11 PRs merged 2026-05-13 (see memory `project_wsl_port.md`).
- **Multi-workbench resolution** (PRs #25/#26). One sourced `aliases.sh` now serves every stamped wb on the machine via `_wb_resolve_root` (`WB_PIN` env → walk-up for `project.conf` → source-baked default). New aliases: `wb.switch`, `wb.unswitch`, `wb.where`. Loud failure on invalid `WB_PIN`. Detail in "Multi-workbench resolution" section below.
- **Versioning template-side wiring** (PRs #22/#23, 2026-05-09). `version.json` at root, `aliases.sh` preamble checks `version.json` against `requires` for peer tools (ai-ralph, ai-devkit). `wb.upgrade` / `ralph.upgrade` / `devkit.upgrade` separated; `devkit doctor` is the one-step diagnostic.
- **Wb-side version notification pages** (PR #24, 2026-05-11). `docs/pages/versioning.md` documents the upgrade flow.
- **`/handoff` skill** packaged so any session can compact itself for the next agent.
- release-please cut tag v1.1.0 (#32).

### Ralph V2 passthrough — `--repos` / `--exclude` / `--parallel-plan` (2026-05-08)
- `wb.ralph-dispatch --repos <list>` / `--exclude <list>`: narrow workspace run to a subset of registered repos. Validated against `project.conf REPOS` before forwarding; typos fail in the wrapper. Mutually exclusive. Resolution: CLI > env (`WB_RALPH_DISPATCH_REPOS` / `_EXCLUDE`) > `project.conf` > unset.
- `wb.ralph-plan --parallel-plan N`: workspace-mode only; forwards to `ralph-plan --workspace --parallel-plan N` for concurrent per-repo plan calls. Buffer-then-merge keeps section ordering stable. Resolution: CLI > `WB_RALPH_PLAN_PARALLEL` > `project.conf` > sequential.
- env-state captured before sourcing `project.conf` so CLI / env override conf correctly.
- 8 new smoke assertions.
- Upstream ralph impl shipped 2026-05-07/08: amit-t/ai-ralph#51 (main) + #52 (dev), Invenco-Cloud-Systems-ICS/ai-ralph#17 (main) + #18 (dev); amit-t/ai-ralph#53 (main) + #54 (dev), Invenco-Cloud-Systems-ICS/ai-ralph#19 (main) + #20 (dev). Workbench wiring: amit-t/ai-workbench#20 (main) + #21 (dev), Invenco-Cloud-Systems-ICS/ai-workbench#34 + #35.

### Multi-workbench resolution for `wb.*` aliases (2026-05-13)
- `aliases.sh`: every `wb.*` command now resolves the active wb per call via a new `_wb_resolve_root` helper. Priority order: `WB_PIN` env var → walk up from `$PWD` for `project.conf` → source-baked default. One sourced `aliases.sh` now serves every stamped wb on the machine; switching workbenches no longer requires re-sourcing.
- New aliases: `wb.switch <path>` (validates `<path>/project.conf`, exports `WB_PIN`), `wb.unswitch` (clears the pin), `wb.where` (prints resolved wb + how — pin / cwd / default). `wb.info` extended with the resolution source.
- Loud-failure semantics: an invalid `WB_PIN` errors immediately and never silently falls through to cwd. Outside-any-wb + no valid default prints the hint `wb.switch /path/to/wb-<label>`.
- Tests: new `tests/test-wb-resolve-root.sh` (17 cases covering pin/cwd/default priorities, nested wbs, symlinks, end-to-end wrapper dispatch). `tests/test-aliases-preamble.sh` migrated from the old `WB_ROOT=` env-var override to `WB_PIN=` (the new public hook), with project.conf seeded in fake wb fixtures. `.github/workflows/test.yml` adds a `wb-resolve-root` matrix job on ubuntu + macos. `tests/smoke.sh` unchanged (already resolves via cwd from inside the stamped tree).
- Spec: `docs/superpowers/specs/2026-05-13-wb-multi-workbench-resolution-design.md`.
- Migration: `aliases.sh` is `template_owned`. Stamped wbs receive the new resolver on the next `wb.upgrade`. Sole back-compat change: the undocumented `export WB_ROOT=…` pre-source trick no longer works (each wb.* function declares `WB_ROOT` as a local). The only known consumer was `test-aliases-preamble.sh`, migrated in this change.

### Plan D2, wb-side CI lint workflow seeded by `update.wb` (2026-04-29)
- `.github/workflows/wb-ci.yml`: PR check that runs steering-lint plus per-file artifact validation. Triggers on changes to `product/`, `design/`, `engineering/`, `qa/`, `steering/`, `steering.local/`, or any of the helper scripts. The artifact step diffs `origin/<base>...HEAD` and pipes the change list into the helper.
- `scripts/wb-ci-validate.py`: classifier + runner. Maps each path to one of ten artifact types by directory prefix, skips non-artifact files (README/INDEX, anything outside `product|design|engineering|qa/outputs/`, anything that does not exist in the worktree), and runs `scripts/validate-artifact.py` per file. Catches missing `target_repos`, unregistered repos, and missing required fields at PR time so reviewers do not have to find them by running `wb.publish` locally.
- Stamped wbs get the workflow for free: `.github/workflows/**` is already in `template_owned`, so `update.wb` syncs `wb-ci.yml` into every existing stamped wb on the next run; new wbs inherit it from `gh repo create --template`. In the template repo itself, `project.conf` is absent, so artifact validation is a no-op and only steering-lint runs.
- `tests/smoke.sh` 29/29 → 35/35 (asserts workflow + helper presence in stamped tree, manifest still keeps `.github/workflows/**` template-owned, classify-by-path table covers all ten types, helper fails on bad PRD, helper passes on clean PRD, helper ignores non-artifact paths).

### Plan D1 — remaining 12 skills get Step 0 + relevant_topics (2026-04-29)
- Added `relevant_topics: []` and a Step 0 "Load steering" section to the 12 skills that did not yet have them: `adr`, `erd`, `epic-intake`, `figma-pull`, `ds-screen-gen`, `design-draft`, `design-review`, `grill-me`, `prd-review-panel`, `pmo-status`, `ralph-workspace-plan`, `ralph-dispatch`. The 6 critical-path skills that already shipped Step 0 in Phase 2 (`prd-draft`, `eng-spec`, `tdd`, `bdd-gen`, `test-cases-gen`, `test-spec`) were untouched. Every skill now declares `relevant_topics:` in frontmatter and runs Step 0 before any other work.
- Per-skill pattern: artifact-producers (`adr`, `erd`, `epic-intake`) call `wb.steering artifact:<type>` (forward-compat for `adr` and `epic-context` even though those steering directories are empty today; the loader returns an empty merged blob without erroring); reviewer (`prd-review-panel`) calls `artifact:prd` so reviewer agents enforce the same rules the author obeyed; orchestrators (`ralph-workspace-plan`, `ralph-dispatch`) and read-only (`pmo-status`) note explicitly that Layer 2 was already enforced upstream and only Layer 0 governs voice / gate logic; design skills (`figma-pull`, `ds-screen-gen`, `design-draft`, `design-review`) note the lack of a template `artifact:design` scope and only load `artifact:design` when a per-workbench team has added overlay rules; `grill-me` defers the load to step 1 once the target type is known.
- Smoke 29/29 still green (no smoke contract changes); steering-lint clean; no Python or shell touched.

### Plan D3 — `wb.steering-audit` command (2026-04-29)
- `scripts/steering-audit.py`: surfaces every overlay under `steering.local/` with kind (add / supersede / remove), targeted template rule(s), scope, owner, `created`, `updated`-with-mtime-fallback, age in days, distinct epics whose artifacts fall under the overlay's scope, and a promote-suggest flag (true when 2+ epics; REMOVE excluded).
- Three output modes: default markdown report (Summary + Overrides table + Promotion candidates section when applicable), `--json` (machine-readable), `--list` (terse one-line-per-override).
- `aliases.sh`: new `wb.steering-audit` wrapper.
- Docs: `CLAUDE.md` Key commands table, `README.md` "Steering workflow" + Tooling block, `steering/README.md` Drift visibility section.
- Smoke 29/29 → 33/33 (4 new asserts: markdown, --list, --json schema, multi-epic promote-suggest).

### Plan D4, steering loader mtime-keyed cache (2026-04-29)
- `scripts/steering-load.py` caches rendered output at `.workbench-state/steering-cache/<scope>.cache`. Fingerprint is sha256 over (relative path, st_mtime_ns, st_size) for every input file in the scope's template dir and overlay dir, so any edit, add, or remove flips the key. Hit returns the cached body verbatim; miss renders, writes atomically via a `.tmp` rename, and emits the fresh content.
- New CLI: `--no-cache` per-call, `--clear-cache` to wipe the cache dir, `WB_STEERING_NO_CACHE=1` env var (also `true`/`yes`/`on`) for session-wide bypass. Cache writes are best-effort: any `OSError` is swallowed so the loader still works on read-only filesystems.
- `.gitignore` excludes `.workbench-state/steering-cache/`.
- `tests/smoke.sh` 29/29 to 35/35: six new asserts cover first-call write, hit returns identical bytes, mutated-cache observability proves the hit path, mtime-touch invalidation, new-overlay-file invalidation, both bypass paths, and `--clear-cache`.

### Template-dev ralph self-host + stamped-wb ralph bootstrap (2026-04-27)

**Template-dev self-host.** Ralph now runs against the template repo itself for template-dev work. Enabled via `ralph-enable --non-interactive --skip-tasks` at root. `.ralph/PROMPT.md` rewritten with template-dev orientation (reading order, hard rules, cross-repo routing for `ai-ralph` PRs, RALPH_STATUS block preserved). `.ralph/fix_plan.md` seeded with Plan D, Plan E, Plan F from prior `What's open` section. `.ralphrc` gitignored as machine-specific config; `ALLOWED_TOOLS` expanded for template-dev workflows; `PR_DRAFT=true` for safer auto-PRs. Verified by running `rpc.p.b 1` which picked Plan E1 and shipped it (PRs #12 / #13).

**Stamped-wb ralph bootstrap (Plan F1).** `ai-devkit` is now the only place that bootstraps ralph for stamped wbs:
- `init.prompt.md` Step 3.1 installs `ralph` from local `ai-ralph` clone (or upstream) when missing and verifies `--workspace` support; Step 3.4 always `mkdir -p repos`; new Step 3.4a purges every entry in `.workbench-manifest.json` `template_dev_only`; new Step 3.4b runs `ralph enable --workspace --non-interactive --skip-tasks` at `repos/` and calls `scripts/ralph-enable-check.sh` to verify.
- `join.prompt.md` Step 0 preflight installs `ralph`; new Step 4b runs `ralph-enable-check.sh` with idempotent `ralph enable --workspace` fallback.
- `install.zsh` warns when `ralph` is missing or lacks `--workspace`. Auto-install lives in init.wb / join.wb so users see it.
- `.workbench-manifest.json` now has `.ralph/**` and `repos/.ralph/**` in `user_owned`, plus a new `template_dev_only` list (`SESSION-HANDOFF.md`, `CHANGELOG.md`, `.ralph/PROMPT.md`, `.ralph/fix_plan.md`).
- `CLAUDE.md` Step 0 + Ralph adapter sections updated to document the rule.
- `tests/smoke.sh` 22/22 → 25/25 (asserts ralph install probe, `--workspace`, `template_dev_only` purge, `ralph-enable-check.sh` sanity, manifest fields).

### Plan E1 — ralph-workspace-plan + ralph-dispatch skill bodies (2026-04-27)
- `skills/ralph-workspace-plan/SKILL.md` and `skills/ralph-dispatch/SKILL.md` rewritten to drive the V1 `wb.ralph-plan` / `wb.ralph-dispatch` aliases with only the flags they actually accept. Stale `wb.ralph-loop` reference in `AGENTS.md` patched. Smoke + steering-lint clean. Shipped autonomously by ralph (PRs #12 / #13, both draft).

### Phase 1 — scaffold
- Template tree: `CLAUDE.md`, `AGENTS.md`, `DESIGN.md`, manifest, scripts, 18 skills (stubs).
- `ai-devkit/` with `init.wb`, `join.wb`, `update.wb` (Devin-first, Claude fallback).

### Phase 2 — three-stage lifecycle + critical-path skills
- Three-stage artifact lifecycle: `draft → published → approved`.
- Aliases: `wb.publish`, `wb.approve`, `wb.reject`, `wb.published`, `wb.approved`, `wb.rejected`.
- `scripts/sync-context.sh` reads `.workbench-state/approved.json` as the only gate.
- Critical-path skill bodies (9): `epic-intake`, `prd-draft`, `eng-spec`, `tdd`, `bdd-gen`, `test-cases-gen`, `test-spec`, `ralph-workspace-plan`, `ralph-dispatch`.
- Smoke test: `tests/smoke.sh`.
- Hardenings: path-traversal guards, type validation, reject-from-approved, frontmatter-missing errors.

### Phase 2 — Plan D (2026-04-23)
- Remaining 9 skill bodies: `grill-me`, `prd-review-panel`, `pmo-status`, `adr`, `erd`, `figma-pull`, `ds-screen-gen`, `design-draft`, `design-review`.
- `wb.rejected` lister added for symmetry.

### Lifecycle polish (2026-04-24)
- Extracted `scripts/lifecycle.py`: single CLI with subcommands `publish | approve | reject | list`.
- BDD `.feature` lifecycle support: `# status:` header rewrite.
- Advisory `flock` on `.workbench-state/.lock` around every read-modify-write.
- Artifact lifecycle section added to `README.md` (diagram, stage semantics, dev + QA flows).

### Steering system V1 (2026-04-24)
- `steering/` (template) + `steering.local/` (user) with YAML frontmatter rule files.
- Progressive disclosure: Layer 0 (golden) at session start, Layer 1 (role) on role-inference, Layer 2 (artifact / topic) at step 0 of each critical-path skill.
- `scripts/steering-load.py` merges template + overlay (explicit `supersedes:` field, `<ID>.removed.md` sidecar). `scripts/steering-lint.py` validates frontmatter schema, ID regex, overlay-only placement. `.claude/settings.json` PostToolUse hook re-emits Layer 0 on relevant edits.
- Drift visibility: M1 (pmo-status), M2 (weekly Monday GitHub Action querying org by topic `ai-workbench`), M3 (promotion PRs). M4 was parked for the ralph adapter work and now shipped as part of V1 below.
- 60 starter rules across golden (10), roles (19), artifacts (28), topics (7).
- Smoke 9 → 13 assertions.

### Ralph adapter V1 (2026-04-25)
- Layering principle baked in: **workbench wraps ai-ralph; workbench never re-implements ralph internals.** Ralph owns planning, the workspace loop, parallelism, and PR creation.
- `scripts/ralph-plan.sh` resolves mode (CLI > env `WB_RALPH_PLAN_MODE` > `project.conf RALPH_PLAN_MODE` > auto-detect > workspace default). Workspace mode: one `ralph-plan --workspace` at `$WB_ROOT/repos/` with `--engine devin --thinking ultra` defaults. Per-repo fallback retained.
- `scripts/ralph-dispatch.sh` is a thin wrapper over `ralph --workspace --parallel N` (default `N = min(len(REPOS), 4)`). `--status` wraps `gh pr list` + ralph worker log tail. Exports `WORKSPACE_ROOT`.
- Deleted `scripts/ralph-loop.sh` and `wb.ralph-loop`. Single-repo debug is a documented one-liner.
- New: `scripts/ralph-enable-check.sh` preflight. `wb.ralph-enable-check` alias.
- Artifact routing: `scripts/artifact-schema.json` + `scripts/validate-artifact.py` enforce `target_repos:` on eight routed types (prd, eng-spec, tdd, erd, bdd, test-cases, test-spec, test-erd). `lifecycle.py` invokes the validator at both `publish` and `approve`. `sync-context.sh` filters to `target_repos` and warns (broadcasts) only for non-routed types.
- M4 drift footer: `scripts/steering-overlays.py --footer` emits the markdown. `sync-context.sh` writes it into `$WB_ROOT/repos/.ralph/pr_footer.md` when the overlay set is non-empty; ralph-side `pr_manager.sh` (companion ai-ralph PR `feat/pr-footer-append`) appends it to every PR body. Post-hoc fallback `scripts/ralph-annotate-prs.sh` + `wb.ralph-annotate` is the safety net while the ralph binary is rolled out on workbench machines.
- Seven skills updated with `target_repos` frontmatter / Gherkin header + prompt step sourcing from `project.conf REPOS`: `prd-draft`, `eng-spec`, `tdd`, `erd`, `bdd-gen`, `test-cases-gen`, `test-spec`.
- Seven new steering rules (`PRD-007`, `ESPEC-007`, `TDD-006`, `ERD-001`, `BDD-007`, `TC-005`, `TSPEC-006`). `artifact:erd` scope added to `steering/config.yaml`.
- `project.conf.template`: `RALPH_PLAN_MODE=auto`, `RALPH_PLAN_ENGINE=devin`, `RALPH_PLAN_THINKING=ultra`, `WB_RALPH_PARALLEL=""`.
- Docs: `CLAUDE.md` ralph quick reference + new hard rules; `README.md` "Multi-repo execution with ralph" section.
- Smoke 13 → 22 assertions.
- Companion ai-ralph PRs merged: `feat/workspace-plan-mode` (adds `ralph-plan --workspace`), `feat/pr-footer-append` (`pr_manager.sh` appends `.ralph/pr_footer.md`). Once the pr_footer support is installed on every workbench machine, `wb.ralph-annotate` can be retired.

---

## What's open (pick one to kick off next session)

### R1. Smoke regression — README missing F2 strings — **DONE** 2026-05-28
- Fixed via Fix-A: added `### Stamped-wb bootstrap` subsection to `README.md` (after the Multi-repo ralph block) carrying the three verbatim strings, and widened `tests/smoke.sh:799` regex to `((wb\.upgrade|update\.wb).*migrat|...)` so the assertion tracks the `update.wb`→`wb.upgrade` rename instead of freezing the deprecated alias.
- Smoke now green (76 assertions). steering-lint clean. **Uncommitted** — needs a worktree-PR to both remotes.

### R2. inv remote URL via SSH alias
- `git remote get-url inv` returns `git@github.com-atv:Invenco-Cloud-Systems-ICS/ai-workbench.git` (SSH host alias `github.com-atv` for Invenco identity).
- Direct `git fetch inv` fails with `Permission denied (publickey)` on this machine — the SSH config block for `github.com-atv` is missing or its key is not loaded. `gh` API access also fails for the inv repo until you `gh auth switch -u amit-tiwari_vnt` (see top of file).
- Fix: confirm `~/.ssh/config` has `Host github.com-atv` block pointing at the Invenco SSH key, or rewrite the inv remote URL to use HTTPS + gh credential helper. Not blocking shipping on origin.

### C. New feature brainstorm (carried over)
- User raised wanting to "suggest more features" after Plan D shipped; subsequently shipped: steering V1 + V2, ralph adapter V1 + V2, multi-wb resolution, versioning, precision-mode, implicit grill, /wtd, /precise-readme. Nothing new captured yet.
- Expected shape: user lists ideas, Claude grills each via `/grill-me` (one decision at a time) before any implementation. Start by asking user to list features, loop one at a time.

### Q. QA-skill PRs from `shaalinis` parked on inv (P1, awaiting review)
Five inv-side PRs from QA collaborator `shaalinis` sitting open up to 19 days. None replicated on origin yet. After `gh auth switch -u amit-tiwari_vnt`:

- **inv#37** (2026-05-08) — `bdd-gen` updated for layer awareness, performance, impact-area scenarios.
- **inv#43** (2026-05-11) — `test-cases-gen` Zephyr-aligned columns, AC traceability, ISTQB techniques, consolidation rule, self-review (closes #42).
- **inv#45** (2026-05-11) — `test-spec` reads automation repo + existing tests, refuses gracefully for all-manual, architectural coverage matrix, AC→TC→entry-point traceability, self-review (closes #44).
- **inv#59** (2026-05-17) — `test-plan-gen`: new QA strategic-plan skill between `/bdd-gen` and `/test-cases-gen` (closes #58).
- **inv#68** (2026-05-18) — `wb.zephyr-export`: convert approved test-cases to Zephyr-importable CSV (closes #69).

Decision needed per PR: review + merge as-is, request changes, or fork onto origin first. Order of leverage: 37 → 43 → 45 → 59 → 68 (later builds on earlier where they touch shared skills).

### G. v2.0.0 readiness audit (proposed)
- Six minor releases shipped between 2026-05-13 and 2026-05-19 (1.1.0 → 1.6.0). Surface area now covers steering V2, ralph adapter V2, multi-wb resolution, versioning, precision-mode, implicit grill, /wtd, /precise-readme, dispatch engine routing, continuous mode, wb-root stub purge.
- Worth a `wb.upgrade` dry-run audit across the inv stamped wbs (via `gh search` by topic `ai-workbench` per memory `project_wb_discovery.md`) to catch fields that broke compatibility. Decide whether to cut v2.0.0 with the breaking changes batched, or keep stacking minors.

### D/E/F. Steering V2 / Ralph adapter V2 / Stamped-wb ralph bootstrap — all **DONE**
Detail moved to `## What shipped`. D1/D2/D3/D4 shipped 2026-04-29; E1/E2/E3/E4/E5 shipped between 2026-04-27 and 2026-05-08; F1/F2/F3 shipped 2026-04-27.

---

## Key files and paths

| What | Path |
|---|---|
| Template source | `/Users/amittiwari/Projects/Tools-Utilities/ai-workbench/` |
| Devkit source | `/Users/amittiwari/Projects/Tools-Utilities/ai-devkit/` |
| Ralph source | `/Users/amittiwari/Projects/Tools-Utilities/ai-ralph/` |
| Working scratch (docs, plans) | `/Users/amittiwari/Projects/harness/` (not a git repo) |
| Manifest (what `update.wb` overwrites) | `.workbench-manifest.json` |
| Smoke test | `tests/smoke.sh` (run: `bash tests/smoke.sh`) |
| GitHub Pages site (manual-enable pending) | `docs/` — Jekyll + Cayman theme |

---

## GitHub Pages — DONE 2026-05-07

Enabled by user. Site live at expected URL.

---

## Sanity checks for next session

```bash
cd /Users/amittiwari/Projects/Tools-Utilities/ai-workbench
git pull --rebase origin main
bash tests/smoke.sh                 # currently FAILS at 9o2 (README missing F2 strings); see R1
git log --oneline -5                # head should be 646c475 (release 1.6.0) or later
git remote -v                       # origin (amit-t) + inv (Invenco-Cloud-Systems-ICS, via SSH alias github.com-atv)
gh auth status                      # confirm both amit-t + amit-tiwari_vnt accounts; switch via `gh auth switch -u amit-tiwari_vnt` for inv repo access
python3 scripts/steering-load.py golden | head -5        # loader sanity
python3 scripts/steering-lint.py                          # linter sanity
python3 scripts/steering-overlays.py --list               # overlay summary
cat version.json                                          # currently 1.6.0
```

If smoke fails at 9o2: see R1 (precision-mode README rewrite regression). Fix-A is a compact bootstrap subsection re-add to `README.md`.

For other smoke failures, bisect against `5ae20f6` (ralph-adapter merge), `00ac061` (steering merge), `fd4e794` (lifecycle polish merge), `bbacea5` (precision-mode skill install), `34e880d` (implicit grill wiring), `a0b77a2` (dispatch engine routing), or `8ba2d69` (wb-root .ralph stub purge).

---

## Conventions to keep

- No em dashes. Plain commas / parentheses. (Code blocks are exempt.)
- Every agent-generated artifact starts `status: draft`. Humans run `wb.publish` / `wb.approve`.
- Never edit files listed in `.workbench-manifest.json` `user_owned` from a template-dev session.
- Never write into `repos/*` from the workbench — ralph's job.
- **Never re-implement ralph internals inside workbench scripts.** Workbench wraps; ralph owns enable, loop, parallelism, and PR creation.
- Every PRD, eng-spec, TDD, ERD, BDD, test-cases, test-spec, and test-erd must declare `target_repos:`. The validator blocks `wb.publish` and `wb.approve` otherwise.
- Commit messages: plain English, no hype words.
