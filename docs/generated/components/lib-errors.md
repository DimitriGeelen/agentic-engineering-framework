# errors

> Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/errors.sh`

**Tags:** `shell`, `errors`, `output`, `usability`, `core`

## What It Does

lib/errors.sh — Consistent error/warning/info output for the framework
Provides colored, TTY-aware output functions with standardized exit codes.
Replaces ad-hoc echo/exit patterns across 25+ agent scripts.
Usage: source "$FRAMEWORK_ROOT/lib/errors.sh"
Functions:
die MESSAGE [EXIT_CODE]   — Print error and exit (default: 1)
error MESSAGE             — Print error to stderr (no exit)
warn MESSAGE              — Print warning to stderr
info MESSAGE              — Print info to stdout
success MESSAGE           — Print success to stdout

## Used By (34)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [healing](/docs/generated/agents-healing-healing) | calls | Healing Agent - Antifragile error recovery and pattern learning |
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [paths](/docs/generated/lib-paths) | called_by | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [lib_errors](/docs/generated/tests-unit-lib_errors) | called-by | Unit tests for errors (11 tests) |
| [lib_errors](/docs/generated/tests-unit-lib_errors) | called_by | Unit tests for errors (11 tests) |
| [inception_decide_ac_tick](/docs/generated/tests-unit-inception_decide_ac_tick) | called_by | Unit tests for T-1324 — tick_inception_decide_acs auto-ticks the templated [REVIEW]/[RUBBER-STAMP] Human AC after fw inception decide writes the Decision block, so the work-completed gate does not leave the task in partial-complete forever (G-008; P-039). |
| [inception_decide_ac_tick](/docs/generated/tests-unit-inception_decide_ac_tick) | tests_by | Unit tests for T-1324 — tick_inception_decide_acs auto-ticks the templated [REVIEW]/[RUBBER-STAMP] Human AC after fw inception decide writes the Decision block, so the work-completed gate does not leave the task in partial-complete forever (G-008; P-039). |
| [inception_decide_atomicity](/docs/generated/tests-unit-inception_decide_atomicity) | called_by | TODO: describe what this component does |
| [inception_decide_atomicity](/docs/generated/tests-unit-inception_decide_atomicity) | tests_by | TODO: describe what this component does |
| [inception_tick_decision_recorded](/docs/generated/tests-unit-inception_tick_decision_recorded) | called_by | TODO: describe what this component does |
| [inception_tick_decision_recorded](/docs/generated/tests-unit-inception_tick_decision_recorded) | tests_by | TODO: describe what this component does |
| [inception_tick_marker](/docs/generated/tests-unit-inception_tick_marker) | called_by | TODO: describe what this component does |
| [inception_tick_marker](/docs/generated/tests-unit-inception_tick_marker) | tests_by | TODO: describe what this component does |
| [lib_assumption](/docs/generated/tests-unit-lib_assumption) | called_by | Unit tests for assumption (11 tests) |
| [lib_assumption](/docs/generated/tests-unit-lib_assumption) | tests_by | Unit tests for assumption (11 tests) |
| [lib_bus](/docs/generated/tests-unit-lib_bus) | called_by | Unit tests for bus (24 tests) |
| [lib_bus](/docs/generated/tests-unit-lib_bus) | tests_by | Unit tests for bus (24 tests) |
| [lib_dispatch](/docs/generated/tests-unit-lib_dispatch) | called_by | Unit tests for dispatch (9 tests) |
| [lib_dispatch](/docs/generated/tests-unit-lib_dispatch) | tests_by | Unit tests for dispatch (9 tests) |
| [lib_errors](/docs/generated/tests-unit-lib_errors) | tests_by | Unit tests for errors (11 tests) |
| [lib_inception](/docs/generated/tests-unit-lib_inception) | called_by | Unit tests for inception (12 tests) |
| [lib_inception](/docs/generated/tests-unit-lib_inception) | tests_by | Unit tests for inception (12 tests) |
| [lib_init](/docs/generated/tests-unit-lib_init) | called_by | TODO: describe what this component does |
| [lib_init](/docs/generated/tests-unit-lib_init) | tests_by | TODO: describe what this component does |
| [lib_setup](/docs/generated/tests-unit-lib_setup) | called_by | Unit tests for setup (2 tests) |
| [lib_setup](/docs/generated/tests-unit-lib_setup) | tests_by | Unit tests for setup (2 tests) |
| [lib_update](/docs/generated/tests-unit-lib_update) | called_by | Unit tests for update (3 tests) |
| [lib_update](/docs/generated/tests-unit-lib_update) | tests_by | Unit tests for update (3 tests) |
| [lib_version](/docs/generated/tests-unit-lib_version) | called_by | Unit tests for version (16 tests) |
| [lib_version](/docs/generated/tests-unit-lib_version) | tests_by | Unit tests for version (16 tests) |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-errors.yaml`*
*Last verified: 2026-03-10*
