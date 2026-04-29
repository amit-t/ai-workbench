---
name: figma-pull
description: Park Figma links for a PRD in design/context-library/figma-links.md. If the Figma MCP is enabled in `.mcp.json`, pull frame list and export nodes to design/outputs/screens/{PRD-NNN}/. Default path is link-parking only — no network call needed.
category: UX Design
relevant_topics: []
---

# /figma-pull

## When to use

- A PRD exists and the designer has a Figma file for its screens.
- Engineer or QA wants the current frame list beside the PRD without loading the Figma UI.

## Prerequisites

- `design/context-library/figma-links.md` exists (the workbench template ships it).
- Optional: `.mcp.json` contains a Figma MCP entry. Detect with `jq '.mcpServers | has("figma")' .mcp.json`. If false, this skill runs in **link-parking mode** only.

## Steps

0. **Load steering.** No `artifact:figma` scope is defined; design artifacts do not yet have Layer 2 rules. Layer 0 (golden) loaded at session start and Layer 1 (`role:uxd`) loaded on UX role-switch remain in force. If a per-workbench team has added overlay rules under `steering.local/artifacts/design/`, run `wb.steering artifact:design` to pick them up. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none by default).

1. **Identify target.** Ask for `{PRD-NNN}` and the Figma URL. Validate URL matches `https://www.figma.com/file/<key>/<name>` or `https://www.figma.com/design/<key>/<name>`. Extract `<key>`.

2. **Append or update the link row** in `design/context-library/figma-links.md`:

   ```markdown
   | PRD-{NNN} | {title} | {https://...} | {key} | {today} | {author-gh} |
   ```

   If a row for this PRD already exists, replace it in place (Figma links rot; most recent wins).

3. **Branch by MCP availability:**

   - **Link-parking mode (default):**
     Stop here. Tell the user:
     > Link parked for PRD-{NNN}. No Figma MCP configured — enable per-workbench by adding a Figma server to `.mcp.json` and re-run `/figma-pull` if you want frame extraction.

   - **MCP mode:**
     Continue to steps 4–6.

4. **List frames.** Call the Figma MCP tool to list top-level frames in the file. Persist results to `design/outputs/screens/PRD-{NNN}/frames.json`:

   ```json
   [
     { "nodeId": "123:45", "name": "Sign-in — default", "width": 1440, "height": 900 },
     ...
   ]
   ```

5. **Ask before exporting.** Export is bandwidth-heavy. Show the frame count and ask:
   > Export {N} frames as PNG@2x to `design/outputs/screens/PRD-{NNN}/`? (y/N)

   On `y`, call the MCP export tool per node; save `<slug>.png`. Skip any frame named `Archived-*` or starting with `_`.

6. **Write an index** `design/outputs/screens/PRD-{NNN}/index.md`:

   ```markdown
   ---
   id: DESIGN-PRD-{NNN}
   status: draft
   prd: PRD-{NNN}
   source: figma
   figma_file_key: {key}
   exported: {today}
   ---

   # Design index — PRD-{NNN}

   | Frame | Node | File |
   |-------|------|------|
   | Sign-in default | 123:45 | sign-in-default.png |
   ```

   Note: `index.md` is the lifecycle artifact (type `design`); PNGs are binary assets tracked by git but not by `wb.publish`.

7. **Tell the user next steps:**

   > {N} frames exported to `design/outputs/screens/PRD-{NNN}/`.
   > Index at `design/outputs/screens/PRD-{NNN}/index.md` (status: draft).
   > Next: `/design-draft PRD-{NNN}` to wrap flows/wireframes, or `wb.publish DESIGN-PRD-{NNN} design/outputs/screens/PRD-{NNN}/index.md design` once the set is complete.

## Output contract

- Modifies: `design/context-library/figma-links.md`.
- Creates (MCP mode): `design/outputs/screens/PRD-{NNN}/frames.json`, PNG files, and `design/outputs/screens/PRD-{NNN}/index.md` (status: draft).
- Never writes outside the workbench.

## Do not

- Do not hardcode a Figma access token. The MCP server reads its own credentials per-workbench.
- Do not export private/archived frames. Respect the naming convention in step 5.
- Do not overwrite exported PNGs without appending `-v2`, `-v3` — keeps revision history traceable.
