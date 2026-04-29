---
name: epic-intake
description: Pull a Jira epic body into product/context-library/epics/, stamp it as a draft context artifact, and prep it for /prd-draft once approved.
category: Product Management
relevant_topics: []
---

# /epic-intake

## When to use

User references a Jira epic ID (e.g. `EPIC-001`) or pastes a Jira link, intending to start work on it inside this workbench.

## Prerequisites

- The epic ID is listed in `project.conf` `EPICS=(...)`. If not, prompt the user to append it (commit the change).
- Atlassian MCP is optional. If `.mcp.json` enables it, use it; else ask the user to paste the epic body.

## Lifecycle note

The epic-context file you write starts at `status: draft`. It must be published (`wb.publish epic-{EPIC_ID} product/context-library/epics/{EPIC_ID}.md epic-context`) and approved (`wb.approve epic-{EPIC_ID}`) before `/prd-draft` may consume it.

## Steps

0. **Load steering.** Run `wb.steering artifact:epic-context` (or `python3 scripts/steering-load.py artifact:epic-context`). Treat the merged ruleset as hard constraints on summary completeness, AC capture, linked-issue handling, and TODO honesty. The loader emits an empty merged blob when no `artifact:epic-context` rules ship yet; the hook is in place for when the council adds them. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none by default).

1. **Verify epic is in `project.conf`.** If not, ask and append.

2. **Pull the epic.**
   - If Atlassian MCP enabled: call `get_issue` for `{EPIC_ID}`. Capture summary, description, ACs, status, priority, assignee, reporter, parent link, linked issues, labels, top 10 comments.
   - Else: ask the user to paste the epic body and summaries.

3. **Write `product/context-library/epics/{EPIC_ID}.md`** with:

   ```markdown
   ---
   id: epic-{EPIC_ID}
   title: {title}
   status: draft
   priority: {priority}
   pm: {assignee}
   business_owner: {BO}
   jira_url: https://<your-jira-domain>.atlassian.net/browse/{EPIC_ID}
   pulled_at: {today YYYY-MM-DD}
   source: {mcp|manual}
   ---

   ## Summary

   ## Description

   ## Acceptance Criteria

   ## Linked issues

   ## Comments (most recent 10)
   ```

   Fill each section. Mark unknowns with `TODO: <what's missing>`.

4. **Update `EPIC-PIPELINE.md`.** Find the `## EPIC {EPIC_ID}` section. If present, update `Status:` and add a notes bullet with the pulled-at date. If absent, append a new section matching the template.

5. **Do not publish or approve automatically.** Tell the user:

   > Epic `{EPIC_ID}` context drafted at `product/context-library/epics/{EPIC_ID}.md` (status: draft). Review it, then run:
   >
   > ```
   > wb.publish epic-{EPIC_ID} product/context-library/epics/{EPIC_ID}.md epic-context
   > wb.approve epic-{EPIC_ID}
   > ```
   >
   > Then run `/prd-draft {EPIC_ID}` to scope a PRD.

## Output contract

- Creates: `product/context-library/epics/{EPIC_ID}.md` with `status: draft`.
- Modifies: `EPIC-PIPELINE.md`.
- Does not modify any `.workbench-state/*.json`.

## Do not

- Do not set `status: published` or `status: approved`. Those transitions belong to `wb.publish` and `wb.approve`.
- Do not expose MCP tokens in the written file.
- Do not draft a PRD from this skill — that is `/prd-draft`.
