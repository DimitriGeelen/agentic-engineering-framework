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

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | tests | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [handover](/docs/generated/agents-handover-handover) | tests | Handover Agent - Mechanical Operations |
| [config](/docs/generated/lib-config) | tests | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [config](/docs/generated/web-blueprints-config) | tests | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover_digest.yaml`*
*Last verified: 2026-08-16*
