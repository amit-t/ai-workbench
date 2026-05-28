# Ralph Fix Plan — ai-workbench template-dev

Source of truth for parked work. Ordered by leverage within each plan.
Last reseeded: 2026-05-27 from `SESSION-HANDOFF.md` "What's open" section.

## High Priority — Plan R. Regressions

- [x] **R1.** Smoke 9o2 README F2 strings. **DONE** 2026-05-28 via Fix-A: `README.md` `### Stamped-wb bootstrap` subsection re-added (three verbatim strings) + `tests/smoke.sh:799` regex widened to accept `wb.upgrade` (canonical) alongside `update.wb` (deprecated). Smoke green (76 assertions), steering-lint clean. **Uncommitted** — needs worktree-PR to both remotes.

- [ ] **R2.** inv remote SSH config absent on this machine. `git fetch inv` returns `Permission denied (publickey)` because `~/.ssh/config` lacks the `Host github.com-atv` block (or its key is not loaded). Workaround: `gh auth switch -u amit-tiwari_vnt` for API access. **Not loopable** (machine-specific config; out of repo).

## Discussion (not auto-loopable) — Plan C. New feature brainstorm

Plan C is human-driven grilling, not autonomous implementation. Skip in unattended ralph runs.

- [ ] **C1.** User to list candidate features. Drive via `/grill-me` skill: one decision at a time, resolve each branch before moving on. Do not spec or implement anything from C in an autonomous loop.

## Discussion (not auto-loopable) — Plan Q. QA-skill PRs parked on inv

QA collaborator `shaalinis` has 5 PRs open on inv up to 19 days (none replicated on origin). Reviewing them is a human-judgment call (skill body changes, contract changes for /bdd-gen, /test-cases-gen, /test-spec; new skills /test-plan-gen, /wb.zephyr-export). Skip in autonomous loops.

- [ ] **Q1.** inv#37 — `bdd-gen` layer awareness + performance + impact-area scenarios.
- [ ] **Q2.** inv#43 — `test-cases-gen` Zephyr-aligned columns + AC traceability + ISTQB + consolidation + self-review.
- [ ] **Q3.** inv#45 — `test-spec` reads automation repo + traceability + self-review.
- [ ] **Q4.** inv#59 — `/test-plan-gen` new QA strategic-plan skill.
- [ ] **Q5.** inv#68 — `wb.zephyr-export` test-cases → Zephyr CSV.

Order of leverage: Q1 → Q2 → Q3 → Q4 → Q5 (later PRs build on earlier in shared skills).

## Discussion (not auto-loopable) — Plan G. v2.0.0 readiness audit

- [ ] **G1.** Six minor releases shipped 2026-05-13 → 2026-05-19 (1.1.0 → 1.6.0). Audit whether to batch v2.0.0 with breaking changes (dispatch engine routing default flips, wb-root .ralph purge, multi-wb resolution) or continue stacking minors. Sample stamped wbs via `gh search` by topic `ai-workbench`; dry-run `wb.upgrade` against each. **Not loopable** (human decision on compatibility scope + release timing).

## Done — moved out of active queue

- [x] **Plan B.** Ralph adapter V1 (shipped 2026-04-25).
- [x] **Plan D1.** Remaining 12 skills get Step 0 + `relevant_topics`. **DONE** 2026-04-29. PRs amit-t#17, inv#18.
- [x] **Plan D2.** Wb-side CI lint workflow. **DONE** 2026-04-29. PRs amit-t#18, inv#19.
- [x] **Plan D3.** `wb.steering-audit`. **DONE** 2026-04-29. PRs amit-t#16, inv#17.
- [x] **Plan D4.** Steering loader mtime cache. **DONE** 2026-04-29. PRs amit-t#15, inv#16.
- [x] **Plan E1.** Wire `ralph-workspace-plan` + `ralph-dispatch` skill bodies to V1 aliases. **DONE** 2026-04-27 (commit `39bff2a`, cherry-picked into Plan F PR).
- [x] **Plan E2.** Retire `wb.ralph-annotate`. **DONE** 2026-04-27 (commits `5e85e99`/`48e2929`).
- [x] **Plan E3.** Parallel planning in `ralph-plan --workspace`. **DONE** 2026-05-08 end-to-end (upstream amit-t/ai-ralph#53/#54 + inv#19/#20; workbench wiring PRs amit-t#20/#21 + inv#34/#35).
- [x] **Plan E4.** `wb.ralph-plan --replan <repo>`. **DONE** 2026-04-27 (commits `37c9d1c`/`fa8dafb`).
- [x] **Plan E5.** Upstream-ralph `--repos <subset>` filter. **DONE** 2026-05-08 end-to-end (upstream amit-t/ai-ralph#51/#52 + inv#17/#18; workbench wiring same PRs as E3).
- [x] **Plan F1.** ai-devkit `init.wb` + `join.wb` ralph bootstrap. **DONE** 2026-04-27 (workbench `239936b`, devkit `480d286`).
- [x] **Plan F2.** README "Multi-repo execution with ralph" refresh. **DONE** 2026-04-27. (⚠️ Subsequently regressed by R1.)
- [x] **Plan F3.** `update.wb` migration for old stamped wbs missing `repos/.ralph/`. **DONE** 2026-04-27 (devkit `update.zsh`).
- [x] **Versioning template-side wiring.** `version.json` + aliases preamble + `wb.upgrade`/`ralph.upgrade`/`devkit.upgrade` + `devkit doctor`. **DONE** 2026-05-09. PRs amit-t#22/#23.
- [x] **Wb-side version notification pages.** **DONE** 2026-05-11. PR amit-t#24.
- [x] **Multi-workbench resolution.** `_wb_resolve_root` + `wb.switch`/`wb.unswitch`/`wb.where`. **DONE** 2026-05-13. PRs amit-t#25/#26 → release v1.1.0 (#32).
- [x] **WSL/Windows port hardening (workbench leg).** Shell-lint matrix + `.gitattributes` + E2E onboarding smoke. **DONE** 2026-05-13. PRs amit-t#28/#29/#30/#31.
- [x] **Repo-context-scan auto-run + `wb.rescan`.** **DONE** 2026-05-13. PRs amit-t#27/#33 → release v1.2.0 (#34).
- [x] **`wb.rescan` brick fix.** Permission-mode, flag order, stdout leak. **DONE** 2026-05-14. PR amit-t#35 → release v1.2.1 (#36).
- [x] **Implicit grill into 9 draft skills + grill-substrate package.** **DONE** 2026-05-15. PRs amit-t#37/#38 + inv#49/#50 → release v1.3.0 (#39).
- [x] **Precision-mode skill install + wire into 9 draft hosts.** **DONE** 2026-05-15. PRs amit-t#40/#41 → release v1.4.0 (#42).
- [x] **Ralph V2 passthrough (workbench leg).** `wb.ralph-dispatch --repos`/`--exclude`, `wb.ralph-plan --parallel-plan N`. **DONE** 2026-05-08. PRs amit-t#20/#21 + inv#34/#35.
- [x] **Dispatch engine binary routing + plan/exec split.** `--engine <claude|devin|codex>` → `ralph`/`ralph-devin`/`ralph-codex`. **DONE** 2026-05-18 (commits `a0b77a2`/`ab86496`).
- [x] **Dispatch continuous-mode passthrough.** `--parallel N --max-tasks M` + `--max-task-attempts`/`--respawn-delay`/`--no-tabs`. **DONE** 2026-05-15 (commit `3cc85e2`).
- [x] **Wb-root `.ralph/` stub purge.** Manifest `template_dev_only` + `ralph-enable-check` guard + `wb.upgrade` backup. **DONE** 2026-05-18 (commits `8ba2d69`/`02ed649`).
- [x] **`/wtd` what-to-do recommender + workflows GH-Pages page.** **DONE** 2026-05-18. PRs amit-t#43/#44.
- [x] **`/precise-readme` skill + per-skill GH-Pages catalogue.** **DONE** 2026-05-18. PRs amit-t#47/#48.
- [x] **Workflows.md precision-mode pass.** **DONE** 2026-05-18. PRs amit-t#49/#50.
- [x] **README precision-mode pass + V1 archive at `/v1/`.** **DONE** 2026-05-18. PRs amit-t#45/#46. (⚠️ Caused R1.)
- [x] **`wrd.p` devin-parallel shorthand.** **DONE** 2026-05-19. PR amit-t#53 → release v1.6.0 (#54).

## Notes

- R1 is the highest-leverage low-risk item: pure docs edit; restores smoke green.
- Plan C and G are human-only — if ralph picks them, exit clean with `STATUS: BLOCKED`, `EXIT_SIGNAL: true`, `RECOMMENDATION: human-input-required`.
- Companion `ai-ralph` PRs land first; surface in workbench second. See PROMPT.md "Cross-Repo Routing".
- Update this file at the end of every loop. Move done items to `## Done` with PR URL appended.
