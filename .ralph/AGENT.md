# Ralph Agent Configuration — ai-workbench template

## Build

No build step. This is a shell + Python + Markdown repo.

## Test

```bash
bash tests/smoke.sh
```

The smoke harness prints `PASSED` and an assertion count on success. Currently 22/22 (pre-V2 baseline). If your task changes the contract being asserted, update `tests/smoke.sh` in the same PR.

Steering lint (run when touching anything under `steering/`):

```bash
python3 scripts/steering-lint.py
```

Artifact validator (run when touching `scripts/lifecycle.py` or `scripts/validate-artifact.py`):

```bash
python3 scripts/validate-artifact.py --schema scripts/artifact-schema.json <path-to-artifact>
```

## Run

Aliases live in `aliases.sh`. Source it once per shell:

```bash
source aliases.sh
```

Then use `wb.*` commands. See `CLAUDE.md` "Key commands" section.

## Notes

- Python 3 required (`python3` on PATH).
- `flock` used for `.workbench-state/.lock`; macOS ships compatible `flock` via shellutils or via the macOS `lockf` shim — confirm before adding new code that uses it.
- `jq` required for state files.
- `gh` CLI required for any PR-related work.
