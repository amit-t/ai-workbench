---
id: TSPEC-001
title: Environment matrix is stated
scope: artifact:test-spec
owner: qa-council
created: 2026-04-24
updated: 2026-04-24
tags: [test-spec, environments]
---
**Rule:** Every test spec states the environments each test layer runs in: local, CI, staging, production-like. For each environment, state what differs (real DB vs sqlite, real payment processor vs stub, real queue vs in-memory).

**Why:** Environment drift is a top cause of "passes in CI, fails in staging." Naming the matrix up front forces the team to decide which tests run where.

**How to apply:**
- Table with rows = test layer (unit, integration, contract, e2e), columns = environment.
- For each cell, mark run / skip and name the substitutions made (mock Stripe, real DB).
- Tests that require specific environment capabilities (real network, specific region, real mTLS) get called out.
- When the matrix changes (new env, new layer), update the test spec before the change ships.

**Anti-pattern:** Test spec that lists test layers with no environment breakdown, leading to "we thought contract tests ran in CI, turns out they don't" incidents.
