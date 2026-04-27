# Ralph Fix Plan — ai-workbench template-dev

Source of truth for parked work. Ordered by leverage within each plan.
Last seeded: 2026-04-27 from `SESSION-HANDOFF.md` "What's open" section.

## High Priority — Plan E. Ralph adapter V2 polish

Follow-ups to the V1 ship that deserve their own PRs.

- [x] **E1.** Wire `ralph-workspace-plan` and `ralph-dispatch` skill bodies to the rewritten aliases. Their `SKILL.md` bodies still reference pre-adapter flags and will misroute users. (Shipped 2026-04-27. Both skill bodies now call `wb.ralph-plan` / `wb.ralph-dispatch`, drop the deleted `--agent`/`--repos` flags, point single-repo debug at the documented one-liner, and reflect the workspace-mode default + per-repo fallback. AGENTS.md `wb.ralph-loop` reference patched at the same time.)
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

## Discussion (not auto-loopable) — Plan C. New feature brainstorm

Plan C is human-driven grilling, not autonomous implementation. Skip in unattended ralph runs.

- [ ] **C1.** User to list candidate features. Drive via `/grill-me` skill: one decision at a time, resolve each branch before moving on. Do not spec or implement anything from C in an autonomous loop.

## Done

- [x] Plan B. Ralph adapter V1 (shipped 2026-04-25, see `CHANGELOG.md`).
- [x] Plan E1. Wire `ralph-workspace-plan` and `ralph-dispatch` skill bodies to the rewritten aliases (shipped 2026-04-27, see `CHANGELOG.md`). PRs: amit-t/ai-workbench#12, Invenco-Cloud-Systems-ICS/ai-workbench#13.

## Notes

- Plan E1 was the highest-leverage low-risk item (pure docs/skill edits that prevent users running broken commands). Shipped 2026-04-27.
- Learning from E1: the SKILL.md bodies must reference the **alias** (`wb.ralph-plan`, `wb.ralph-dispatch`), not the underlying script path. Bypassing the alias skips `wb.ralph-enable-check`, `sync-context.sh`, and the `WORKSPACE_ROOT` export — all easy to miss when running scripts directly. Dispatch skill now also calls out that `--repos` is parked on E2 (do not document a flag we have not wired).
- Plan E2/E3/E4 require companion `ai-ralph` PRs. Land ralph-side first, then surface in workbench. See PROMPT.md "Cross-Repo Routing".
- Plan D1 is mechanical and parallelizable per skill. Good candidate for `rpc.p N` with N matching free skills. Two of the twelve skills (`ralph-workspace-plan`, `ralph-dispatch`) were rewritten as part of E1 but still need the Layer 2 step 0 + `relevant_topics` frontmatter — keep them on the D1 list.
- Plan C should never be picked by an autonomous loop. If ralph picks it, exit clean with `STATUS: BLOCKED`, `EXIT_SIGNAL: true`, `RECOMMENDATION: human-input-required`.
- Update this file at the end of every loop. Move done items to `## Done` with the PR URL appended in parentheses.
