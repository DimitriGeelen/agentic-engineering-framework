# t3798_handover_fixture_no_push

> T-3798 — handover.sh must not commit or push when HANDOVER_DIR lies outside the git repo at PROJECT_ROOT.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3798_handover_fixture_no_push.bats`

## What It Does

T-3798 — handover.sh must not commit or push when HANDOVER_DIR lies outside
the git repo at PROJECT_ROOT. Origin: handover_digest.bats pointed
HANDOVER_DIR at a fixture but left PROJECT_ROOT on the real repo; the commit
failed (pathspec outside the repo) and _push_to_remotes still pushed the real
repo's HEAD to origin, twice, from inside the unit suite.
Each behavioural leg leaves one LOCAL, UNPUSHED commit in the fixture repo, so
a push of any kind is visible as origin's master moving.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3798_handover_fixture_no_push.yaml`*
*Last verified: 2026-10-21*
