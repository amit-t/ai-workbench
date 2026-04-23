# Session handoff — ai-workbench template development

> This file is for **template-development work on the ai-workbench repo itself**, not for stamped workbench instances. If you are in a stamped workbench (one created by `init.wb`), ignore this file.
>
> **New Claude Code session starting here?** Read this top-to-bottom before doing anything. Then read `CHANGELOG.md` and `docs/superpowers/plans/PARKED-plan-D-remaining-skills.md` for details.

**Last session:** 2026-04-23 (commit `178434a`).
**Branch:** `main`. **Remotes:** `origin → amit-t/ai-workbench`, `inv → Invenco-Cloud-Systems-ICS/ai-workbench`.
**Commit identity for pushes here:** `user.email=amit.tiwari@invenco.com`, `user.name=amit-tiwari_vnt` (local config; already set).
**Main branch protection:** PR required, admin bypass enabled, no force-push, no deletion.

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

### Phase 2 — Plan D (this session, 2026-04-23)
- Remaining 9 skill bodies: `grill-me`, `prd-review-panel`, `pmo-status`, `adr`, `erd`, `figma-pull`, `ds-screen-gen`, `design-draft`, `design-review`.
- All skills: three-stage lifecycle aware; house structure (When to use / Prerequisites / Steps / Output contract / Do not); concrete example in at least one step.
- `wb.rejected` lister added for symmetry.
- Smoke test still 9/9.

---

## What's open (do next)

### Lifecycle polish (highest leverage, small)
- [ ] **Extract `scripts/lifecycle.py`.** Collapse the three Python heredocs in `aliases.sh` into a single `scripts/lifecycle.py publish|approve|reject|list` CLI. Gives one file to unit-test and one place to add BDD support.
- [ ] **BDD `.feature` lifecycle support.** `wb.publish` only handles YAML frontmatter. Gherkin files use `# status: draft` header comments. Add a handler to `lifecycle.py`; then re-enable the BDD case that was swapped out of `tests/smoke.sh`.
- [ ] **Lockfile for concurrency.** `.workbench-state/*.json` is currently last-writer-wins. Add an advisory flock on `.workbench-state/.lock` around the read-modify-write cycle.
- [ ] **Approved-folder audit.** `grep -r "prds/approved" skills/ scripts/ docs/` — confirm no stragglers from Phase 1.

### Plan B — ralph adapter (still parked)
- Finalize `scripts/ralph-plan.sh` workspace-mode flag once `ai-ralph` PR #3 merges.
- Check status before starting: `gh pr view 3 --repo <ai-ralph-remote>`.

### Features (pending user input)
User said they want to **suggest more features** after Plan D shipped. I am supposed to **grill hard** on each. Nothing captured yet — ask them to list features before doing anything.

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
bash tests/smoke.sh                 # must print "PASSED"
git log --oneline -5                # confirm last commit is 178434a or later
git remote -v                       # origin + inv both present
```

If smoke fails, bisect against `178434a`.

---

## Conventions to keep

- No em dashes. Plain commas / parentheses. (Code blocks are exempt.)
- Every agent-generated artifact starts `status: draft`. Humans run `wb.publish` / `wb.approve`.
- Never edit files listed in `.workbench-manifest.json` `user_owned` from a template-dev session.
- Never write into `repos/*` from the workbench — ralph's job.
- Commit messages: plain English, no hype words.
