# yaml_pipefail

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/yaml_pipefail.bats`

## What It Does

T-1557 / L-302 — Regression: foundation YAML/config helpers must not
silent-kill the calling shell under set -e -o pipefail when the requested
field/key is absent.
Origin: T-1545 fixed one site (lib/review.sh emit_review). This pins the
same invariant for the foundation helpers (lib/yaml.sh:get_yaml_field +
lib/config.sh:_fw_config_file_val) so future callers cannot reintroduce
the trap by writing bare `var=$(get_yaml_field ...)` assignments.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [yaml](/docs/generated/lib-yaml) | calls | YAML manipulation helpers: Python-based read/write for YAML frontmatter in task files. Used by update-task.sh. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [config](/docs/generated/lib-config) | tests | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [yaml](/docs/generated/lib-yaml) | tests | YAML manipulation helpers: Python-based read/write for YAML frontmatter in task files. Used by update-task.sh. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-yaml_pipefail.yaml`*
*Last verified: 2026-04-27*
