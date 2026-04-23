---
name: prd-review-panel
description: Multi-perspective review of a draft PRD — engineer, QA, designer, exec, skeptic, PM, end-user. Writes review synthesis next to the PRD. Use before approving a PRD.
category: Product Management
status: stub
phase: 2
---

# /prd-review-panel

**Phase 1 stub.**

## Intent

- For a given PRD path, spawn 7 sub-agent perspectives.
- Each writes one section of a review file.
- Final synthesis gates approval — if any perspective flags a blocker, PRD cannot move to `approved`.

## Output

- `product/outputs/prds/PRD-NNN-<slug>-review.md`
