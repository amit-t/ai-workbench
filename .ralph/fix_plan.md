# Ralph Fix Plan — ai-workbench template-dev

Source of truth for parked work. Ordered by leverage within each plan.
Last seeded: 2026-04-27 from `SESSION-HANDOFF.md` "What's open" section.

## High Priority — Plan E. Ralph adapter V2 polish

Reconciled with `main` after merge: ralph autonomous loops on `main` shipped multiple Plan E items in parallel under different numbering. Consolidated status:

- [x] **E1 (mine).** Wire `ralph-workspace-plan` and `ralph-dispatch` skill bodies to V1 aliases. **DONE** 2026-04-27 (commit `39bff2a`, cherry-picked from ralph branch into Plan F PR; original ralph PRs #12/#13 closed).
- [x] **E2.** Retire `wb.ralph-annotate` post-hoc fallback. **DONE** 2026-04-27 on `main` (commits `5e85e99` / `48e2929`).
- [x] **E3.** Upstream-ralph parallel-planning design doc. **DONE** 2026-04-27 on `main` (commits `37db5fb` / `ca78837` → `notes/upstream-ralph-v2/parallel-planning.md`). Upstream PRs raised 2026-05-07: amit-t/ai-ralph#47 (main), #48 (dev); Invenco-Cloud-Systems-ICS/ai-ralph#13 (main), #14 (dev). Doc copied into `docs/proposals/parallel-planning.md` on branch `docs/parallel-planning-v2`.
- [x] **E4.** `wb.ralph-plan --replan <repo>`. **DONE** 2026-04-27 on `main` (commits `37c9d1c` / `fa8dafb`).
- [x] **E5.** Upstream-ralph `--repos <subset>` filter for `ralph --workspace`. **DONE** 2026-04-29 (`notes/upstream-ralph-v2/repos-subset-filter.md`). Doc covers allowlist + denylist flags, `discover_workspace_repos()` chokepoint, cross-repo skip default, env var passthrough, and the workbench follow-up surface (`wb.ralph-dispatch --repos`, `WB_RALPH_DISPATCH_REPOS` in `project.conf.template`). Smoke 22/22 still green; no behavior changes shipped (design only). Workbench PRs: amit-t/ai-workbench#14, Invenco-Cloud-Systems-ICS/ai-workbench#15. Upstream PRs raised 2026-05-07: amit-t/ai-ralph#49 (main), #50 (dev); Invenco-Cloud-Systems-ICS/ai-ralph#15 (main), #16 (dev). Doc copied into `docs/proposals/repos-subset-filter.md` on branch `docs/repos-subset-filter`.

## High Priority — Plan D. Steering V2 polish

Parked items from the steering V1 ship.

- [x] **D1.** Remaining 12 skills get step 0 (load Layer 2 steering) + `relevant_topics` frontmatter: `adr`, `erd`, `epic-intake`, `figma-pull`, `ds-screen-gen`, `design-draft`, `design-review`, `grill-me`, `prd-review-panel`, `pmo-status` (skill side), `ralph-workspace-plan`, `ralph-dispatch`. **DONE** 2026-04-29. All 18 skills now declare `relevant_topics:` and run a Step 0 "Load steering" before any other work. Pattern adapted per skill: artifact-producers call `wb.steering artifact:<type>` (forward-compat for `adr`/`epic-context`/`design` even when the steering directory is empty; the loader emits an empty merged blob without erroring); artifact-reviewers call the same scope as the artifact author; orchestrators (`ralph-workspace-plan`, `ralph-dispatch`) and read-only skills (`pmo-status`) note explicitly that Layer 2 was already enforced upstream; `grill-me` defers the load until the target type is known. Smoke 29/29 green; steering-lint clean. Critical-path 6 (not 9; the original count was off, the list of 12 above plus `prd-draft`, `eng-spec`, `tdd`, `bdd-gen`, `test-cases-gen`, `test-spec` totals 18) was already covered in Phase 2. PRs: amit-t/ai-workbench#17, Invenco-Cloud-Systems-ICS/ai-workbench#18.
- [x] **D2.** Wb-side CI lint workflow seeded by `update.wb`. **DONE** 2026-04-29. New `.github/workflows/wb-ci.yml` runs `scripts/steering-lint.py` plus `scripts/wb-ci-validate.py --stdin` on every PR that touches `product/`, `design/`, `engineering/`, `qa/`, `steering/`, or `steering.local/`. The helper maps changed files to one of ten artifact types (`prd`, `eng-spec`, `tdd`, `erd`, `adr`, `bdd`, `test-cases`, `test-spec`, `test-erd`, `epic-context`) by directory prefix and runs `validate-artifact.py` per file, catching missing `target_repos` or unregistered repos at PR time. `.github/workflows/**` is already in `template_owned`, so `update.wb` syncs the workflow into every existing stamped wb on the next run; new wbs inherit it from `gh repo create --template`. In the template repo itself `project.conf` is absent, so artifact validation is a no-op and only steering-lint runs. Smoke 29/29 → 35/35. PRs: amit-t/ai-workbench#18, Invenco-Cloud-Systems-ICS/ai-workbench#19.
- [x] **D3.** `wb.steering-audit` command. **DONE** 2026-04-29 (`scripts/steering-audit.py`). Markdown / `--json` / `--list` outputs, surfaces kind + targets + scope + owner + created + updated + age + epics_touched + promote_suggest. Heuristic: flag overrides whose scope is exercised by artifacts spanning 2+ epics; REMOVE entries are excluded. Smoke 29/29 → 33/33. PRs: amit-t/ai-workbench#16, Invenco-Cloud-Systems-ICS/ai-workbench#17.
- [x] **D4.** Loader cache under `.workbench-state/steering-cache/`. Invalidate on mtime change. Cheap, only matters at scale. **DONE** 2026-04-29 (`scripts/steering-load.py`, `.gitignore`, `tests/smoke.sh`). Cache file is `.cache` per scope, header line `# steering-cache fp:<sha256>` keyed by (relpath, st_mtime_ns, st_size) over both `steering/<rel>/*.md` and `steering.local/<rel>/*.md`. Atomic write via `.tmp` rename. Bypass via `--no-cache` flag, `WB_STEERING_NO_CACHE=1` env, or `--clear-cache`. Smoke 29/29 to 35/35. PRs: amit-t/ai-workbench#15, Invenco-Cloud-Systems-ICS/ai-workbench#16.

## High Priority — Plan F. Stamped-wb ralph bootstrap (in flight 2026-04-27)

Lift ralph-workspace bootstrap into the `ai-devkit` so stamped wbs get a working `repos/.ralph/` workspace at init time and so the template's own `.ralph/PROMPT.md` + `.ralph/fix_plan.md` (template-dev only) stop leaking into them.

- [x] **F1.** Ai-devkit `init.wb` (Step 3.1, 3.4, 3.4a, 3.4b) and `join.wb` (Step 0, 4b) install the `ralph` binary if missing, verify `--workspace` support, ensure `repos/` exists, purge `template_dev_only` artifacts from `.workbench-manifest.json`, run `ralph enable --workspace` at `repos/`, and call `scripts/ralph-enable-check.sh` to verify. `install.zsh` warns about a missing/old ralph. `.workbench-manifest.json` adds `.ralph/**` to `user_owned` and adds the new `template_dev_only` list. `CLAUDE.md` documents the rule. `tests/smoke.sh` 22/22 -> 25/25. **DONE** 2026-04-27 on `dev` (workbench commit `239936b`, devkit commit `480d286`). PRs pending.
- [x] **F2.** Refresh `README.md` "Multi-repo execution with ralph" section to mention init.wb's bootstrap step explicitly. **DONE** 2026-04-27.
- [x] **F3.** Add an `update.wb` migration step that detects an old stamped wb missing `repos/.ralph/` and runs `ralph enable --workspace` at `repos/` once. Idempotent. **DONE** 2026-04-27 (devkit `update.zsh` post-sync block).

## Discussion (not auto-loopable) — Plan C. New feature brainstorm

Plan C is human-driven grilling, not autonomous implementation. Skip in unattended ralph runs.

- [ ] **C1.** User to list candidate features. Drive via `/grill-me` skill: one decision at a time, resolve each branch before moving on. Do not spec or implement anything from C in an autonomous loop.

## Done

- [x] Plan B. Ralph adapter V1 (shipped 2026-04-25, see `CHANGELOG.md`).

## Notes

- Plan E1 is the highest-leverage low-risk item: pure docs/skill edits that prevent users from running broken commands.
- Plan E2/E3/E4/E5 require companion `ai-ralph` PRs. Land ralph-side first, then surface in workbench. See PROMPT.md "Cross-Repo Routing".
- Plan D1 is mechanical and parallelizable per skill. Good candidate for `rpc.p N` with N matching free skills.
- Plan C should never be picked by an autonomous loop. If ralph picks it, exit clean with `STATUS: BLOCKED`, `EXIT_SIGNAL: true`, `RECOMMENDATION: human-input-required`.
- Update this file at the end of every loop. Move done items to `## Done` with the PR URL appended in parentheses.
