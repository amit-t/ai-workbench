# ralph/ — workspace-mode ralph state

Workspace-level summary of what ralph planned across repos. Per-repo fix_plans live at `repos/<name>/.ralph/fix_plan.md` — ralph's native location.

## Files

| File | Source | Purpose |
|------|--------|---------|
| `workspace-plan.md` | `wb.ralph-plan` | Human-readable rollup: which tasks went to which repo, which PRDs/specs they came from. |
| `dispatch.log` | `wb.ralph-dispatch` | Log of parallel loop launches, PIDs, exit codes. Gitignored. |

## Workflow

1. `wb.sync-context` — pushes approved workbench artifacts into each `repos/<x>/ai/`.
2. `wb.ralph-plan` — runs ai-ralph in workspace mode; writes per-repo fix_plans + the rollup here.
3. `wb.ralph-dispatch` — launches parallel loops in each repo.
4. Monitor each repo's `.ralph/logs/` for progress.
