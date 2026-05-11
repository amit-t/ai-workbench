---
title: FAQ
layout: default
eyebrow: FAQ
---

## Why a Workbench per Epic Bundle, Not a Permanent Hub?

Bundles are disposable. An epic (or a small set of related epics) gets picked up, planned, shipped, then closed. A workbench matches that lifespan — start one, work in it for weeks or a quarter, archive it. A permanent team-wide hub drifts, accumulates stale context, and becomes a second Jira. This harness is explicitly throwaway.

## Do I Have to Use Devin?

No. Every devkit command has a `.cly` variant that forces Claude: `init.wb.cly`, `join.wb.cly`, `update.wb.cly`. Inside a workbench, slash commands work the same under Claude or Devin because both read the same `skills/` directory. `.dev` variants force Devin if you want to be explicit.

## What Happens If Both Dev and QA Edit `project.conf` at the Same Time?

Git merge conflict. Resolve it normally and push. The file is a shell script — conflicts usually show up as duplicated array entries, which are easy to reconcile. Pull before starting a session and push when you pause; that is the simplest way to avoid the situation.

## Can I Run Ralph Without Workspace-Mode?

Yes. `scripts/ralph-plan.sh` falls back to per-repo planning: it iterates each registered repo, runs `ralph-plan` inside, and stitches the per-repo results into `ralph/workspace-plan.md`. When the workspace-mode PR in the ai-ralph fork you use lands, the adapter switches to the native workspace command with no skill-level changes.

## Where Do Secrets Go?

In `.mcp.json`, which is **gitignored**. Use `${ENV_VAR}` refs for every credential — never literal tokens. `.mcp.json.template` is committed and shows the agreed server set; each collaborator copies it to `.mcp.json` locally and fills in their own env vars out-of-band. `gh auth status` provides GitHub credentials; no token lives in the repo.

## How Do I Contribute a Skill Improvement Back to the Template?

Open a pull request against `amit-t/ai-workbench`. The workbench's `update.wb` is strictly **one-way** (template → instance) by design, so upstream contributions go via PR, not via sync. If you hand-edit a `template_owned` path in a stamped workbench, `update.wb` will overwrite it on the next run — which is why the skill constitution (`AGENTS.md`) tells agents not to touch those paths.

## Can I Rename the Workbench Repo?

Yes, but `project.conf`'s `WORKBENCH_REPO` needs to match afterwards. There is no automatic rename support — rename on GitHub, update `project.conf` locally, push. Every collaborator re-pulls.

## Is the `.workbench-state/` Dir Shared?

Yes — it is tracked in git. Both collaborators see the same `published.json`, `approved.json`, `rejected.json`. This is deliberate: the approval state is a shared artifact that ralph reads, so both sides need to agree on it.

## Why Do I See "[wb] checking for updates..." Every Time I Run a wb Command?

You don't, actually. The first meaningful `wb.*` command in any 12-hour window triggers a single GitHub-API call to compare your stamped wb's template version against upstream `ai-workbench`. If a newer template version is available, a one-line banner is printed before your command runs. Otherwise the preamble is silent. The result is cached for 12 hours (configurable via `check_ttl_hours` in upstream `version.json`), so subsequent calls within the window do nothing. The check is fail-open: offline machines, rate-limit hits, and missing `gh` all skip silently. Trivial list aliases (`wb.published`, `wb.approved`, `wb.rejected`) never trigger the check at all. See [Versioning + upgrades](./versioning.html) for the full picture.
