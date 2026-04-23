# product/context-library

Everything a PO hat needs before drafting a PRD. Populated by init.wb (epic bodies from Jira) and augmented as research happens.

## Structure

```
context-library/
  epics/                  # one MD per Jira epic, pulled via Atlassian MCP or manually pasted
    EPIC-001.md
    EPIC-002.md
  research/               # user interviews, stakeholder notes
  decisions/              # product-side decision log (ADR-equivalent)
```

## Epic file format

```markdown
---
id: EPIC-001
title: Example refactor
status: In Progress
priority: High
pm: <name>
business_owner: <name>
jira_url: https://<your-jira-domain>.atlassian.net/browse/EPIC-001
pulled_at: 2026-04-23
---

## Summary
## Description
## Acceptance Criteria
## Linked issues
## Comments (condensed)
```
