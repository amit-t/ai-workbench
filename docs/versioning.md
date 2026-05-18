---
title: Versioning + Upgrades
layout: default
eyebrow: Versioning
subtitle: How a stamped wb learns about a new template version, and how to pull it.
---

*Prefer the old long-form? See [V1 archive](./v1/versioning.html).*

{% include links.html %}

This page covers the **workbench side** of cross-tool versioning: what you see when running `wb.*` commands inside a stamped wb. Full story (`version.json` location, `release-please` bumps, notification library, peer-version requirements, rollback, `devkit doctor`): [ai-devkit Pages]({{ links.ai_devkit_pages }}versioning.html).

## What you see

First meaningful `wb.*` call in any 12h window prints a banner above the command's normal output:

```
[wb] new ai-workbench template available: 1.2.0 → 1.3.0 (run wb.upgrade)
```

After that, silent until cache expires (12h default, configurable via `check_ttl_hours` in upstream `version.json`).

If the check can't reach GitHub (offline, rate limit, missing `gh`), the preamble fails open: command runs normally, no banner, no error. Best-effort, never load-bearing.

## How it works

`aliases.sh` wraps every meaningful command with a `_wb_check` helper. Helper sources `~/.local/share/wb-versioncheck/version-check.sh` (dropped on your machine by the `ai-devkit` and `ai-ralph` installers) and calls `_wb_versioncheck wb`, which compares this wb's `.workbench-state/template-version.json` against upstream `ai-workbench` `version.json`.

Library lives outside this repo intentionally. Missing → wrapper returns immediately, so a wb untouched by the devkit installer is silent, not broken.

## Which commands trigger the check

| Triggers banner | Silent (read-only / trivial) |
|------------------|-------------------------------|
| `wb.publish` | `wb.published` |
| `wb.approve` | `wb.approved` |
| `wb.reject` | `wb.rejected` |
| `wb.sync-context` | |
| `wb.ralph-plan` | |
| `wb.ralph-dispatch` | |
| `wb.ralph-enable-check` | |
| `wb.register-repo` | |
| `wb.steering` | |
| `wb.steering-refresh` | |
| `wb.steering-lint` | |
| `wb.steering-audit` | |

List aliases stay silent on purpose: tight loops + prompts would make a banner noise.

## What `wb.upgrade` does

Canonical name for the workbench-template refresh. It:

1. Pulls the latest `ai-workbench` template tarball from upstream release.
2. Replaces every path under `template_owned` in `.workbench-manifest.json`. PRDs, specs, BDDs, code repos, lifecycle state, `steering.local/` overlays untouched.
3. Updates `.workbench-state/template-version.json` to the new upstream version.

If a new template declares a peer-version requirement (`requires` in upstream `version.json`), `wb.upgrade` checks your `ai-devkit` and `ai-ralph` versions and refuses if either is below the floor. `--force` overrides (rarely correct).

## `update.wb` is deprecated

Old alias. Still works as a shim that forwards to `wb.upgrade`. Use `wb.upgrade` in scripts, runbooks, new docs. Shim goes away in a future major.

## See also

- [ai-devkit versioning]({{ links.ai_devkit_pages }}versioning.html) for `devkit doctor`, `*.upgrade --rollback`, notification-library internals.
- [Architecture]({{ '/architecture.html' | relative_url }}) for where `aliases.sh` and `.workbench-manifest.json` sit.
- [Artifact lifecycle]({{ '/lifecycle.html' | relative_url }}) for the publish/approve/reject flow the preamble wraps.
