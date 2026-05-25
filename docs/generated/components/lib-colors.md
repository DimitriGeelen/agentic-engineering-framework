# colors

> Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/colors.sh`

## What It Does

lib/colors.sh — Shared color variables for the Agentic Engineering Framework
Provides TTY-aware, NO_COLOR-respecting color variables.
Replaces inline color definitions duplicated across 20+ scripts.
Usage: source "$FRAMEWORK_ROOT/lib/colors.sh"
Variables: RED, GREEN, YELLOW, CYAN, BOLD, NC
Automatically sourced via lib/errors.sh → lib/paths.sh chain.
Scripts that source lib/paths.sh get colors for free.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |

## Used By (45)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [colors](/docs/generated/lib-colors) | called-by | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [costs](/docs/generated/lib-costs) | called-by | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |
| [lib_colors](/docs/generated/tests-unit-lib_colors) | called-by | Unit tests for colors (6 tests) |
| [handover](/docs/generated/agents-handover-handover) | called_by | Handover Agent - Mechanical Operations |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [colors](/docs/generated/lib-colors) | called_by | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [costs](/docs/generated/lib-costs) | called_by | Token usage tracking from JSONL transcripts — parses Claude Code session data for cost reporting (T-801) |
| [lib_colors](/docs/generated/tests-unit-lib_colors) | called_by | Unit tests for colors (6 tests) |
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
| [lib_colors](/docs/generated/tests-unit-lib_colors) | tests_by | Unit tests for colors (6 tests) |
| [lib_dispatch](/docs/generated/tests-unit-lib_dispatch) | called_by | Unit tests for dispatch (9 tests) |
| [lib_dispatch](/docs/generated/tests-unit-lib_dispatch) | tests_by | Unit tests for dispatch (9 tests) |
| [lib_harvest](/docs/generated/tests-unit-lib_harvest) | called_by | TODO: describe what this component does |
| [lib_harvest](/docs/generated/tests-unit-lib_harvest) | tests_by | TODO: describe what this component does |
| [lib_inception](/docs/generated/tests-unit-lib_inception) | called_by | Unit tests for inception (12 tests) |
| [lib_inception](/docs/generated/tests-unit-lib_inception) | tests_by | Unit tests for inception (12 tests) |
| [lib_init](/docs/generated/tests-unit-lib_init) | called_by | TODO: describe what this component does |
| [lib_init](/docs/generated/tests-unit-lib_init) | tests_by | TODO: describe what this component does |
| [lib_pickup](/docs/generated/tests-unit-lib_pickup) | called_by | TODO: describe what this component does |
| [lib_pickup](/docs/generated/tests-unit-lib_pickup) | tests_by | TODO: describe what this component does |
| [lib_promote](/docs/generated/tests-unit-lib_promote) | called_by | TODO: describe what this component does |
| [lib_promote](/docs/generated/tests-unit-lib_promote) | tests_by | TODO: describe what this component does |
| [lib_review](/docs/generated/tests-unit-lib_review) | called_by | Unit tests for review (10 tests) |
| [lib_review](/docs/generated/tests-unit-lib_review) | tests_by | Unit tests for review (10 tests) |
| [lib_setup](/docs/generated/tests-unit-lib_setup) | called_by | Unit tests for setup (2 tests) |
| [lib_setup](/docs/generated/tests-unit-lib_setup) | tests_by | Unit tests for setup (2 tests) |
| [lib_update](/docs/generated/tests-unit-lib_update) | called_by | Unit tests for update (3 tests) |
| [lib_update](/docs/generated/tests-unit-lib_update) | tests_by | Unit tests for update (3 tests) |
| [lib_upgrade](/docs/generated/tests-unit-lib_upgrade) | called_by | TODO: describe what this component does |
| [lib_upgrade](/docs/generated/tests-unit-lib_upgrade) | tests_by | TODO: describe what this component does |
| [lib_version](/docs/generated/tests-unit-lib_version) | called_by | Unit tests for version (16 tests) |
| [lib_version](/docs/generated/tests-unit-lib_version) | tests_by | Unit tests for version (16 tests) |
| [test_upgrade_downgrade_guard](/docs/generated/tests-unit-test_upgrade_downgrade_guard) | called_by | TODO: describe what this component does |
| [test_upgrade_downgrade_guard](/docs/generated/tests-unit-test_upgrade_downgrade_guard) | tests_by | TODO: describe what this component does |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-colors.yaml`*
*Last verified: 2026-03-11*
