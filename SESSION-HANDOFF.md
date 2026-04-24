# Session handoff — ai-workbench template development

> This file is for **template-development work on the ai-workbench repo itself**, not for stamped workbench instances. If you are in a stamped workbench (one created by `init.wb`), ignore this file.
>
> **New Claude Code session starting here?** Read this top-to-bottom before doing anything. Then read `CHANGELOG.md` and `docs/superpowers/plans/PARKED-plan-D-remaining-skills.md` for details.

**Last session:** 2026-04-24 (main at `fd4e794`, lifecycle polish merged on `origin`; `inv` PR #1 still open, awaiting batch merge by user).
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
- Smoke still 9/9, now exercising the BDD path.
- Merged to `origin/main` as PR #1 (head commit `fd4e794`). `inv` PR #1 is open, awaiting batch merge.

---

## What's open (do next)

### Batch merge on `inv`
- [ ] Merge all pending PRs on `Invenco-Cloud-Systems-ICS/ai-workbench` together. Currently open: `inv` PR #1 (lifecycle polish, branch `lifecycle-polish`). Requires `gh auth switch -u amit-tiwari_vnt` first.
- [ ] After merge: `git fetch inv && git log inv/main..origin/main` to confirm the two remotes are in sync. They should be byte-identical on `main`.

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
