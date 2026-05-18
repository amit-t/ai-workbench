---
title: FAQ
layout: default
eyebrow: FAQ
---

*Prefer the old long-form? See [V1 archive](./v1/faq.html).*

## Why a workbench per epic bundle, not a permanent hub?

Bundles are disposable. An epic (or a small set of related epics) gets picked up, planned, shipped, archived. A workbench matches that lifespan. A permanent team-wide hub drifts, accumulates stale context, becomes a second Jira. Explicitly throwaway by design.

## Do I have to use Devin?

No. Every devkit command has a `.cly` variant that forces Claude: `init.wb.cly`, `join.wb.cly`, `update.wb.cly`. Inside a workbench, slash commands work the same under Claude or Devin (both read the same `skills/`). `.dev` variants force Devin.

## What if dev and QA edit `project.conf` simultaneously?

Git merge conflict. Resolve normally and push. The file is shell; conflicts usually surface as duplicated array entries, easy to reconcile. Pull at session start, push at pause.

## Can I run ralph without workspace-mode?

Yes. `scripts/ralph-plan.sh` falls back to per-repo: iterates each registered repo, runs `ralph-plan` inside, stitches results into `ralph/workspace-plan.md`. When workspace-mode is available in the ai-ralph fork you use, the adapter switches automatically.

## Where do secrets go?

`.mcp.json`, which is **gitignored**. Use `${ENV_VAR}` refs for every credential, never literal tokens. `.mcp.json.template` is committed and documents the agreed server set; each collaborator copies it to `.mcp.json` locally and fills env vars out-of-band. GitHub creds come from `gh auth status`; no tokens in repo.

## How do I contribute a skill improvement back to the template?

Open a PR against `amit-t/ai-workbench`. `wb.upgrade` is strictly one-way (template → instance) by design, so upstream contributions go via PR, not sync. Hand-edits to `template_owned` paths in a stamped wb get overwritten on the next `wb.upgrade`. `AGENTS.md` tells agents not to touch those paths.

## Can I rename the workbench repo?

Yes, but `project.conf`'s `WORKBENCH_REPO` must match afterwards. No auto-rename: rename on GitHub, update `project.conf` locally, push. Every collaborator re-pulls.

## Is `.workbench-state/` shared?

Yes, tracked in git. Both collaborators see the same `published.json`, `approved.json`, `rejected.json`. Deliberate: approval state is the shared contract ralph reads, so both sides must agree.

## Why do I see "[wb] checking for updates..." on every wb command?

You don't. First meaningful `wb.*` call per 12h window triggers a single GitHub-API call comparing your wb's template version against upstream. Newer → one-line banner. Otherwise silent. Result cached 12h (configurable via `check_ttl_hours`). Fail-open: offline / rate-limit / missing `gh` all skip silently. Trivial list aliases (`wb.published`, `wb.approved`, `wb.rejected`) never trigger. Details: [Versioning](./versioning.html).
