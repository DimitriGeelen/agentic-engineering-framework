# lib_review

> Unit tests for review (10 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_review.bats`

**Tags:** `review`, `bats`, `unit-test`

## What It Does

Unit tests for lib/review.sh
Tests emit_review() — human review output helper

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [review](/docs/generated/lib-review) | calls | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [review](/docs/generated/lib-review) | tests | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_review.yaml`*
*Last verified: 2026-04-05*
