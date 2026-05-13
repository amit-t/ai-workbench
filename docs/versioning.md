---
title: Versioning + Upgrades
layout: default
eyebrow: Versioning
subtitle: How a stamped workbench learns about a new template version, and how to pull it.
---

{% include links.html %}

This page covers the **workbench side** of the cross-tool versioning system, the bit you see when you run `wb.*` commands inside a stamped wb. For the full story (where `version.json` lives, how `release-please` bumps it, the notification library, peer-version requirements, rollback, `devkit doctor`), see the canonical reference in [ai-devkit Pages]({{ links.ai_devkit_pages }}versioning.html).

## What you actually see

The first time you run a meaningful `wb.*` command in any 12-hour window, you get a banner like this above the command's normal output:

```
[wb] new ai-workbench template available: 1.2.0 → 1.3.0 (run wb.upgrade)
```

After that the banner is silent until the cache expires (12 hours by default, configurable via `check_ttl_hours` in upstream `version.json`).

If the check cannot reach GitHub (offline, rate limit, missing `gh`), the preamble fails open. Your command runs normally with no banner and no error. The version check is best-effort, never load-bearing.

## How it works in this wb

`aliases.sh` wraps every meaningful workbench command with a `_wb_check` helper. The helper sources `~/.local/share/wb-versioncheck/version-check.sh` (a small library dropped on your machine by the `ai-devkit` and `ai-ralph` installers) and calls `_wb_versioncheck wb`, which compares this stamped wb's `.workbench-state/template-version.json` against the upstream `ai-workbench` `version.json`.

The library lives outside this repo on purpose. If it is missing the wrapper returns immediately, so a wb that has never been touched by the devkit installer is not broken, just silent.

## Which commands trigger the check

| Triggers banner | Silent (read-only or trivial) |
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

The list aliases (`wb.published`, `wb.approved`, `wb.rejected`) intentionally stay silent. They get used in tight loops and from prompts; pinning a banner on every call would be noise, not a signal.

## What `wb.upgrade` actually does

`wb.upgrade` is the canonical name for the workbench-template refresh. It:

1. Pulls the latest `ai-workbench` template tarball from the upstream release.
2. Replaces every path listed under `template_owned` in `.workbench-manifest.json`. Your PRDs, specs, BDDs, code repos, lifecycle state, and `steering.local/` overlays are never touched.
3. Updates `.workbench-state/template-version.json` to the new upstream version, so the next `_wb_check` compares against the new floor instead of re-firing the same banner.

If a new template version declares a peer-version requirement (the `requires` field in upstream `version.json`), `wb.upgrade` checks your installed `ai-devkit` and `ai-ralph` versions and refuses to upgrade if either is below the floor. Pass `--force` to override (rarely the right call).

## `update.wb` is deprecated

The original alias was `update.wb`. It still works, but only as a thin shim that prints a deprecation notice and forwards to `wb.upgrade`. Use `wb.upgrade` in scripts, runbooks, and any new docs you write. The shim will go away in a future major bump.

## See also

- [ai-devkit versioning page]({{ links.ai_devkit_pages }}versioning.html) covers `devkit doctor`, `*.upgrade --rollback`, and the notification library internals.
- [Architecture]({{ '/architecture.html' | relative_url }}) shows where `aliases.sh` and `.workbench-manifest.json` fit in the workbench tree.
- [Artifact Lifecycle]({{ '/lifecycle.html' | relative_url }}) walks the `wb.publish` / `wb.approve` / `wb.reject` flow that the version-check preamble wraps.
