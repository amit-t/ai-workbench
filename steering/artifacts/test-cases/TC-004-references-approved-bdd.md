---
id: TC-004
title: Test-cases file references approved BDD features
scope: artifact:test-cases
owner: qa-council
created: 2026-04-24
updated: 2026-04-24
tags: [lifecycle, traceability]
---
**Rule:** Every test-cases file's frontmatter links to the approved BDD feature files that seed the cases. BDDs must be `status: approved` per `.workbench-state/approved.json` before test-case generation runs.

**Why:** Test cases generated from draft BDDs re-do work when the BDDs shift. The gate keeps generated work valuable.

**How to apply:**
- Frontmatter: `bdd_features: [BDD-EPIC-123-capability-a, BDD-EPIC-123-capability-b]` with paths.
- `/test-cases-gen` skill refuses to run when any referenced BDD is not approved.
- When a referenced BDD is later updated, regenerate the test cases rather than hand-editing.

**Anti-pattern:** Test-cases generated from "the feature files I found in qa/outputs/bdd/" without checking their lifecycle state.
