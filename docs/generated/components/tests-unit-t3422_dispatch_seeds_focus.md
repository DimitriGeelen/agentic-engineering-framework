# t3422_dispatch_seeds_focus

> T-3422 — dispatch pre-seeds the worker's session-scoped focus file.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3422_dispatch_seeds_focus.bats`

## What It Does

T-3422 — dispatch pre-seeds the worker's session-scoped focus file.
T-3038 gave each dispatched worker its own focus.<name>.yaml but never
created it, so until the worker's first `fw work-on` the gate's deliberate
fallback served the SHARED focus.yaml — and the worker read a foreign, real,
unrelated task as its own (SEQ-T3411 Δ8, four rounds running).
`fw_focus_seed <root> <task>` (lib/paths.sh) writes the scoped file at
dispatch time with the worker's own --task, through the SAME resolver the
reader uses (L-399 parity). Hermetic: every file here lives under a tmpdir.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [termlink](/docs/generated/agents-termlink-termlink) | tests | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3422_dispatch_seeds_focus.yaml`*
*Last verified: 2026-09-22*
