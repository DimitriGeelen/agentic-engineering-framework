# handover_digest

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/handover_digest.bats`

## What It Does

T-3028 (T-3025 GO, option 3): the three state dumps digest to
count + regenerating command + top-N; the narrative does not change.
Runs the real generator against a synthetic corpus (TASKS_DIR / CONTEXT_DIR /
HANDOVER_DIR are overridable per the lib/paths.sh test-fixture invariant), so
these are end-to-end assertions on generated output rather than on a fixture
someone captured once and stopped maintaining.
The assertion that matters most is not "the file got smaller" — it is that
digest-off reproduces the undigested sections unchanged. A size win that cannot
be reversed is a migration, and this candidate was chosen over the 10x one
precisely because it is subtraction you can undo.

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover_digest.yaml`*
*Last verified: 2026-08-16*
