# yaml

> YAML manipulation helpers: Python-based read/write for YAML frontmatter in task files. Used by update-task.sh.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/yaml.sh`

## What It Does

lib/yaml.sh — Shared YAML frontmatter field extraction
Provides get_yaml_field() to replace the inconsistent
grep/sed/cut patterns duplicated across 30+ files.
Usage: source "$FRAMEWORK_ROOT/lib/yaml.sh"

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | called_by | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [lib_yaml](/docs/generated/tests-unit-lib_yaml) | called-by | Unit tests for yaml (8 tests) |
| [lib_yaml](/docs/generated/tests-unit-lib_yaml) | called_by | Unit tests for yaml (8 tests) |
| [healing_suggest](/docs/generated/tests-unit-healing_suggest) | called_by | Unit tests for healing suggest (9 tests) |
| [healing_suggest](/docs/generated/tests-unit-healing_suggest) | tests_by | Unit tests for healing suggest (9 tests) |
| [lib_yaml](/docs/generated/tests-unit-lib_yaml) | tests_by | Unit tests for yaml (8 tests) |
| [yaml_pipefail](/docs/generated/tests-unit-yaml_pipefail) | called_by | TODO: describe what this component does |
| [yaml_pipefail](/docs/generated/tests-unit-yaml_pipefail) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-yaml.yaml`*
*Last verified: 2026-03-11*
