---
title: /epic-intake
layout: default
eyebrow: PO
subtitle: "Pull a Jira epic body into `product/context-library/epics/` as a draft context artifact."
---

| Hat | Stage | Upstream gate | Output | Unblocks |
|-----|-------|---------------|--------|----------|
| PO | Intake | Jira epic ID listed in `project.conf EPICS` | `product/context-library/epics/<EPIC-ID>.md` | `/prd-draft` |

## When to use

User references a Jira epic ID (e.g. `EPIC-001`) or pastes a Jira link, intending to start work on it inside this workbench.

## Prerequisites

- Epic ID in `project.conf EPICS`. If missing, append and commit.
- Atlassian MCP optional. Enabled → use `get_issue`. Disabled → paste epic body.

## Protocol

1. Verify epic in `project.conf EPICS`.
2. Pull epic — MCP `get_issue` or manual paste. Capture summary, description, ACs, priority, assignee, reporter, parent, linked issues, labels, top 10 comments.
3. Write `product/context-library/epics/{EPIC_ID}.md` with frontmatter `status: draft` and sections: Summary, Description, Acceptance Criteria, Linked issues, Comments. Mark unknowns `TODO: …`.
4. Update `EPIC-PIPELINE.md` section `## EPIC {EPIC_ID}`.
5. Never publish or approve — tell user to run `wb.publish` + `wb.approve`.

## Output frontmatter

```yaml
id: epic-{EPIC_ID}
title: {title}
status: draft
priority: {priority}
pm: {assignee}
business_owner: {BO}
jira_url: https://<your-jira-domain>.atlassian.net/browse/{EPIC_ID}
pulled_at: {today}
source: {mcp|manual}
```

## Do not

- Set `status: published` or `status: approved` — both are human-driven via aliases.
- Expose MCP tokens in the written file.
- Draft a PRD from this skill — that is `/prd-draft`.

## Source

[`skills/epic-intake/SKILL.md`](https://github.com/amit-t/ai-workbench/blob/main/skills/epic-intake/SKILL.md)
