# Ralph Fix Plan — ai-workbench template-dev

Source of truth for parked work. Ordered by leverage within each plan.
Last seeded: 2026-04-27 from `SESSION-HANDOFF.md` "What's open" section.

## High Priority — Plan E. Ralph adapter V2 polish

Follow-ups to the V1 ship that deserve their own PRs.

- [~] **E1.** Wire `ralph-workspace-plan` and `ralph-dispatch` skill bodies to the rewritten aliases. Their `SKILL.md` bodies still reference pre-adapter flags and will misroute users.
- [ ] **E2.** Upstream-ralph: add `--repos <subset>` filter to `ralph --workspace`, then surface as `wb.ralph-dispatch --repos a,b`. Today users must pre-edit `repos/.ralph/fix_plan.md` to scope a partial dispatch.
- [ ] **E3.** Upstream-ralph: parallel planning in `ralph-plan --workspace`. V1 plans sequentially per repo; with 4+ repos this is the dispatch bottleneck.
- [ ] **E4.** Add `wb.ralph-plan --replan <repo>` that regenerates one repo's section of `repos/.ralph/fix_plan.md` without blowing away other repos' state. Companion ralph change likely needed.
- [ ] **E5.** Retire `wb.ralph-annotate` once every developer's installed `ralph` carries the `pr-footer-append` change. Simplify `sync-context.sh` and drop the alias + script.

## High Priority — Plan D. Steering V2 polish

Parked items from the steering V1 ship.

- [ ] **D1.** Remaining 12 skills get step 0 (load Layer 2 steering) + `relevant_topics` frontmatter: `adr`, `erd`, `epic-intake`, `figma-pull`, `ds-screen-gen`, `design-draft`, `design-review`, `grill-me`, `prd-review-panel`, `pmo-status` (skill side), `ralph-workspace-plan`, `ralph-dispatch`. Critical-path 9 already shipped.
- [ ] **D2.** Wb-side CI lint workflow seeded by `update.wb`. Currently only the template repo runs `steering-lint` in CI; stamped wbs need it too so PRs there validate.
- [ ] **D3.** `wb.steering-audit` command. Surface: which template rules a team has overridden, age of overlays, last-updated dates, suggest-promotion heuristic (override used across more than one epic).
- [ ] **D4.** Loader cache under `.workbench-state/steering-cache/`. Invalidate on mtime change. Cheap, only matters at scale.

## High Priority — Plan F. Stamped-wb ralph bootstrap (in flight 2026-04-27)

Lift ralph-workspace bootstrap into the `ai-devkit` so stamped wbs get a working `repos/.ralph/` workspace at init time and so the template's own `.ralph/PROMPT.md` + `.ralph/fix_plan.md` (template-dev only) stop leaking into them.

- [x] **F1.** Ai-devkit `init.wb` (Step 3.1, 3.4, 3.4a, 3.4b) and `join.wb` (Step 0, 4b) install the `ralph` binary if missing, verify `--workspace` support, ensure `repos/` exists, purge `template_dev_only` artifacts from `.workbench-manifest.json`, run `ralph enable --workspace` at `repos/`, and call `scripts/ralph-enable-check.sh` to verify. `install.zsh` warns about a missing/old ralph. `.workbench-manifest.json` adds `.ralph/**` to `user_owned` and adds the new `template_dev_only` list. `CLAUDE.md` documents the rule. `tests/smoke.sh` 22/22 -> 25/25. **DONE** 2026-04-27 on `dev` (workbench commit `239936b`, devkit commit `480d286`). PRs pending.
- [ ] **F2.** Refresh `README.md` "Multi-repo execution with ralph" section to mention init.wb's bootstrap step explicitly.
- [ ] **F3.** Add an `update.wb` migration step that detects an old stamped wb missing `repos/.ralph/` and runs `ralph enable --workspace` at `repos/` once. Keep idempotent.

## Discussion (not auto-loopable) — Plan C. New feature brainstorm

Plan C is human-driven grilling, not autonomous implementation. Skip in unattended ralph runs.

- [ ] **C1.** User to list candidate features. Drive via `/grill-me` skill: one decision at a time, resolve each branch before moving on. Do not spec or implement anything from C in an autonomous loop.

## Done

- [x] Plan B. Ralph adapter V1 (shipped 2026-04-25, see `CHANGELOG.md`).

## Notes

- Plan E1 is the highest-leverage low-risk item: pure docs/skill edits that prevent users from running broken commands.
- Plan E2/E3/E4 require companion `ai-ralph` PRs. Land ralph-side first, then surface in workbench. See PROMPT.md "Cross-Repo Routing".
- Plan D1 is mechanical and parallelizable per skill. Good candidate for `rpc.p N` with N matching free skills.
- Plan C should never be picked by an autonomous loop. If ralph picks it, exit clean with `STATUS: BLOCKED`, `EXIT_SIGNAL: true`, `RECOMMENDATION: human-input-required`.
- Update this file at the end of every loop. Move done items to `## Done` with the PR URL appended in parentheses.
