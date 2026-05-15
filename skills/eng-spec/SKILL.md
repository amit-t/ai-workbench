---
name: eng-spec
description: Engineering spec at status=draft from an approved PRD. Covers architecture, contracts, data, rollout, observability.
category: Engineering
relevant_topics: [api-design]
---

# /eng-spec

## When to use

User has an approved PRD and wants to draft the engineering spec.

## Prerequisites

- PRD has `status: approved` AND `.workbench-state/approved.json` contains `PRD-{NNN}`.
- `project.conf` REPOS is populated.

## Steps

0. **Load steering.** Run `wb.steering artifact:eng-spec` and then `wb.steering topic:api-design` (declared in this skill's frontmatter). Treat the merged rulesets as hard constraints on every section written below.

0.5. **Precision check.** Resolve `PRECISION_MODE` — env `WB_PRECISION_MODE` > `project.conf PRECISION_MODE` > default `on`. If `on`, invoke `Skill("precision-mode")` and announce one line: `Precision mode on for this run.` Carry the resolved value into the SPEC frontmatter as `precision_mode: on|off` at write time. The directive applies for the rest of this host run (artifact body, grill pass, next-steps tail). See `.agents/skills/precision-mode/SKILL.md`.

1. **Read the PRD** (frontmatter + all sections). Identify outcomes and constraints.

2. **Read engineering context.** `engineering/context-library/` for stack notes; `engineering/outputs/adrs/` for relevant prior decisions (approved ADRs only).

3. **Pick SPEC number** (scan `engineering/outputs/specs/SPEC-*.md`, max + 1, zero-padded three digits). Slug matches the PRD slug.

4. **Identify target repos.** For each entry in `project.conf REPOS`, decide modified? y/n with a one-liner. Capture the yes-entries as `target_repos:` in frontmatter (validated at `wb.publish` / `wb.approve` — missing or unknown names block the transition).

5. **Write `engineering/outputs/specs/SPEC-{NNN}-{slug}.md`:**

   ```markdown
   ---
   id: SPEC-{NNN}
   title: {title}
   status: draft
   created: {today}
   owner: {gh-user}
   epic: {EPIC_ID}
   prd: PRD-{NNN}
   target_repos: [{repo-1}, {repo-2}]
   precision_mode: {on | off}
   ---

   # SPEC-{NNN}: {title}

   ## 1. Scope
   Tied to PRD-{NNN}. {paragraph summary.}

   ## 2. Target repositories
   | Repo | Role | Change summary |
   |------|------|---------------|

   ## 3. Architecture impact
   - Services touched:
   - Ports (hexagonal): inbound / outbound changes
   - Cross-service contracts:
   - New components:

   ## 4. API and contracts
   - **{METHOD} /path** — purpose
     - Request / Response shapes
     - Error envelope
     - Breaking? migration plan

   ## 5. Data model
   ### Schema changes
   - {table/collection}: {add|modify|remove}
   - Migration: forward + rollback
   ### ERD
   See `engineering/outputs/erd/ERD-{NNN}.md` (draft via `/erd`).

   ## 6. Rollout plan
   - Feature flag: {name or none}
   - Deploy order:
   - Dark-launch period:
   - Backfill:

   ## 7. Observability
   - Metrics (name, unit, alert threshold)
   - Logs (new events)
   - Traces (spans)
   - Dashboards (link or "TBD")

   ## 8. Failure modes
   | Failure | Blast radius | Detection | Mitigation |
   |---------|--------------|-----------|------------|

   ## 9. Rollback plan
   {concrete steps; if irreversible, justify.}

   ## 10. Risks and open questions

   ## 11. Dependencies
   - ADRs:
   - Other SPECs:
   - External teams:
   ```

6. **Update `EPIC-PIPELINE.md`.** Set the PRD row's `Spec` column to `SPEC-{NNN}`, `Exec` row unchanged.

7. **Grill pass.** Read `skills/grill-substrate.md` (single source for stance, scratch-block format, and `grilled:` frontmatter schema). Then:

   - **Mode (per repo, Resolution Z):** for each `repo` in the SPEC's `target_repos`, use `/domain-grill` when `${WB_ROOT}/context/<repo>/CONTEXT.md` exists, otherwise fall back to `/grill-me` for that repo.
   - **Prompt (Option-B with teeth, batched):**
     ```
     SPEC-{NNN} drafted at engineering/outputs/specs/SPEC-{NNN}-{slug}.md.
     Targets: repo-A (domain-grill), repo-B (grill-me, no CONTEXT.md), ...
     Prior grill: <none | YYYY-MM-DD depth (resolved N, parked M)>
     Run grill now? Depth? [deep|standard|quick] (default: deep)
     [Y/n/skip-this-session]
     ```
     Default Y on first run. Default n if `grilled.date` is current and artifact mtime less than or equal to `grilled.date`.
   - **Execute sequentially.** On `Y`, for each target repo: pre-stage the `eng-spec` stance from §1 of `grill-substrate.md` + the scratch-block format from §2, then invoke `Skill("domain-grill" | "grill-me", args=<depth>)` with `cwd=${WB_ROOT}/context/<repo>/` for domain-grill, or `cwd=${WB_ROOT}` for the fallback.
   - **Record per pass.** After each pass: append a scratch block (one per pass, header records repo + mode + depth) and atomically extend the `grilled.passes` list with this pass's record (tempfile + rename). One pass's record is durable even if a later pass aborts.
   - **Abort / skip / cascade-resume.** Follow §4 cheat-sheet. On `stop grill` mid-pass, ask whether to cascade-abort remaining repos (default Y). Never blocks; outcomes flow to `wb.publish` (warning) and review panels (P2 finding).

8. **Tell the user:**

   > SPEC-{NNN} drafted (status: draft). Review, then:
   > ```
   > wb.publish SPEC-{NNN} engineering/outputs/specs/SPEC-{NNN}-{slug}.md eng-spec
   > wb.approve SPEC-{NNN}   # after review
   > ```
   > Next: `/tdd SPEC-{NNN}` once approved.

## Output contract

- Creates: `engineering/outputs/specs/SPEC-{NNN}-{slug}.md` with `status: draft`.
- Modifies: `EPIC-PIPELINE.md`.

## Do not

- Do not include class-level pseudocode here — that is `/tdd`'s job.
- Do not produce a spec without an approved PRD. Refuse and instruct user.
