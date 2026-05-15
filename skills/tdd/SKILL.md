---
name: tdd
description: Technical design document at status=draft from an approved engineering spec. File map per repo, interfaces, sequence diagrams, failure matrix, test outline.
category: Engineering
relevant_topics: [api-design]
---

# /tdd

## When to use

SPEC is approved; user wants implementation-ready detail for ralph.

## Prerequisites

- SPEC has `status: approved` AND entry in `.workbench-state/approved.json`.

## Steps

0. **Load steering.** Run `wb.steering artifact:tdd` and then `wb.steering topic:api-design`. Treat the merged rulesets as hard constraints for the file map, interface signatures, sequence diagrams, and failure matrix.

0.5. **Precision check.** Resolve `PRECISION_MODE` — env `WB_PRECISION_MODE` > `project.conf PRECISION_MODE` > default `on`. If `on`, invoke `Skill("precision-mode")` and announce one line: `Precision mode on for this run.` Carry the resolved value into the TDD frontmatter as `precision_mode: on|off` at write time. The directive applies for the rest of this host run (artifact body, grill pass, next-steps tail). See `.agents/skills/precision-mode/SKILL.md`.

1. **Read the SPEC** (frontmatter + all sections).

2. **For each target repo in SPEC `target_repos`**, identify concrete files to create or modify. Use `engineering/context-library/` and, if needed, read `repos/{name}/` (read-only) to learn the existing layout. Mirror the SPEC's `target_repos:` into the TDD frontmatter (validated at `wb.publish` / `wb.approve`).

3. **Write `engineering/outputs/tdd/TDD-{NNN}-{slug}.md`:**

   ```markdown
   ---
   id: TDD-{NNN}
   title: {title}
   status: draft
   created: {today}
   owner: {gh-user}
   epic: {EPIC_ID}
   prd: PRD-{NNN}
   spec: SPEC-{NNN}
   target_repos: [{repo-1}, {repo-2}]
   precision_mode: {on | off}
   ---

   # TDD-{NNN}: {title}

   ## 1. Summary
   {2-3 sentences pointing at SPEC-{NNN}.}

   ## 2. File map per repo

   ### Repo: {repo-1} ({role})
   | Action | File | Purpose |
   |--------|------|---------|
   | Create | `src/adapters/in/http/…ts` | REST entry point |
   | Modify | `src/core/services/….ts:45-120` | new method |
   | Create | `tests/services/….test.ts` | unit tests |

   (Repeat per repo.)

   ## 3. Key interfaces
   ```ts
   // src/core/ports/out/….port.ts
   export interface FooPort { … }
   ```

   ## 4. Sequence diagrams
   ```mermaid
   sequenceDiagram
     Client->>Controller: request
     Controller->>Service: call
     Service->>Adapter: outbound
     Adapter-->>Service: result
     Service-->>Controller: result
     Controller-->>Client: response
   ```

   ## 5. Data shapes
   Reference `engineering/outputs/erd/ERD-{NNN}.md`. Repeat key types consumers need.

   ## 6. Failure handling matrix
   | Failure | Layer | Surface | Retry? | Idempotency key |
   |---------|-------|---------|--------|-----------------|

   ## 7. Test outline
   - `….test.ts`
     - happy path
     - edge
     - idempotent on repeated key

   ## 8. Observability additions
   - Metric:
   - Log:
   - Trace span:

   ## 9. Open questions
   ```

4. **Update `EPIC-PIPELINE.md`.** Set TDD column to `TDD-{NNN}`.

5. **Grill pass.** Read `skills/grill-substrate.md` (single source for stance, scratch-block format, and `grilled:` frontmatter schema). Then:

   - **Mode (per repo, Resolution Z):** for each `repo` in the TDD's `target_repos`, use `/domain-grill` when `${WB_ROOT}/context/<repo>/CONTEXT.md` exists, otherwise fall back to `/grill-me` for that repo.
   - **Prompt (Option-B with teeth, batched):**
     ```
     TDD-{NNN} drafted at engineering/outputs/tdd/TDD-{NNN}-{slug}.md.
     Targets: repo-A (domain-grill), repo-B (grill-me, no CONTEXT.md), ...
     Prior grill: <none | YYYY-MM-DD depth (resolved N, parked M)>
     Run grill now? Depth? [deep|standard|quick] (default: deep)
     [Y/n/skip-this-session]
     ```
     Default Y on first run. Default n if `grilled.date` is current and artifact mtime less than or equal to `grilled.date`.
   - **Execute sequentially.** On `Y`, for each target repo: pre-stage the `tdd` stance from §1 of `grill-substrate.md` + the scratch-block format from §2, then invoke `Skill("domain-grill" | "grill-me", args=<depth>)` with `cwd=${WB_ROOT}/context/<repo>/` for domain-grill, or `cwd=${WB_ROOT}` for the fallback.
   - **Record per pass.** Append scratch block + atomically extend `grilled.passes` (tempfile + rename). Per-pass durability.
   - **Abort / skip / cascade-resume.** Per §4 cheat-sheet. Cascade prompt default Y. Never blocks.

6. **Tell the user:**

   > TDD-{NNN} drafted (status: draft). Review, then:
   > ```
   > wb.publish TDD-{NNN} engineering/outputs/tdd/TDD-{NNN}-{slug}.md tdd
   > wb.approve TDD-{NNN}
   > ```
   > Next: `/erd SPEC-{NNN}` if schema non-trivial, else proceed to test authoring.

## Output contract

- Creates: `engineering/outputs/tdd/TDD-{NNN}-{slug}.md` with `status: draft`.
- Modifies: `EPIC-PIPELINE.md`.

## Do not

- Do not leave "TODO" in the file map. Ask the user if uncertain.
- Do not copy-paste code from `repos/*` without citing the original file and line range.
