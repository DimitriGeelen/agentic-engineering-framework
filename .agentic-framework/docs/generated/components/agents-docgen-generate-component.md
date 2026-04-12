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

| Target | Relationship |
|--------|-------------|
| `agents/docgen/generate_component.py` | calls |
| `lib/paths.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `tests/unit/docgen_component.bats` | tested_by |
| `tests/unit/docgen_component.bats` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-docgen-generate-component.yaml`*
*Last verified: 2026-03-11*
