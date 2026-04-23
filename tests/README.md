# Smoke tests

Run `./tests/smoke.sh` from the workbench root to exercise the full local three-stage lifecycle: stamp template → render configs → register repos → draft/publish/approve → sync-context routing → reject round-trip. No GitHub, no network.

Run `./tests/smoke.sh --keep` to retain the temp workbench for inspection.
