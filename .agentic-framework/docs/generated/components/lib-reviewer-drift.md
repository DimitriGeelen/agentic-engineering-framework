# drift

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/drift.py`

## What It Does

File reference extraction
Matches: relative paths starting with ./ or just dir/file.ext, absolute paths,
and common stems mentioned in test/grep/python -c contexts.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit](/docs/generated/lib-reviewer-audit) | called_by | TODO: describe what this component does |
| [drift_cli](/docs/generated/lib-reviewer-drift_cli) | called_by | TODO: describe what this component does |
| [test_reviewer_audit_pass_a](/docs/generated/tests-unit-test_reviewer_audit_pass_a) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-drift.yaml`*
*Last verified: 2026-05-06*
