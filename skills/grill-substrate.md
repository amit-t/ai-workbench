# grill-substrate.md — wb-aware substrate for implicit grilling

Non-runtime reference. Every draft-producing skill in `skills/` reads this file before invoking `/grill-me` or `/domain-grill` so the grill session honors workbench conventions that the generic skills do not carry.

This file owns three things:

1. **Per-artifact stance** — what each grill pass should pressure-test.
2. **Scratch-block format** — where grill outcomes get recorded inside the artifact body.
3. **`grilled:` frontmatter schema** — the structured record the host writes after each pass concludes.

It does **not** own the depth-selector (lives in the generic skill) or the interview discipline (also in the generic skill).

---

## 1. Per-artifact stance

When a host invokes a grill, it must pass the stance for its artifact type as context. The grill session presses on these dimensions first; auxiliary branches come after if depth allows.

| Artifact type | Default grill | Stance — what to press on |
|---------------|---------------|----------------------------|
| `prd`         | `/grill-me`     | Scope slice clarity. Acceptance-criteria coverage (happy + edge). Non-goals honesty. Stakeholder gaps. Metrics that prove ship. Open questions that should be hard answers. |
| `design`      | `/grill-me`     | Flow gaps (happy path + at least empty / loading / error). Accessibility. DS-token fidelity. Persona fit. Missing states between screens. |
| `eng-spec`    | `/domain-grill` | Architecture fit vs `CONTEXT.md`. Contract / API compatibility. Migration + rollback plan. Observability hooks. Cross-service blast radius. ADR contradictions. |
| `tdd`         | `/domain-grill` | Testability of stated design. Race conditions. Failure-mode coverage. Public-API surface stability. Test-data realism. Determinism vs flakiness. |
| `erd`         | `/domain-grill` | Entity cardinality realism. Foreign-key + index plan. Migration cost on production data. Glossary alignment with `CONTEXT.md`. Backfill paths. |
| `adr`         | `/domain-grill` | Reversibility honesty. Alternatives genuinely considered. Consequence framing. Conflict with prior ADRs. Threshold check — does this decision actually meet the ADR bar? |
| `bdd`         | `/domain-grill` | Traceability back to PRD AC. Negative-path coverage. Non-functional scenarios. Step-definition reuse. Gherkin clarity. |
| `test-cases`  | `/domain-grill` | Coverage matrix vs BDDs. Boundary conditions. Equivalence-class collapse. Test-data preconditions. Risk-based prioritisation. |
| `test-spec`   | `/domain-grill` | Test pyramid balance. Tooling choices vs repo realities. Environment fidelity. Test-data lifecycle. Quality-gate definitions. |

For engineering artifacts (`eng-spec` through `test-spec`), the host runs one pass **per `target_repo`** — using `/domain-grill` against `${WB_ROOT}/context/<repo>/CONTEXT.md` when present, falling back to `/grill-me` for repos without a `CONTEXT.md`.

---

## 2. Scratch-block format

After a grill pass concludes, the host (or the grill skill itself, when prompted) records line items in an HTML comment near the top of the artifact body. One block per pass. Older blocks are kept for traceability.

```markdown
<!-- grill-me session 2026-05-14 (depth: standard, mode: grill-me, repo: -)
- [resolved] non-goal for mobile clients — explicit now at §5
- [parked]   SLO target — deferred to spec; tracked as GRILL-1
- [open]     rollback strategy if migration partially applied
-->
```

Rules:

- Header line carries date, depth, mode, repo (or `-` when not per-repo).
- Each line item starts with `[resolved]`, `[parked]`, `[open]`, or `[aborted]`.
- Parked items carry a tracking id (`GRILL-N`). The host increments `N` across all sessions for that artifact, starting at 1.
- Open items must either resolve before the next grill or get re-classified as parked with an id.
- Block goes immediately after the YAML frontmatter (or, for Gherkin files, immediately after the `# status:` header line).

---

## 3. `grilled:` frontmatter schema

Each host writes a `grilled:` block into the artifact's frontmatter after every grill session. Atomic per-pass: each pass's update is written via tempfile + rename so partial-state survives crashes.

### Shape

```yaml
grilled:
  date: 2026-05-14
  depth: standard            # deep | standard | quick | null (when skipped at top-level)
  passes:
    - mode: domain-grill     # grill-me | domain-grill | skipped
      repo: repo-A           # null for product/design hosts; <repo-name> for engineering hosts
      result: resolved       # resolved | parked-N | skipped | aborted | aborted-cascade
      open: 0                # count of unresolved items at session end
      parked: 0              # count of parked items at session end
```

### Result vocabulary

| Result | Meaning |
|--------|---------|
| `resolved`         | Pass completed; every branch resolved or parked-with-id. |
| `parked-N`         | Pass completed but `N` items parked. (`parked: N` mirrors the count.) |
| `skipped`          | User chose `n` / `skip-this-session` at the Option-B prompt. |
| `aborted`          | User typed `stop grill` mid-session for this pass. |
| `aborted-cascade`  | Set automatically on remaining passes after the user opts to cascade-abort. |

### Examples

**PRD (product, single pass, resolved):**

```yaml
grilled:
  date: 2026-05-14
  depth: standard
  passes:
    - { mode: grill-me, repo: null, result: resolved, open: 0, parked: 0 }
```

**Engineering spec (3 repos, mixed modes, mid-session abort):**

```yaml
grilled:
  date: 2026-05-14
  depth: standard
  passes:
    - { mode: domain-grill, repo: repo-A, result: resolved,        open: 0, parked: 0 }
    - { mode: domain-grill, repo: repo-B, result: aborted,         open: 2, parked: 0 }
    - { mode: grill-me,     repo: repo-C, result: aborted-cascade, open: 0, parked: 0 }
```

**Skipped at top-level:**

```yaml
grilled:
  date: 2026-05-14
  depth: null
  passes:
    - { mode: skipped, repo: null, result: skipped, open: 0, parked: 0 }
```

---

## 4. Host responsibilities (cheat-sheet)

A draft-producing skill does this between writing the artifact and printing its "next steps" tail:

1. **Read this file.** Capture stance for the artifact type + the schema.
2. **Resolve target repos.** From the artifact frontmatter `target_repos:` (product/design hosts skip this step — `repo: null`).
3. **Decide mode per repo.** For each `repo` in `target_repos`: `/domain-grill` if `${WB_ROOT}/context/<repo>/CONTEXT.md` exists, else `/grill-me`. Product/design hosts always use `/grill-me`.
4. **Show prior grill state if any.** Read existing `grilled:` block. If present and artifact mtime ≤ `grilled.date`, default the prompt to `n`; otherwise default `Y`.
5. **Prompt (Option B with teeth).**
   ```
   {ARTIFACT-ID} drafted at {path}. Targets: ...
   Prior grill: <none | YYYY-MM-DD depth (resolved N, parked M)>
   Run grill now? Depth? [deep|standard|quick] (default: deep)
   [Y/n/skip-this-session]
   ```
6. **Execute passes sequentially.** For each pass:
   - Pre-stage the stance from §1 into conversation context.
   - Pre-stage the scratch-block format from §2.
   - Invoke the resolved skill: `Skill("grill-me" | "domain-grill", args=<depth>)`.
   - On pass end, write scratch block + atomically update `grilled.passes` with this pass's record (tempfile + rename).
7. **Cascade-abort prompt.** If user `stop grill`-s mid-pass, ask `Abort remaining passes too? [Y/n]` (default Y). Cascade aborts record `result: aborted-cascade`.
8. **Resume on re-run.** If `grilled.passes` is non-empty but misses repos from `target_repos`, prompt `Resume grilling missing repos? [Y/n]` (default Y).
9. **Emit "next steps" tail.** Include grill outcome summary (`resolved N, parked M, skipped/aborted K`).

---

## 5. Lifecycle interaction

- `wb.publish` emits a stderr warning when any pass has a non-`resolved` result or when `grilled:` is absent. It does **not** block publish.
- `prd-review-panel` and `design-review` add a P2 finding `Ungrilled artifact — manual scrutiny recommended` when the same conditions are met. They block on P0 only, per their existing rubric.
- `scripts/validate-artifact.py` shape-checks the `grilled:` block but never rejects on non-resolved results.

The principle: grilling is high-friction-by-default, low-block-by-default. The author owns the decision; reviewers see the receipt.
