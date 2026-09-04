# t3220_verification_gate_exits

> Pins that every failure path in run_verification_commands exits rather than returns, and that the choice does not depend on set -euo pipefail 1700 lines away. Four measured cells (exit/return x errexit present/absent) isolate the dependency; the two control cells stop the suite passing against anything.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3220_verification_gate_exits.bats`

**Tags:** `tests`, `bats`, `verification-gate`, `errexit-dependency`, `T-3220`

## What It Does

T-3220 — the P-011 gate's failure paths must EXIT, and the reason must be the
real one.
WHAT WENT WRONG. T-3219 shipped the reconciliation guard with `exit 1` and a
comment justifying it: "the caller (do_update) invokes this function BARE ...
so a non-zero return is discarded". Both halves were false. There is no
`do_update` in the file, and a bare call under `set -euo pipefail` (line 14)
aborts on a non-zero return — so `return 1` blocks too. Measured, one byte
apart, on the real script: both shapes print the ERROR and exit 1.
The fix was right; the stated mechanism was not. A comment describing a
mechanism is a model of it, and this one had drifted before the ink dried.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3220_verification_gate_exits.yaml`*
*Last verified: 2026-08-29*
