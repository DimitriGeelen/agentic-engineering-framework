# yaml

> YAML manipulation helpers: Python-based read/write for YAML frontmatter in task files. Used by update-task.sh.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/yaml.sh`

## What It Does

lib/yaml.sh — Shared YAML frontmatter field extraction
Provides get_yaml_field() to replace the inconsistent
grep/sed/cut patterns duplicated across 30+ files.
Usage: source "$FRAMEWORK_ROOT/lib/yaml.sh"

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `lib/paths.sh` | called_by |
| `tests/unit/lib_yaml.bats` | called-by |
| `tests/unit/lib_yaml.bats` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-yaml.yaml`*
*Last verified: 2026-03-11*
