# Session handoff — ai-workbench template development

> This file is for **template-development work on the ai-workbench repo itself**, not for stamped workbench instances. If you are in a stamped workbench (one created by `init.wb`), ignore this file.
>
> **New Claude Code session starting here?** Read this top-to-bottom before doing anything. Then read `CHANGELOG.md` and `docs/superpowers/plans/PARKED-plan-D-remaining-skills.md` for details.

**Last session:** 2026-04-24 (main at `7326882`, steering system v1 merged on both remotes; companion devkit follow-up prompt was handed off for a separate ai-devkit session).
**Branch:** `main`. **Remotes:** `origin → amit-t/ai-workbench`, `inv → Invenco-Cloud-Systems-ICS/ai-workbench`.
**Commit identity in use this session:** `user.name=amit-t`, `user.email=tiwari.m.amit@gmail.com` (personal). Earlier handoff referenced the Invenco identity; local config currently resolves to the personal one. Set local `user.email=amit.tiwari@invenco.com` if you want Invenco attribution on template-dev commits.
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
- Smoke test: `tests/smoke.sh` (9 assertions, full three-stage flow).
- Hardenings: path-traversal guards, type validation, reject-from-approved, frontmatter-missing errors.

### Phase 2 — Plan D (session 2026-04-23)
- Remaining 9 skill bodies: `grill-me`, `prd-review-panel`, `pmo-status`, `adr`, `erd`, `figma-pull`, `ds-screen-gen`, `design-draft`, `design-review`.
- All skills: three-stage lifecycle aware; house structure (When to use / Prerequisites / Steps / Output contract / Do not); concrete example in at least one step.
- `wb.rejected` lister added for symmetry.

### Lifecycle polish (session 2026-04-24)
- Extracted `scripts/lifecycle.py`: single CLI with subcommands `publish | approve | reject | list`. Replaces the three Python heredocs in `aliases.sh`. `aliases.sh` collapsed to 6 one-line shell wrappers.
- BDD `.feature` lifecycle support: CLI detects `.feature` and rewrites the `# status:` header comment (instead of YAML frontmatter). BDD smoke round-trip re-enabled in `tests/smoke.sh`.
- Advisory `flock` on `.workbench-state/.lock` around every read-modify-write, removing the last-writer-wins race.
- Audited `grep -r "prds/approved"` across `skills/`, `scripts/`, `docs/`: clean.
- Artifact lifecycle section added to `README.md` (diagram, stage semantics, upstream gates, dev + QA flows, inspection aliases).
- Smoke went 9 to 9, now exercising the BDD path.
- Merged on both remotes.

### Steering system V1 (session 2026-04-24)
- New `steering/` tree (template-owned) + `steering.local/` overlay (user-owned) with structured rule files (one markdown file per rule, YAML frontmatter).
- Progressive disclosure in three layers: Layer 0 (golden) at session start, Layer 1 (role: dev / qa / po / uxd) on role-inference match, Layer 2 (artifact / topic) as step 0 of each critical-path skill.
- Loader: `scripts/steering-load.py <scope>` merges template + overlay with explicit `supersedes: [ID]` and `<ID>.removed.md` sidecar semantics. Linter: `scripts/steering-lint.py` enforces frontmatter schema, ID regex, overlay-only field placement. PostToolUse hook in `.claude/settings.json` re-emits Layer 0 after `update.wb`, `git pull`, `git merge`, or any Edit/Write under `steering/**` or `steering.local/**`.
- Drift visibility: M1 (pmo-status lists local overrides), M2 (weekly Monday GitHub Action in template repo, queries org by topic `ai-workbench`, emits digest issue via GitHub App token), M3 (promotion PRs from `steering.local/` to `steering/`). M4 (ralph PR footer) parked for the ralph adapter work.
- Aliases: `wb.steering <scope>`, `wb.steering-refresh`, `wb.steering-lint`.
- Seeded content: 60 starter rules across golden (10), roles (19), artifacts (28), topics (7). Each rule has Rule / Why / How to apply / Anti-pattern.
- Critical-path skills updated (prd-draft, eng-spec, tdd, bdd-gen, test-cases-gen, test-spec): step 0 now loads the merged steering; frontmatter gained `relevant_topics:`.
- Docs: root README section "Steering workflow" (role-split), `docs/steering/index.md` (deep), `docs/steering/setup.md` (GitHub App install steps).
- CODEOWNERS granular per-directory with `{{ORG}}` placeholders (substituted at `init.wb` stamp time, once devkit follow-up lands).
- Manifest v2 adds `steering/`, `.claude/settings.json`, `.github/workflows/**`, `.github/CODEOWNERS` as template-owned; `steering.local/` as user-owned.
- Smoke extended from 9 to 13 assertions (steering presence, loader non-empty output, overlay add + supersede + remove round-trip, lint pass).
- Merged on both remotes.

### Companion devkit follow-up (separate session, ai-devkit repo)
- Two-item handoff prompt delivered to the user for a fresh session in `ai-devkit`:
  1. `init.wb` must tag every stamped repo with the GitHub topic `ai-workbench` (required for M2 drift-digest discovery; must be org-agnostic).
  2. `update.wb` must print the count of non-empty `steering.local/` entries after a pull, with a link to the template repo's promotion PR flow.
- Status: user ran the session; result tracked in `ai-devkit` PRs.

---

## What's open (pick one to kick off next session)

Three independent streams, ordered by how much is in flight:

### B. Plan B, ralph adapter (long parked)
- Finalize `scripts/ralph-plan.sh` workspace-mode flag once `ai-ralph` PR #3 merges. Check first: `gh pr view 3 --repo <ai-ralph-remote>`. If still open, this stays parked.
- When B lands, M4 (drift footer on every ralph-authored code PR) bundles into it. The per-wb steering and overlay list already flows through `sync-context.sh` into `repos/*/ai/steering{,.local}/`; ralph just has to read it and append a footer to PR bodies.

### C. New feature brainstorm
- User said they wanted to "suggest more features" after Plan D shipped. Nothing captured yet.
- Expected shape: user lists ideas, Claude grills each (like the steering brainstorm) before any implementation. Start by asking the user to list the features, then loop one at a time.

### D. Steering V2 polish
Parked items from the V1 ship that are worth a follow-up PR in isolation:

1. Remaining 12 skills get step 0 + `relevant_topics` frontmatter (adr, erd, epic-intake, figma-pull, ds-screen-gen, design-draft, design-review, grill-me, prd-review-panel, pmo-status (skill-side rather than the M1 section), ralph-workspace-plan, ralph-dispatch).
2. Wb-side CI lint workflow (currently only the template repo runs steering-lint in CI; wb-side workflow should be seeded by `update.wb` so PRs on stamped wbs also validate).
3. `wb.steering-audit` command. Useful diffs: which template rules a team has touched, age of overlays, last-updated dates, suggest-promotion-candidates heuristic (override used for more than one epic).
4. Loader cache under `.workbench-state/steering-cache/`. Invalidate on mtime change of `steering/` or `steering.local/`. Cheap to add; only matters at scale.

---

## Key files and paths

| What | Path |
|---|---|
| Template source | `/Users/amittiwari/Projects/Tools-Utilities/ai-workbench/` |
| Devkit source | `/Users/amittiwari/Projects/Tools-Utilities/ai-devkit/` |
| Working scratch (docs, plans) | `/Users/amittiwari/Projects/harness/` (not a git repo) |
| Parked Plan D (details) | `/Users/amittiwari/Projects/harness/docs/superpowers/plans/PARKED-plan-D-remaining-skills.md` |
| Parked Plan B | `/Users/amittiwari/Projects/harness/docs/superpowers/plans/PARKED-plan-B-ralph-adapter.md` |
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
bash tests/smoke.sh                 # must print "PASSED" (13/13)
git log --oneline -5                # confirm the steering merge (8a9278c or later) is present
git remote -v                       # origin + inv both present
python3 scripts/steering-load.py golden | head -5   # loader sanity
python3 scripts/steering-lint.py                    # linter sanity
```

If smoke fails, bisect against `00ac061` (steering merge) or `fd4e794` (lifecycle polish merge).

---

## Conventions to keep

- No em dashes. Plain commas / parentheses. (Code blocks are exempt.)
- Every agent-generated artifact starts `status: draft`. Humans run `wb.publish` / `wb.approve`.
- Never edit files listed in `.workbench-manifest.json` `user_owned` from a template-dev session.
- Never write into `repos/*` from the workbench — ralph's job.
- Commit messages: plain English, no hype words.
