# Session handoff — ai-workbench template development

> This file is for **template-development work on the ai-workbench repo itself**, not for stamped workbench instances. If you are in a stamped workbench (one created by `init.wb`), ignore this file.
>
> **New Claude Code session starting here?** Read this top-to-bottom before doing anything. Then read `CHANGELOG.md` for detail on what has shipped.

**Last session:** 2026-04-29. Plan D1, D2, D3, D4 all shipped today via parallel ralph autonomous loops (`rpc.p 5`). D1 (remaining 12 skills get Step 0 + `relevant_topics` frontmatter; PR #17). D2 (wb-side CI lint workflow seeded by `update.wb`; adds `.github/workflows/wb-ci.yml` + `scripts/wb-ci-validate.py`; smoke 29/29 → 35/35; PR #18). D3 (`wb.steering-audit` command; `scripts/steering-audit.py` surfaces overlay kind, targets, age, last-updated, promote-suggest heuristic; smoke 29/29 → 33/33; PR #16). D4 (steering loader mtime cache; smoke 29/29 → 35/35; PR #15). Earlier today: Plan E5 (upstream-ralph `--repos <subset>` filter design doc at `notes/upstream-ralph-v2/repos-subset-filter.md`) shipped via ralph autonomous loop on worktree branch `ralph-devin/E5`. Previous session: 2026-04-27. Ralph self-host at template-dev root shipped; Plan E1 (skill bodies) shipped via ralph autonomous loop (PRs amit-t/ai-workbench#12, Invenco-Cloud-Systems-ICS/ai-workbench#13, both draft, awaiting human merge); Plan F1 (stamped-wb ralph bootstrap in ai-devkit) shipped on `dev` branch awaiting PRs.
**Branch:** `dev` (work in flight). Previous session: 2026-04-25 (main at `5ae20f6` on origin / `5136f0d` on inv; ralph adapter V1 merged; companion ai-ralph PRs `feat/workspace-plan-mode` + `feat/pr-footer-append` merged).
**Remotes:** `origin → amit-t/ai-workbench`, `inv → Invenco-Cloud-Systems-ICS/ai-workbench`.
**Commit identity in use:** `user.name=amit-t`, `user.email=tiwari.m.amit@gmail.com` (personal). Set local `user.email=amit.tiwari@invenco.com` before committing if you want Invenco attribution on template-dev commits.
**Main branch protection:** PR required, admin bypass enabled, no force-push, no deletion.
**gh accounts:** two logged in (`amit-t` active by default, `amit-tiwari_vnt` for Invenco). Use `gh auth switch -u amit-tiwari_vnt` before any PR create/merge on `Invenco-Cloud-Systems-ICS/ai-workbench`, and switch back after.

---

## What shipped

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

### C. New feature brainstorm
- User raised wanting to "suggest more features" after Plan D shipped; steering V1 and the ralph adapter shipped since. Nothing captured yet.
- Expected shape: user lists ideas, Claude grills each (one decision at a time) before any implementation. Start by asking the user to list the features, then loop one at a time.

### D. Steering V2 polish
Parked items from the V1 ship, ordered by leverage:

1. ~~Remaining 12 skills get step 0 + `relevant_topics` frontmatter (adr, erd, epic-intake, figma-pull, ds-screen-gen, design-draft, design-review, grill-me, prd-review-panel, pmo-status skill-side, ralph-workspace-plan, ralph-dispatch).~~ **DONE** 2026-04-29 (Plan D1 above). PRs: amit-t/ai-workbench#17, Invenco-Cloud-Systems-ICS/ai-workbench#18.
2. ~~Wb-side CI lint workflow seeded by `update.wb` so PRs on stamped wbs also validate.~~ **DONE** 2026-04-29 (`.github/workflows/wb-ci.yml` + `scripts/wb-ci-validate.py`). PRs: amit-t/ai-workbench#18, Invenco-Cloud-Systems-ICS/ai-workbench#19.
3. ~~`wb.steering-audit` command. Useful diffs: which template rules a team has touched, age of overlays, last-updated dates, suggest-promotion-candidates heuristic (override used for more than one epic).~~ **DONE** 2026-04-29 (`scripts/steering-audit.py`, smoke 29/29 → 33/33). PRs: amit-t/ai-workbench#16, Invenco-Cloud-Systems-ICS/ai-workbench#17.
4. ~~Loader cache under `.workbench-state/steering-cache/`. Invalidate on mtime change. Cheap; only matters at scale.~~ **DONE** 2026-04-29 (`scripts/steering-load.py`, `.gitignore`, smoke 29/29 to 35/35). PRs: amit-t/ai-workbench#15, Invenco-Cloud-Systems-ICS/ai-workbench#16.

### E. Ralph adapter V2 polish
Follow-ups to the V1 ship that deserve their own PRs (E1 done 2026-04-27, see PRs #12 / #13):

Reconciled with `main` (parallel ralph autonomous run shipped E1, E2, E4 under different numbering; E3 in flight; E5 cherry-picked into `dev`). Remaining work:

1. ~~Retire `wb.ralph-annotate` once every developer's installed `ralph` binary carries the `pr-footer-append` change. Simplify `sync-context.sh` accordingly and drop the alias.~~ **DONE** 2026-04-27 on `main` (commit 5e85e99 / 48e2929).
2. ~~Parallel planning in `ralph-plan --workspace` (upstream ralph). Design doc only.~~ **DONE** 2026-04-27 on `main` (commit 37db5fb / ca78837 → `notes/upstream-ralph-v2/parallel-planning.md`). Upstream PRs raised 2026-05-07: amit-t/ai-ralph#47 (main), #48 (dev); Invenco-Cloud-Systems-ICS/ai-ralph#13 (main), #14 (dev).
3. ~~Upstream ralph support for a `--repos <subset>` filter in `ralph --workspace`.~~ **DONE** 2026-04-29 (`notes/upstream-ralph-v2/repos-subset-filter.md`). Pure design doc; covers allowlist + denylist flags, `discover_workspace_repos()` chokepoint, cross-repo skip default, env passthrough, back-compat snapshot. Upstream PRs raised 2026-05-07: amit-t/ai-ralph#49 (main), #50 (dev); Invenco-Cloud-Systems-ICS/ai-ralph#15 (main), #16 (dev).
4. ~~`wb.ralph-plan --replan <repo>`.~~ **DONE** 2026-04-27 on `main` (commit 37c9d1c / fa8dafb).
5. ~~Wire `ralph-workspace-plan` and `ralph-dispatch` skill bodies to V1 aliases.~~ **DONE** 2026-04-27 cherry-picked onto `dev` from ralph branch `ralph-claude/e1-skill-rewiring` as commit 39bff2a (consolidated into Plan F PR; original ralph PRs #12/#13 closed).

### F. Stamped-wb ralph bootstrap — **DONE** (2026-04-27)

1. ~~ai-devkit `init.wb` + `join.wb` install ralph globally during preflight, ensure `repos/` exists, purge `template_dev_only` artifacts, and run `ralph enable --workspace` at `repos/`.~~ **DONE** 2026-04-27.
2. ~~Refresh `README.md` "Multi-repo execution with ralph" section to mention init.wb's bootstrap step explicitly.~~ **DONE** 2026-04-27.
3. ~~Add an `update.wb` migration that detects an old stamped wb missing `repos/.ralph/` and runs `ralph enable --workspace` once. Idempotent.~~ **DONE** 2026-04-27 (devkit `update.zsh` post-sync block).

Smoke 22/22 → 27/27.

### B. Plan B ralph adapter — **DONE** (2026-04-25)

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
bash tests/smoke.sh                 # must print "PASSED" (29/29)
git log --oneline -5                # confirm the ralph-adapter merge (5ae20f6 or later) is present
git remote -v                       # origin + inv both present
python3 scripts/steering-load.py golden | head -5        # loader sanity
python3 scripts/steering-lint.py                          # linter sanity
python3 scripts/steering-overlays.py --list               # overlay summary
```

If smoke fails, bisect against `5ae20f6` (ralph-adapter merge) or `00ac061` (steering merge) or `fd4e794` (lifecycle polish merge).

---

## Conventions to keep

- No em dashes. Plain commas / parentheses. (Code blocks are exempt.)
- Every agent-generated artifact starts `status: draft`. Humans run `wb.publish` / `wb.approve`.
- Never edit files listed in `.workbench-manifest.json` `user_owned` from a template-dev session.
- Never write into `repos/*` from the workbench — ralph's job.
- **Never re-implement ralph internals inside workbench scripts.** Workbench wraps; ralph owns enable, loop, parallelism, and PR creation.
- Every PRD, eng-spec, TDD, ERD, BDD, test-cases, test-spec, and test-erd must declare `target_repos:`. The validator blocks `wb.publish` and `wb.approve` otherwise.
- Commit messages: plain English, no hype words.
