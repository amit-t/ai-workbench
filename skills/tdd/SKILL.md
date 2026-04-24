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

1. **Read the SPEC** (frontmatter + all sections).

2. **For each target repo in SPEC `target_repos`**, identify concrete files to create or modify. Use `engineering/context-library/` and, if needed, read `repos/{name}/` (read-only) to learn the existing layout.

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

5. **Tell the user:**

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
