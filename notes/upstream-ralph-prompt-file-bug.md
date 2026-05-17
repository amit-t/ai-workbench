# Upstream bug — ai-ralph Devin workspace --prompt-file relative-path

## Status
Reported 2026-05-13 from wb-gitlore workspace plan runs. Workaround pinned in workbench: set `RALPH_PLAN_ENGINE="claude"` and `RALPH_EXECUTION_ENGINE="claude"`. This file is the handoff brief for a Claude session inside `~/Projects/Tools-Utilities/ai-ralph` to fix it.

## Repro
1. Workspace-enabled parent dir: `repos/` with `repos/.ralph/` and at least one registered code repo.
2. Run any workspace plan invocation with engine devin:
     `ralph-plan --workspace --engine devin`
   or via the workbench:
     `(cd repos && ralph-devin --workspace --parallel 5 10)`
3. ralph-plan computes a per-repo prompt file path and calls `workspace_plan_run_engine` (lib/workspace_plan.sh) with that path.

## Symptom
- Claude and Codex engines: succeed.
- Devin engine: Devin CLI errors with "prompt file not found" (path resolved against the wrong dir). Workspace plan run aborts, no `<repo>.out.md` produced, downstream parsing fails.

## Root cause
File: `lib/workspace_plan.sh`
Function: `workspace_plan_run_engine` (around line 198)

Sequence:
- Line ~237: `prompt_content=$(cat "$prompt_file")` reads the prompt file while still at the caller's cwd. Used only by Claude / Codex paths (positional content), so the read succeeds even when `$prompt_file` is relative to the caller's cwd.
- Line ~240: `cd "$repo_path"` changes cwd into the per-repo subdir (e.g., `repos/gitlore/`).
- Lines ~245-258 (claude) and ~260 (codex): pass `$prompt_content` (the slurped string) as a positional argument. Path string is no longer referenced post-cd, so these engines are insulated from the cd.
- Lines ~262-267 (devin): pass `$prompt_file` (the path string) via `--prompt-file`. Devin CLI receives the path AFTER the cd into `$repo_path`. If the caller supplied a relative path, Devin now resolves it against `$repo_path` instead of the original cwd, and the file is not found.

The function's docstring at line ~195 promises `prompt_file (absolute)`, but the function does not enforce the contract. Devin is the only engine that takes the path string at face value post-cd, so it is the only engine that breaks when the contract is violated by a caller.

## Recommended fix (defensive, at the function)

Resolve `$prompt_file` to an absolute path before the cd, and use the absolute form in the Devin path. One-line patch:

    @@ workspace_plan_run_engine
         local prompt_content
         prompt_content=$(cat "$prompt_file")
    +    # Resolve to absolute before cd so Devin's --prompt-file does not
    +    # break when a caller passes a relative path (contract requires
    +    # absolute, but defending the callee hardens future callers too).
    +    prompt_file="$(cd "$(dirname "$prompt_file")" && pwd)/$(basename "$prompt_file")"

         local _saved_pwd="$PWD"
         cd "$repo_path" || return 1

`realpath` is shorter but behaves differently on macOS without coreutils. Stick with `cd; pwd` for portability.

## Optional secondary fix (caller side)
Audit every caller of `workspace_plan_run_engine`. Primary caller is the workspace plan orchestrator in `ralph_plan.sh` (or `lib/workspace_plan.sh` itself). Ensure each caller resolves `prompt_file` to absolute before calling. Defensive callee + correct caller = belt-and-suspenders.

## Test plan
1. Bats unit on `workspace_plan_run_engine` with `$prompt_file` set to a relative path. Mock the Devin CLI with a script that asserts `--prompt-file` arg is absolute (matches `^/`). Pre-fix fails, post-fix passes.
2. Integration: workspace mode against a two-repo fixture with engine=devin. Should produce output files for both repos. Pre-fix: fails on first repo. Post-fix: succeeds.
3. Regression: existing Claude / Codex workspace plan tests should remain green.

## Why this matters
Workspace mode is the primary multi-repo orchestration path. Devin is the default execution engine for ai-workbench (`RALPH_EXECUTION_ENGINE="devin"` in the template). Workbench users who set engine to devin cannot run workspace plan today, which forces them to pin Claude as a workaround. A downstream ai-workbench PR (feat/dispatch-engine-routing) adds binary routing for `wb.ralph-dispatch` that will route to `ralph-devin --workspace` correctly once this upstream bug is fixed; the workbench wrapper emits a soft warning when engine=devin pointing to this file.
