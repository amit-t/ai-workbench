# Session handoff — ai-workbench template development

> This file is for **template-development work on the ai-workbench repo itself**, not for stamped workbench instances. If you are in a stamped workbench (one created by `init.wb`), ignore this file.
>
> **New Claude Code session starting here?** Read this top-to-bottom before doing anything. Then read `CHANGELOG.md` for detail on what has shipped.

**Last session:** 2026-04-25 (main at `5ae20f6` on origin / `5136f0d` on inv; ralph adapter V1 merged on both remotes; companion ai-ralph PRs `feat/workspace-plan-mode` and `feat/pr-footer-append` merged).
**Branch:** `main`. **Remotes:** `origin → amit-t/ai-workbench`, `inv → Invenco-Cloud-Systems-ICS/ai-workbench`.
**Commit identity in use:** `user.name=amit-t`, `user.email=tiwari.m.amit@gmail.com` (personal). Set local `user.email=amit.tiwari@invenco.com` before committing if you want Invenco attribution on template-dev commits.
**Main branch protection:** PR required, admin bypass enabled, no force-push, no deletion.
**gh accounts:** two logged in (`amit-t` active by default, `amit-tiwari_vnt` for Invenco). Use `gh auth switch -u amit-tiwari_vnt` before any PR create/merge on `Invenco-Cloud-Systems-ICS/ai-workbench`, and switch back after.

---

## What shipped

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

1. Remaining 12 skills get step 0 + `relevant_topics` frontmatter (adr, erd, epic-intake, figma-pull, ds-screen-gen, design-draft, design-review, grill-me, prd-review-panel, pmo-status skill-side, ralph-workspace-plan, ralph-dispatch).
2. Wb-side CI lint workflow (currently only the template repo runs steering-lint in CI; wb-side workflow should be seeded by `update.wb` so PRs on stamped wbs also validate).
3. `wb.steering-audit` command. Useful diffs: which template rules a team has touched, age of overlays, last-updated dates, suggest-promotion-candidates heuristic (override used for more than one epic).
4. Loader cache under `.workbench-state/steering-cache/`. Invalidate on mtime change. Cheap; only matters at scale.

### E. Ralph adapter V2 polish (new)
Follow-ups to the V1 ship that deserve their own PRs:

1. Parallel planning in `ralph-plan --workspace` (upstream ralph). V1 plan is sequential per repo; for 4+ repos this is the bottleneck.
2. Upstream ralph support for a `--repos <subset>` filter in `ralph --workspace`, so `wb.ralph-dispatch --repos a,b` becomes meaningful without pre-editing `fix_plan.md`.
3. `wb.ralph-plan --replan <repo>` — regenerate one repo's section of `repos/.ralph/fix_plan.md` without blowing away other repos' state.
4. Wire `ralph-workspace-plan` and `ralph-dispatch` skills to the rewritten aliases; their SKILL.md bodies still reference pre-adapter flags.

### B. Plan B ralph adapter — **DONE** (this session)

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

## GitHub Pages — still pending (user action)

`https://github.com/amit-t/ai-workbench/settings/pages` → Source: **Deploy from branch** → `main` + `/docs` → Save.
Expected URL after enable: `https://amit-t.github.io/ai-workbench/`.

---

## Sanity checks for next session

```bash
cd /Users/amittiwari/Projects/Tools-Utilities/ai-workbench
git pull --rebase origin main
bash tests/smoke.sh                 # must print "PASSED" (22/22)
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
