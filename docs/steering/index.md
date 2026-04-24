---
layout: default
title: Steering workflow
permalink: /steering/
---

# Steering workflow

Steering is the set of golden principles, role rules, and artifact rules that AI agents working in a stamped workbench must follow. It is authored by senior engineers and architects (org-wide source of truth) and consumed by every session, every role, every skill. Teams add local overrides when they genuinely need to diverge; those overrides are visible to architects through a weekly drift digest.

This page covers the workflow end to end, split by role. For the directory layout and file format, see `steering/README.md` inside any stamped workbench.

---

## How the three layers work

```
Layer 0, Golden principles              always loaded at session start
Layer 1, Role rules (dev, qa, po, uxd)  loaded on role-inference match
Layer 2, Artifact rules (prd, bdd, ...) loaded as step 0 of each skill
Layer 2, Topic rules (api-design, ...)  loaded on demand by skills
```

Progressive disclosure keeps context windows lean. The typical peak load for a task (Layer 0 + current role + current artifact) is around 4,500 tokens, compared to about 20,000 if all steering were always loaded.

Each layer is a directory of one-file-per-rule markdown documents with YAML frontmatter. The loader (`scripts/steering-load.py <scope>`) walks the template tree and the team-local overlay tree, applies overlay semantics, and emits a single merged markdown blob that the agent reads as hard rules. The loader is the only sanctioned way to consume steering; agents do not merge in their heads.

---

## Who does what

### Architecture Council, Principal / Staff SWE, Director of Engineering

**Ownership**

- `steering/golden-principles/`, cross-cutting rules for every agent.
- `steering/roles/dev/`, engineering role rules.
- `steering/roles/po/`, product role rules.
- `steering/artifacts/eng-spec/`, `tdd/`, `erd/`, `adr/`, engineering artifact rules.
- `steering/artifacts/prd/`, jointly with the Director of Engineering (CODEOWNERS).
- `steering/topics/`, cross-cutting topic rules (api-design, and so on).

**Authoring workflow**

1. Propose a new rule by opening a PR on the `ai-workbench` template repo that adds a file under the correct directory. Filename is `<ID>-<slug>.md`; ID uses the directory's prefix (`GP-`, `DEV-`, `PO-`, `ESPEC-`, `TDD-`, `API-`, ...).
2. The PR triggers the steering-lint CI workflow. Lint validates frontmatter schema, ID regex (`^[A-Z]+(-LOCAL)?-\d{2,3}$`), and overlay-only field placement.
3. CODEOWNERS for the target directory review. Merging into `main` ships the rule to every stamped workbench via `update.wb`.
4. To deprecate a rule, do not delete the file. Add a new rule that `supersedes: [OLD-ID]`. This preserves historical references in PRs, docs, and past artifacts.

**Reviewing team overrides**

- The weekly drift digest (every Monday) opens an issue in the template repo listing every non-empty `steering.local/` in the org. See each team's added / superseded / removed overlays, the owner, the file path, and the rule IDs affected.
- Triage the digest:
  - If several teams added the same kind of rule, pull that pattern into the template (promote the team's PR, or draft a template-side version).
  - If a team superseded a core rule, start a conversation about whether the core rule should change or the team should back off.
  - If a team removed a core rule that applies org-wide, follow up directly.

**Promotion PRs**

Teams raise PRs to move a `steering.local/<path>/<ID>-LOCAL-NN.md` into the template as `steering/<path>/<ID>-NN.md`. CODEOWNERS for the target directory review these like any other steering change.

---

### QA Council

**Ownership**

- `steering/roles/qa/`, QA role rules.
- `steering/artifacts/bdd/`, `test-cases/`, `test-spec/`, QA artifact rules.
- `steering/topics/test-data/`, test-data topic rules.

**Workflow** identical to the Architecture Council, scoped to QA directories. CODEOWNERS gate PR merges so QA changes require QA Council review and do not land through a stray approval from elsewhere.

---

### UX Council

**Ownership**

- `steering/roles/uxd/`, UX role rules.

**Workflow** identical. CODEOWNERS on `steering/roles/uxd/`.

---

### Devs and QAs inside a stamped workbench

**You read, you do not author template steering directly.**

Per org policy (no forks), changes to template steering must come as PRs on the `ai-workbench` template repo, reviewed by CODEOWNERS. You still have three ways to influence the steering your agents see inside your workbench:

1. **Read what is loaded.** `wb.steering golden`, `wb.steering role:qa`, `wb.steering artifact:prd`, `wb.steering topic:test-data`. `wb.steering-refresh` reloads every scope.
2. **Add local overrides in `steering.local/`.** Three operations, all local to your workbench:

   **Add a team rule**, drop a new file at `steering.local/<path>/<DOMAIN>-LOCAL-NN-<slug>.md`:

   ```markdown
   ---
   id: PRD-LOCAL-01
   title: PRDs touching payments include a licensing section
   scope: artifact:prd
   owner: team-payments
   created: 2026-04-24
   ---
   **Rule:** ...
   ```

   **Supersede an upstream rule**, same file shape, with explicit `supersedes:` field. Filename convention uses the overlay's own ID:

   ```markdown
   ---
   id: PRD-LOCAL-02
   title: ACs must be testable AND time-boxed in staging
   scope: artifact:prd
   owner: team-payments
   created: 2026-04-24
   supersedes: [PRD-007]
   ---
   **Rule:** ...
   ```

   **Remove an upstream rule**, drop a sidecar file at `steering.local/<path>/<ID>.removed.md`:

   ```markdown
   ---
   id: PRD-003.removed
   removes: [PRD-003]
   owner: team-payments
   created: 2026-04-24
   reason: "Does not apply for this product line; see PRD-LOCAL-02."
   ---
   ```

3. **Promote local overrides upstream when they earn their stripes.** Open a PR on the `ai-workbench` template repo porting `steering.local/<path>/<ID>-LOCAL-NN.md` to `steering/<path>/<ID>-NN.md` (drop the `-LOCAL` infix). Explain in the PR body why the rule has org-wide value. CODEOWNERS for the target directory review.

**When working in a stamped workbench**

- `pmo-status` will show a "Steering overrides" section listing every entry in `steering.local/`. Review it at session start; promote or justify each one.
- Run `wb.steering-lint` locally before opening a PR on the template repo. The CI workflow enforces the same checks.
- Do not edit anything under `steering/` inside a stamped workbench. Those are template-owned; `update.wb` will overwrite your changes and your teammate's changes will silently disappear.

---

## Drift visibility

Drift visibility does not require an architect to join every stamped workbench. Three layered mechanisms:

- **M1, Local nag.** `pmo-status` surfaces local overrides in the current workbench every time someone runs it. No action on the team's part; silent when `steering.local/` is empty.
- **M2, Org-wide digest.** A GitHub Action in the template repo runs every Monday, queries the org via the GitHub API for every repo with the `ai-workbench` topic, reads each repo's `steering.local/`, and posts a digest issue in the template repo. Setup: [`docs/steering/setup.md`](./setup/).
- **M3, Promotion PRs.** Teams actively propose upstream promotion by opening a PR on the template repo; the PR lands in the CODEOWNERS' normal review queue, so architects see the active drift they care about most.

A fourth mechanism, `M4`, wires a drift footer into every ralph-authored code PR. That is parked until the ralph adapter work lands.

---

## Freshness

Steering is cached by each invocation of the loader. The freshness model has three triggers:

- **Per-skill hard load.** Every skill's step 0 runs the loader with the artifact and any declared topics as scopes. Always current at artifact-production time.
- **PostToolUse hook.** A Claude Code hook wired into `.claude/settings.json` re-runs the golden-scope loader after `update.wb`, `git pull`, `git merge`, or any Edit/Write touching `steering/**` or `steering.local/**`. Mid-session pulls pick up upstream changes automatically.
- **`wb.steering-refresh`.** Manual button. Reloads every scope. Use when you want to force a re-read without a triggering action (for example, an architect messages the team "pull latest steering and re-plan").

Non-Claude agents (Devin) rely on the per-skill hard load plus a post-merge shell hook. The manual refresh alias works for every agent.

---

## Tooling reference

| Command | Purpose |
|---------|---------|
| `wb.steering <scope>` | Load merged rules for one scope. |
| `wb.steering-refresh` | Load every scope. |
| `wb.steering-lint` | Validate `steering/` and `steering.local/`. |
| `scripts/steering-load.py <scope>` | Direct loader invocation (what the aliases wrap). |
| `scripts/steering-lint.py` | Direct linter. |
| `.github/workflows/steering-lint.yml` | CI lint on every PR touching steering. |
| `.github/workflows/drift-digest.yml` | Weekly Monday digest issue. |

See also [GitHub App setup](./setup/) for the drift-digest credentials.
