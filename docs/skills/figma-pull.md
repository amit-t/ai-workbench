---
title: /figma-pull
layout: default
---

[← Back to skills](../skills.html)

# /figma-pull

> Park Figma links for a PRD. If Figma MCP is enabled, pull frame list and export nodes to `design/outputs/screens/{PRD-NNN}/`. Default path is link-parking only — no network call.

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| UXD | Design input | PRD ID + Figma URL | `design/context-library/figma-links.md`; optional `design/outputs/screens/PRD-NNN/` | `/ds-screen-gen`, `/design-review` |

## When to use

- PRD exists and designer has a Figma file for its screens.
- Engineer / QA wants current frame list beside the PRD without loading Figma UI.

## Prerequisites

- `design/context-library/figma-links.md` exists (shipped with template).
- Optional: `.mcp.json` contains Figma MCP entry (detect: `jq '.mcpServers | has("figma")' .mcp.json`). Absent → **link-parking mode** only.

## Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| Link-parking (default) | No Figma MCP configured | Append/update row in `figma-links.md`; stop |
| MCP mode | Figma MCP present | List frames → `frames.json`; ask before export → PNG@2x per frame → write `index.md` |

## Protocol

1. Identify target — PRD number + Figma URL. Validate `https://www.figma.com/(file|design)/<key>/<name>`. Extract `<key>`.
2. Append/update row in `design/context-library/figma-links.md`:

    ```markdown
    | PRD-{NNN} | {title} | {url} | {key} | {today} | {author-gh} |
    ```

    Replace existing row for same PRD (Figma links rot).
3. Branch:
    - **Link-parking:** stop, inform user MCP disabled.
    - **MCP:** list frames → save `design/outputs/screens/PRD-{NNN}/frames.json`. Ask before export (`y/N`). Skip `Archived-*` / `_*` frames. Save `<slug>.png` per node. Write `design/outputs/screens/PRD-{NNN}/index.md` at `status: draft`.

## Output frontmatter (MCP mode, index.md)

```yaml
id: DESIGN-PRD-{NNN}
status: draft
prd: PRD-{NNN}
source: figma
figma_file_key: {key}
exported: {today}
```

`index.md` is the lifecycle artifact (type `design`). PNGs are binary assets tracked by git but not by `wb.publish`.

## Do not

- Hardcode a Figma access token. MCP server reads its own credentials per-workbench.
- Export private / archived frames. Respect naming convention.
- Overwrite exported PNGs without `-v2` / `-v3` suffix.

## Source

[`skills/figma-pull/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/figma-pull/SKILL.md)
