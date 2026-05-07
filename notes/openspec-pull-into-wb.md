# OpenSpec → ai-workbench: brief

**Status: PARKED 2026-05-07.** Higher-priority work first. Resume entry point: "Sharpened wave plan" section — Wave 1 (A2 DAG-as-YAML + #3 wb.status --json + A4 --json everywhere) all S-effort, unblock rest. Analysis complete; no more research before build.

Date: 2026-05-06 (initial), 2026-05-07 (deeper-scan additions)
Source: https://openspec.dev, https://github.com/Fission-AI/OpenSpec

## TL;DR

OpenSpec adds a layer workbench lacks: **living capability specs as system source-of-truth**, with **deltas**, **fingerprints**, and **archive-merge**. Steering tells agent *how* to work; OpenSpec specs tell agent *what system is*. Different axis. Keep steering, add OpenSpec layer underneath.

Top 5 to pull:
1. Capability specs (`engineering/capabilities/<cap>/spec.md`)
2. Delta syntax (`## ADDED / MODIFIED / REMOVED Requirements`)
3. Fingerprints + `wb.sync` (parallel-team safety)
4. `wb.archive <epic>` (merge deltas, write changelog)
5. Lite vs Full PRD path (progressive rigor)

## OpenSpec primitives (compressed)

| Primitive | Shape | Workbench analog |
|---|---|---|
| `specs/<cap>/spec.md` | living behavior contract; SHALL + Given-When-Then | none |
| `changes/<id>/proposal.md` | why/what/scope | PRD |
| `changes/<id>/design.md` | tech approach | engineering spec |
| `changes/<id>/tasks.md` | impl checklist | TDD + ralph fix_plan |
| `changes/<id>/specs/<cap>/spec.md` | delta with ADDED/MODIFIED/REMOVED blocks | none |
| `archive/<date>-<id>/` | completed change; deltas merged into living specs | none (PRDs pile forever) |
| `meta.json` fingerprint | SHA of base requirement; blocks stale archives | none |
| `openspec validate` | structural + fingerprint check | `validate-artifact.py` (frontmatter only) |
| `openspec status` | scope, ready-for-apply, structural errors | `EPIC-PIPELINE.md` (manual) |
| workspace.yaml + local.yaml | shared vs machine-local split | `project.conf` (mixed) |
| `/opsx:propose / apply / archive / verify / onboard / bulk-archive` | slash commands | `/epic-intake /prd-draft /eng-spec /tdd /bdd-gen /ralph-*` |
| Lite vs Full spec | progressive rigor by risk | none (full pipeline always) |
| `change sync` (3-way merge, proposed) | conflict markers per requirement | none |

## Ranked moves (ROI / effort)

| # | Move | Effort | ROI |
|---|---|---|---|
| 1 | `engineering/capabilities/<cap>/spec.md` tree + INDEX.md generator | M | huge |
| 2 | Delta syntax in PRDs/eng-specs; `affects_capabilities:` frontmatter | M | huge |
| 3 | `wb.status` auto-derived; kill manual `EPIC-PIPELINE.md` | S | high |
| 4 | `wb.archive <epic>` merges deltas + moves to `product/archive/` + writes changelog | M | high |
| 5 | Fingerprint snapshot in `published.json`; `wb.approve` checks freshness; `wb.sync <epic>` rebase | M-L | huge under parallelism |
| 6 | Lite vs Full PRD path; `risk:` frontmatter | S | high |
| 7 | `engineering/capabilities/_invariants/spec.md` + `affirms_invariants:` validator gate | S | huge for arch-sacrosanct |
| 8 | Capability `owners:` frontmatter + CODEOWNERS-style approval at `wb.approve` | S | high |
| 9 | ADR linkage `enforces_adrs:` in capability requirements; auto-context-inject | S | medium |
| 10 | `wb.doctor` cross-validator | S | medium |
| 11 | Split `project.conf` shared vs `.workbench-local/local.conf` machine-local | S | medium |
| 12 | `wb.onboard` skill (replaces 8-step session-start) | S | medium |
| 13 | `wb.verify <epic>` PR-diff vs delta+tasks coverage check | M | medium |
| 14 | `wb.bulk-archive --release vX` batched archive + auto release notes | M | medium |
| 15 | CI gate: `wb.doctor && wb.status --strict` on `dev` branch | S | huge once #5 ships |
| 16 | Stable requirement IDs (`REQ-CHK-007`) + ID-based deltas | L | medium |
| 17 | Telemetry on fingerprint misses, owner-gate fires | S | low-medium |
| 18 | Tool-agnostic artifacts (Codex/Cursor can also read capabilities) | S | strategic optionality |

Bundle: ship **1+2+3+6+7** as "capability layer v1" first. Then **4+5+8+15** as "parallelism v1" once second stamped wb appears. 13+14+16 = polish.

## Brainchain (causal walk)

```
human attention scarce as parallel teams scale
  → agents decide without architect in loop
  → agents need system's current truth, not just PR-local context
  → need machine-readable, diff-able source-of-truth
  → capability specs (OpenSpec primitive)
  → deltas not full-doc replacement (else parallel epics overwrite)
  → fingerprints + sync (else deltas merge wrong order, lose work)
  → archive merges deltas atomically + release snapshot
  → status + doctor surface drift fast
  → ownership + invariants gate edits
  → ADRs ride attached to requirements
  → CI enforces fingerprint-fresh + invariant-affirmed
  ⇒ N parallel teams ship epics, arch stays sacrosanct
```

Each link forced by previous. OpenSpec walked links 1-7. Workbench needs 1-9.

## Futureback (2027 view, 6 wbs / 12 pairs / 18 capabilities)

Failure modes without OpenSpec layer:
- Silent capability drift (last-merged wins, prior scenarios vanish)
- Architectural rot (agent forgets ADR-008, no reviewer catches at 2am)
- PRD-fatigue review (architect rubber-stamps, review quality → 0)
- Onboarding cost explodes (no durable capability index)
- Release notes are archeology (grep PRs)
- Cross-wb collision (two wbs push conflicting fix_plans to same repo)

State with OpenSpec primitives integrated:
- Capability specs = system memory
- Invariants + ADR linkage = guardrails as code, agent sees rules inline
- Fingerprints = parallel-safe; auto-rebase or hard-flag
- `wb.status` + `wb.doctor` = automated review; architect intervenes only on gate fire
- `wb.archive` = release ledger; per-capability changelog auto-generated
- Capability ownership distributes architectural authority to 2 owners per surface
- Lite-path PRDs ship in hours; full-path days; 3-5x trivial throughput

**Architecture sacrosanct emerges from**: invariants-as-spec + capability owners + fingerprint-fresh CI + agent-context auto-injection. Not from "more reviews".

**Multi-team scaling emerges from**: capability index + spec deltas + auto archive + ownership distribution. Not from more architects.

## Sharp claims

- Delta + fingerprint + archive triplet is the **single most valuable** thing to import. Without it, multi-team-with-agents = silent capability rot.
- Workbench steering is *better* than OpenSpec equivalents. Don't rip out. OpenSpec adds behavior-truth layer underneath; steering stays as agent-behavior layer on top.
- `EPIC-PIPELINE.md` should die. Replace with generated `wb.status`. Manual status rots within weeks.
- `target_repos:` (workbench) and `affects_capabilities:` (proposed) are **different routings**. target_repos = which code repo gets fix. capability = which behavior surface changes. Keep both. Name distinctly.
- Architecture-sacrosanct ≠ more reviews. = invariants-as-spec + ownership + CI gate + agent-context auto-injection. Converts architect attention into code.
- `change sync` (3-way merge of deltas) is killer for 2027 scenario. OpenSpec hasn't shipped (still in plan). Workbench could ship first and contribute back.

## Decision points (ask self before building)

1. Capability specs = new tree, or fold into existing `engineering/outputs/`? (Recommend new tree: `engineering/capabilities/`. Outputs/ stays per-epic; capabilities/ stays per-surface.)
2. Lite-path skip-list: which artifacts? (Recommend: skip eng-spec/TDD/ERD; keep PRD+BDD+ralph-plan.)
3. Owner-gate: where enforced? (Recommend: `wb.approve` checks GitHub CODEOWNERS-style file at `engineering/capabilities/OWNERS.yaml`.)
4. Fingerprint storage: in `published.json` only, or also in PRD frontmatter? (Recommend: `published.json` only; keeps PRD authorable by hand.)
5. Archive trigger: manual `wb.archive <epic>` or auto on Jira Done webhook? (Recommend: manual first, automate after pattern stabilizes.)

## Open questions

- How does invariant spec interact with template-vs-team steering split? (Likely: invariants ship in template, teams cannot override. Capabilities ship per-team.)
- Does ralph need to know about deltas, or only about approved tasks.md? (Likely: ralph stays delta-blind; `sync-context.sh` flattens deltas into prose tasks before ralph sees them.)
- Migration: existing PRDs in stamped wbs — bulk-archive or leave? (Recommend: leave historic; require new format only for post-rollout PRDs.)

## Sources

- https://openspec.dev/
- https://github.com/Fission-AI/OpenSpec/
- https://github.com/Fission-AI/OpenSpec/blob/main/WORKSPACE_REIMPLEMENTATION_DIRECTION.md
- https://github.com/Fission-AI/OpenSpec/blob/main/openspec-parallel-merge-plan.md
- https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md

---

# Additions after deeper scan (2026-05-07)

Re-scanned full local clone + dogfooded `openspec/specs|changes|explorations`. Below: 8 missed primitives, 6 refinements to existing 18, brainchain extension (4 new links), 2028 futureback, sharpened wave plan, 4 new sharp claims, 2 new decision points, 3 open questions.

## Missed primitives (A1-A8, ranked by leverage)

### A1. `/opsx:explore` — no-artifact thinking skill

OpenSpec ships explicit "investigate, compare, draw diagrams, do not commit" skill (`docs/commands.md:73-124`). Workbench has zero equivalent. PO/dev pair has no "think out loud" affordance — defaults to `/prd-draft` too early.

**Add `wb.explore`.** No frontmatter writes. Conversational + Mermaid. Promotes to `/prd-draft` only when scope crystallizes. **Effort: S, ROI: high.** Kills premature-PRD churn.

### A2. Artifact DAG machine-queryable, not CLAUDE.md prose

DAG already exists — "Downstream skill preconditions" table in `CLAUDE.md:60-71`. OpenSpec formalizes same idea as YAML (`openspec/schemas/spec-driven/schema.yaml`). Move to `steering/config.yaml` `artifacts:` section. Then `wb.status --change EPIC-123 --json` emits:

```json
{"artifacts":[
  {"id":"prd","status":"approved"},
  {"id":"eng-spec","status":"draft"},
  {"id":"tdd","status":"blocked","missingDeps":["eng-spec"]},
  {"id":"bdd","status":"ready"}
]}
```

**Highest-leverage S-effort change.** Wave 1 keys off it. Build first.

### A3. `wb.instructions <artifact> --json` — agent queries CLI for context

OpenSpec pattern (`docs/opsx.md:484-518`): agent runs CLI, gets template + dependency contents + unlocks. Workbench skills are markdown agent must read + mentally compose. Move template + context-injection + unlocks into CLI:

- Deterministic context payload. No skill-prose drift across sessions.
- Plumbable into Codex/Cursor without per-tool skill rewrites.
- Telemetry: instructions-fetched-but-not-completed = abandoned drafts.

**Effort: M, ROI: high.** On-ramp to A4 + A8 + A6.

### A4. `--json` everywhere

`lifecycle.py list` only prints human text (`scripts/lifecycle.py:255-287`). Agent-first system without JSON = agents hallucinate. Add `--json` to: `wb.published`, `wb.approved`, `wb.rejected`, `wb.steering`, future `wb.status`, future `wb.doctor`. **Effort: S, ROI: medium-high.**

### A5. Bulk-archive agentic conflict resolution by inspecting code

`docs/commands.md:495-547`: when two changes touch same spec, agent reads implementation, sees what shipped, merges in reality-order. Third leg of parallel-safety stool:

```
fingerprint   = block stale archives    (detection)
sync 3-way    = fix divergence          (mechanism)
inspect-code  = arbitrate post-ship     (recovery)
```

Workbench: when two wbs both ship fix_plans against `payments-svc` and second's PRD fingerprint-stale, recovery = `wb.bulk-archive --inspect`: scan merged repo, decide truth, write reconciled PRD-of-record. **Effort: M-L, ROI: huge in 2027+.**

### A6. Multi-tool adapter pattern

OpenSpec generates skills for 25+ tools from one source (`src/core/converters/`). Workbench hardwired to Claude Code. Fine at 1 pair/wb. Breaks when Codex pair joins or Cursor side-by-side review wanted.

Don't ship multi-tool now. Make architectural choice early: **skill source-of-truth = one file per skill + transformer per tool.** Before 18 hand-edited skills exist. **Effort: deferred, ROI: strategic optionality.**

### A7. `wb.doctor` first-class preflight (promote from #10 to ~#5)

OpenSpec `workspace doctor` (`docs/concepts.md:160-167`) = consolidated health. Workbench has `wb.ralph-enable-check`, `wb.steering-lint`, `wb.steering-audit` — no aggregator. Add checks: orphaned `published.json` entries with no file, `target_repos:` referencing unregistered repos, fingerprint-stale approved PRDs (after #5), dead-pid-held lock files. **Effort: S, ROI: high.** Single command on CI gate.

### A8. Three-dimension verify: completeness × correctness × coherence

OpenSpec `/opsx:verify` (`docs/commands.md:318-383`):

| Dim | Question | Workbench analog |
|---|---|---|
| Completeness | Every requirement got code; every scenario got test | Tasks/BDD coverage |
| Correctness | Code matches spec *intent* not just *letter* | Currently human-only |
| Coherence | Design.md decisions actually appear in code; no silent drift | Currently nothing |

**Coherence** = the unique one for arch-sacrosanct. All tasks done + all tests green + still shipped hand-rolled retry when eng-spec said "use `RetryClient`". `wb.verify` runs grep + LLM coherence check on PR diff vs eng-spec. **Catches violations without architect reviewing every PR.** **Effort: M, ROI: huge.** OpenSpec doesn't have it either — workbench can lead.

## Refinements to existing 18

- **#3 `wb.status`** — promote to *first* visible build. Dashboard A2/A4/A7 surface through. Killing `EPIC-PIPELINE.md` is side effect.
- **#5 fingerprint** — store inside PRD frontmatter *and* `published.json`. Belt + suspenders. PRD copied across wbs keeps frontmatter, loses ledger. Cheap.
- **#7 invariants** — needs hardness rule: invariants mutable only via Layer-0 ADR + ≥2 capability-owner sign. Only stable state. Free mutation = trampled; no mutation = ossified or routed-around.
- **#8 owner-gate** — borrow change-folder convention: `OWNERS.yaml` *next to* `spec.md`, not global. Scales linearly with capabilities, not team size.
- **#16 stable IDs** — leapfrog. No UUIDs (unreviewable in PRs). Use semantic IDs (`CHK-001`, `AUTH-014`), uniqueness validated by extended `steering-lint`. OpenSpec hasn't decided this — workbench can lead.
- **#12 `wb.onboard`** — *replaces* 8-step session-start in `CLAUDE.md`, not supplements. Current 8-step = human-prose-overhead every new pair re-reads. Guided 20-min walk through real epic = durable.

## Brainchain (4 new links)

```
... + invariants must be mutable but mutation high-ceremony
       (else ossify or dissolve, no middle ground)
    + ADRs ride attached to requirements (frontmatter link, auto-injected)
    + verify across completeness × correctness × coherence
       (else drift hides under green CI)
    + CI enforces fingerprint-fresh + invariant-affirmed + coherence-passed
       (only place attention pays uniformly across N PRs)
  ⇒ N teams ship, arch sacrosanct, architect attention scales sub-linearly
```

Forcing logic:
- *Mutable+expensive invariants:* immutable → engineers route around; cheap → agents trample. Only stable = mutable + ceremonial.
- *ADR linkage:* without it, why-behind-rule divorces from rule; agents see rule, route around when why feels stale.
- *Coherence:* without it, design↔code drift accumulates silently. Tests pass on letter; intent rots; next agent infers wrong invariant from code.
- *CI gate:* humans can't review N parallel PRs. Gate = only uniform-attention surface. Everything above must be machine-checkable to land here.

## Futureback — 2028 (12 wbs / 24 pairs / multi-tool)

2027 (6/12/18) is conservative. Interesting failures at 2028.

**With OpenSpec layer:**
- 12 wbs, ~3 with Codex pairs alongside Claude.
- 40+ capabilities, 8 invariants.
- ~200 archived changes, deltas merged.
- Architect headcount still 1-2. Spend time on invariant-exception ADRs + ownership reassignment, not PR review.
- New pair onboard <1hr via `wb.onboard` + capability INDEX.

**Without:**
- "We have CHK process" — three teams' versions of `EPIC-PIPELINE.md`, all stale.
- Architect = bottleneck. 30% fix_plans rejected for forgetting ADR-008. 70% smuggle violations through green CI.
- Two teams ship overlapping `target_repos: [payments-svc]`. Ralph parallel. Second PR overwrites first's session-token logic. Unnoticed for week.
- New pair onboarding = 3 days = "ask Sarah".
- Senior leaves, was human OWNERS file. Capabilities now unowned, agents silently rewrite.

**Strategic prize not named in original:** workbench = **distribution mechanism**. OpenSpec ships discipline as npm. Workbench ships discipline + steering + ralph + parallelism as stamped template. Capability layer makes scaffolding *valuable* across teams — without it shipping process; with it shipping enforcement.

Architectural authority distributes from architects-as-people to **capabilities-as-files-with-owners**. Template is what makes that distribution mechanically possible.

## Sharpened wave plan (replaces original bundle)

**Wave 1 — "see truth":** A2 + A4 + #1 + #3 + #6 + #7. `wb.status --json` works; agents query; humans browse `engineering/capabilities/INDEX.md`; trivial PRDs ship lite. **Demo:** new pair sets up wb, runs `wb.status`, sees system without asking human.

**Wave 2 — "stay safe parallel":** #4 + #5 + #8 + A7 + #15. Triggered when wb count = 2. **Demo:** two wbs modify capability X; second's `wb.publish` fails fingerprint-fresh; `wb.sync` resolves; CI green only after both clean.

**Wave 3 — "verify shipped":** A8 + #13 + A5 + #14. Triggered when archive count ~20. **Demo:** `wb.verify EPIC-123` reports completeness 100% / correctness OK / coherence WARN with specific design-decision missing in code.

**Wave 4 — "scale beyond Claude":** A6 + A1 + A3 + #18. Triggered when first non-Claude pair joins.

Sequencing: skip Wave 2 forever as 1 wb. Wb #2 stamped → Wave 2 non-optional. Wave 3 = architect-attention-multiplier, matters when architect says "I can't review all this".

## Sharp claims (4 new, append to original 6)

7. Workbench three-stage lifecycle (draft/published/approved) > OpenSpec filesystem-existence model. Captures human-approval events, matters at multi-team. Don't downgrade. Do derive `wb.status` from filesystem-DAG-state for unapproved drafts so agents see ready-to-publish.

8. Schema-as-DAG (A2) = single highest-leverage S-effort change. Wave 1 keys off it. Day 1.

9. Coherence-checking (A8) uniquely doesn't exist anywhere. Completeness/correctness tool-able with grep+tests. Coherence needs LLM judgment on design.md vs code. Workbench's chance to lead OpenSpec.

10. Invariants-as-spec ossify if mutation free; dissolve if impossible. Mutation-ceremony rule (≥2 owners + Layer-0 ADR + steering exception) = what makes arch-sacrosanct load-bearing. Without it, A1-A8 = scaffolding routed around.

## Decision points (2 new, append to original 5)

6. **DAG location?** Recommend: extend `steering/config.yaml` with `artifacts:` section. Single config, one loader produces both steering merge + DAG status.

7. **`wb.status` JSON shape?** Recommend: copy OpenSpec verbatim — `{change, scope, artifacts:[{id,status,missingDeps}], readyForApply}`. Cross-tool compat free if matches. Forking standard for no reason = waste.

## Open questions (3 new)

- **Capability layer co-exist or compete with repo-internal OpenSpec?** Some Invenco repos may run OpenSpec internally. Tentative: workbench capabilities = system-level cross-repo behavior; repo OpenSpec = internal. Different scopes, different files. Agents need to know which authority is which → coexistence ADR worth writing now.

- **Do capability deltas eventually obviate eng-specs?** If `payments/checkout/spec.md` has full SHALL+scenario and PRD = delta, what's eng-spec for? Tentative: eng-spec = HOW, capability = WHAT. Different. Many current eng-specs duplicate WHAT — migration could shrink 30-60%.

- **`wb.archive` trigger: ralph PR merge or Jira Done?** OpenSpec archives on user command. Ralph PRs land async. Jira Done = truth event but webhook-coupled. Tentative: manual `wb.archive <epic>` first (already in decision #5), automate on Jira Done after pattern stabilizes.
