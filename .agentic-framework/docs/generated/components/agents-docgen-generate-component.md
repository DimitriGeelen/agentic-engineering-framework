# generate-component

> Generates component reference documentation from fabric cards

**Type:** script | **Subsystem:** watchtower | **Location:** `agents/docgen/generate-component.sh`

**Tags:** `docs`, `docgen`

## What It Does

Component Reference Doc Generator
T-364: Generates markdown reference docs from Component Fabric data
Usage:
fw docs [component-card.yaml]
fw docs --all
Output: docs/generated/components/{card-name}.md

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [generate_component](/docs/generated/agents-docgen-generate_component) | calls | Python implementation for component reference documentation generation from fabric cards |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [docgen_component](/docs/generated/tests-unit-docgen_component) | tested_by | Unit tests for agents/docgen/generate-component.sh (6 tests) |
| [docgen_component](/docs/generated/tests-unit-docgen_component) | called_by | Unit tests for agents/docgen/generate-component.sh (6 tests) |
| [docgen_component](/docs/generated/tests-unit-docgen_component) | tests_by | Unit tests for agents/docgen/generate-component.sh (6 tests) |

---
*Auto-generated from Component Fabric. Card: `agents-docgen-generate-component.yaml`*
*Last verified: 2026-03-11*
