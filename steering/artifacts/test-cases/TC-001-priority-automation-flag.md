---
id: TC-001
title: Every test case has a priority and an automation flag
scope: artifact:test-cases
owner: qa-council
created: 2026-04-24
updated: 2026-04-24
tags: [test-cases, triage]
---
**Rule:** Every test case in a test-cases file carries two explicit fields: priority (`P0` / `P1` / `P2`) and automation flag (`automated` / `manual` / `planned`). No defaults.

**Why:** Priority drives run order in a time-constrained regression. Automation flag makes the manual-test debt visible. Implicit defaults lie.

**How to apply:**
- Priority column in the test-cases table: `P0` (blocker, runs every build), `P1` (runs every release), `P2` (runs weekly).
- Automation flag: `automated` (has a BDD scenario or test), `manual` (requires human execution), `planned` (automation pending).
- When a test case is `manual` or `planned`, the next column states the ticket where automation is tracked.
- Priority + automation together drive the CI vs nightly vs exploratory bucket.

**Anti-pattern:** A test-cases table with columns `TC ID | Title` and nothing else.
