---
id: BDD-001
title: Feature files include happy-path, edge, error, and security tags
scope: artifact:bdd
owner: qa-council
created: 2026-04-24
updated: 2026-04-24
tags: [bdd, tags, coverage]
---
**Rule:** Every `.feature` file includes scenarios tagged with `@happy-path`, `@edge`, `@error`, and `@security`. Additional tags (`@epic-*`, `@prd-*`, `@manual`) are fine; these four are the required minimum.

**Why:** Forcing all four tag classes at feature-file level ensures coverage is visible and missing categories are called out at review.

**How to apply:**
- Every feature has at least one `@happy-path`, `@edge`, `@error`, `@security` scenario.
- For endpoints without a meaningful security boundary, write the `@security` scenario as explicit "any authenticated user may access this endpoint" with a comment explaining why no boundary applies.
- Review: missing category = blocking comment on the PR.
- The generator skill `/bdd-gen` ships a template that includes all four categories by default.

**Anti-pattern:** A feature file with only `@happy-path` scenarios, authored "to get moving and add error paths later."
