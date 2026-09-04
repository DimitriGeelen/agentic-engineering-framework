# generate_component

> Python implementation for component reference documentation generation from fabric cards

**Type:** script | **Subsystem:** watchtower | **Location:** `agents/docgen/generate_component.py`

**Tags:** `docs`, `docgen`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [learnings-data](/docs/generated/learnings-data) | calls | Persistent store of all project learnings. Read by web UI and audit. Written by add-learning command. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [generate-component](/docs/generated/agents-docgen-generate-component) | calls | Generates component reference documentation from fabric cards |
| [generate-component](/docs/generated/agents-docgen-generate-component) | called_by | Generates component reference documentation from fabric cards |
| [test_docgen](/docs/generated/agents-docgen-test_docgen) | called_by | TODO: describe what this component does |
| [test_docgen](/docs/generated/agents-docgen-test_docgen) | uses_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-docgen-generate_component.yaml`*
*Last verified: 2026-03-12*
