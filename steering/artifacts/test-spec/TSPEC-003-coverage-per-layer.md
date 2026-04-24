---
id: TSPEC-003
title: Coverage target per layer is stated
scope: artifact:test-spec
owner: qa-council
created: 2026-04-24
updated: 2026-04-24
tags: [test-spec, coverage]
---
**Rule:** Every test spec states a coverage target for each layer (unit, integration, contract, e2e). A single "80% overall" figure is not enough; targets are per-layer because the layers serve different purposes.

**Why:** A high total masks a missing layer. 90% unit coverage and 0% integration coverage is a riskier profile than 60% unit / 60% integration. Layer-level targets force balanced investment.

**How to apply:**
- Table with columns: layer, target (%), currently-achieved, gap.
- Rationale for each target: why this layer needs more / less.
- Gaps come with a dated remediation plan, not an open-ended TODO.
- For new capabilities, state the "must-have" tests at launch (the subset below which launch is blocked).

**Anti-pattern:** Test spec says "aim for >=80% coverage" and nothing else.
