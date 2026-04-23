---
title: FAQ
layout: default
kicker: FAQ
eyebrow: faq
tagline: Common questions on per-bundle scope, Devin vs Claude, conflicts, secrets, and upstream PRs.
---

# FAQ

## Why a workbench per epic bundle, not a permanent hub?

Bundles are disposable. An epic (or a small set of related epics) gets picked up, planned, shipped, then closed. A workbench matches that lifespan — start one, work in it for weeks or a quarter, archive it. A permanent team-wide hub drifts, accumulates stale context, and becomes a second Jira. This harness is explicitly throwaway.

## Do I have to use Devin?

No. Every devkit command has a `.cly` variant that forces Claude: `init.wb.cly`, `join.wb.cly`, `update.wb.cly`. Inside a workbench, slash commands work the same under Claude or Devin because both read the same `skills/` directory. `.dev` variants force Devin if you want to be explicit.

## What happens if both dev and QA edit `project.conf` at the same time?

Git merge conflict. Resolve it normally and push. The file is a shell script — conflicts usually show up as duplicated array entries, which are easy to reconcile. Pull before starting a session and push when you pause; that is the simplest way to avoid the situation.

## Can I run ralph without workspace-mode?

Yes. `scripts/ralph-plan.sh` falls back to per-repo planning: it iterates each registered repo, runs `ralph-plan` inside, and stitches the per-repo results into `ralph/workspace-plan.md`. When the workspace-mode PR in the ai-ralph fork you use lands, the adapter switches to the native workspace command with no skill-level changes.

## Where do secrets go?

In `.mcp.json`, which is **gitignored**. Use `${ENV_VAR}` refs for every credential — never literal tokens. `.mcp.json.template` is committed and shows the agreed server set; each collaborator copies it to `.mcp.json` locally and fills in their own env vars out-of-band. `gh auth status` provides GitHub credentials; no token lives in the repo.

## How do I contribute a skill improvement back to the template?

Open a pull request against `amit-t/ai-workbench`. The workbench's `update.wb` is strictly **one-way** (template → instance) by design, so upstream contributions go via PR, not via sync. If you hand-edit a `template_owned` path in a stamped workbench, `update.wb` will overwrite it on the next run — which is why the skill constitution (`AGENTS.md`) tells agents not to touch those paths.

## Can I rename the workbench repo?

Yes, but `project.conf`'s `WORKBENCH_REPO` needs to match afterwards. There is no automatic rename support — rename on GitHub, update `project.conf` locally, push. Every collaborator re-pulls.

## Is the `.workbench-state/` dir shared?

Yes — it is tracked in git. Both collaborators see the same `published.json`, `approved.json`, `rejected.json`. This is deliberate: the approval state is a shared artifact that ralph reads, so both sides need to agree on it.
