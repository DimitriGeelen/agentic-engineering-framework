# test_task_create_description_yaml

> T-2778: `fw task create` must emit parseable frontmatter for multi-line descriptions.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_task_create_description_yaml.py`

## What It Does

Three paragraphs, deliberately covering both failure shapes: the second contains a
colon (the silent-truncation trigger), the third does not (the ScannerError trigger).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [create-task](/docs/generated/agents-task-create-create-task) | calls | Task Creation Agent - Mechanical Operations |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_task_create_description_yaml.yaml`*
*Last verified: 2026-08-03*
