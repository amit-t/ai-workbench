---
name: erd
description: Entity-relationship diagram + C4-level-2 component diagram at status=draft. Writes engineering/outputs/erd/ERD-NNN-<slug>.md. Uses Mermaid so diagrams render in GitHub without external tools.
category: Engineering
relevant_topics: []
---

# /erd

## When to use

- SPEC §5 "Data model" or §3 "Architecture impact" is material and deserves a picture.
- A cross-service data flow needs a C4-level-2 component view.
- Reviewer asked "where does X live" during `/grill-me`.

## Prerequisites

- Related SPEC exists at `engineering/outputs/specs/SPEC-{NNN}-<slug>.md`. Spec may still be `draft`.
- `project.conf` REPOS populated — diagrams reference repos/services by their canonical names.

## Steps

0. **Load steering.** Run `wb.steering artifact:erd` (or `python3 scripts/steering-load.py artifact:erd`). Treat the merged ruleset as hard constraints on entity naming, cardinality notation, C4-level-2 component scope, and migration-note discipline. Any `relevant_topics` declared in this skill's frontmatter are loaded after (none by default).

1. **Pick ERD number.** Scan `engineering/outputs/erd/ERD-*.md`, max + 1, zero-pad to three digits. Use the same slug as the SPEC when possible (e.g. `ERD-003-audit-log`). Copy `target_repos:` from the SPEC into the ERD frontmatter (validated at `wb.publish` / `wb.approve`).

2. **Choose diagram set.** Ask the user; default to all three:
   - **DB-ERD** — tables/collections, keys, cardinality. Required if SPEC §5 introduces schema changes.
   - **C4-L2 component** — services, ports, adjacent systems. Required if SPEC §3 lists new services or cross-service contracts.
   - **Sequence** — request flow for the hottest path. Optional; add when contracts in §4 have more than 2 hops.

3. **Write `engineering/outputs/erd/ERD-{NNN}-{slug}.md`:**

   ````markdown
   ---
   id: ERD-{NNN}
   title: {title}
   status: draft
   created: {today}
   owner: {gh-user}
   epic: {EPIC_ID}
   related_spec: SPEC-{NNN}
   target_repos: [{repo-1}, {repo-2}]
   ---

   # ERD-{NNN}: {title}

   ## 1. DB entity-relationship

   ```mermaid
   erDiagram
       USER ||--o{ AUDIT_EVENT : writes
       AUDIT_EVENT {
           uuid    id PK
           uuid    user_id FK
           text    action
           jsonb   payload
           timestamptz occurred_at
       }
       USER {
           uuid id PK
           text email
       }
   ```

   **Notes:** PK/FK conventions, nullability, indexes added by this change.

   ## 2. C4 Level-2 — components

   ```mermaid
   flowchart LR
       subgraph api["api-gateway"]
           AUTH[auth-adapter]
       end
       subgraph svc["audit-service"]
           PORT[in/http]
           CORE[core/audit-service]
           OUT[out/pg-audit-repo]
       end
       DB[(postgres: audit)]

       AUTH --> PORT
       PORT --> CORE
       CORE --> OUT
       OUT --> DB
   ```

   **Notes:** new components bolded; existing components dimmed.

   ## 3. Hot-path sequence (optional)

   ```mermaid
   sequenceDiagram
       actor U as User
       participant G as api-gateway
       participant S as audit-service
       participant D as postgres
       U->>G: POST /action
       G->>S: publish(event)
       S->>D: INSERT audit_event
       D-->>S: ok
       S-->>G: 202
       G-->>U: 202
   ```

   ## 4. Change summary
   | Object | Change | Owner repo |
   |--------|--------|------------|

   ## 5. Migration notes
   - Forward: {one-liner}
   - Rollback: {one-liner or "irreversible — see ADR-NNN"}
   ````

4. **Back-link.** In SPEC §5 replace `ERD: see ...` placeholder with `See ERD-{NNN}`. Only edit the SPEC if it is still `draft`.

5. **Update `EPIC-PIPELINE.md`.** Under the epic's ERD section (create if missing), append `| ERD-{NNN} {title} | draft |`.

6. **Grill pass.** Read `skills/grill-substrate.md` (single source for stance, scratch-block format, and `grilled:` frontmatter schema). Then:

   - **Mode (per repo, Resolution Z):** for each `repo` in the ERD's `target_repos`, use `/domain-grill` when `${WB_ROOT}/context/<repo>/CONTEXT.md` exists, otherwise fall back to `/grill-me` for that repo.
   - **Prompt (Option-B with teeth, batched):**
     ```
     ERD-{NNN} drafted at engineering/outputs/erd/ERD-{NNN}-{slug}.md.
     Targets: repo-A (domain-grill), repo-B (grill-me, no CONTEXT.md), ...
     Prior grill: <none | YYYY-MM-DD depth (resolved N, parked M)>
     Run grill now? Depth? [deep|standard|quick] (default: deep)
     [Y/n/skip-this-session]
     ```
     Default Y on first run. Default n if `grilled.date` is current and artifact mtime less than or equal to `grilled.date`.
   - **Execute sequentially.** On `Y`, for each target repo: pre-stage the `erd` stance from §1 of `grill-substrate.md` + the scratch-block format from §2, then invoke `Skill("domain-grill" | "grill-me", args=<depth>)` with `cwd=${WB_ROOT}/context/<repo>/` for domain-grill, or `cwd=${WB_ROOT}` for the fallback.
   - **Record per pass.** Append scratch block + atomically extend `grilled.passes` (tempfile + rename). Per-pass durability.
   - **Abort / skip / cascade-resume.** Per §4 cheat-sheet. Cascade prompt default Y. Never blocks.

7. **Tell the user:**

   > ERD-{NNN} drafted. Review, then:
   > ```
   > wb.publish ERD-{NNN} engineering/outputs/erd/ERD-{NNN}-{slug}.md erd
   > wb.approve ERD-{NNN}   # after review
   > ```

## Output contract

- Creates: `engineering/outputs/erd/ERD-{NNN}-{slug}.md` with `status: draft`.
- Modifies: `EPIC-PIPELINE.md`, and the SPEC if still `draft`.

## Do not

- Do not embed screenshots — Mermaid only, so diagrams review as text in PRs.
- Do not invent services or tables. Every box must map to a repo in `project.conf` or an approved SPEC section.
- Do not produce an ERD without at least one of the three diagram types. Empty ERDs clutter the pipeline.
