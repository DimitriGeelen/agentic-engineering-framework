# cmd_classify

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/cmd_classify.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [prescribed-commands-are-allowed](/docs/generated/tests-lint-prescribed-commands-are-allowed) | tests_by | TODO: describe what this component does |
| [t2919_budget_gate_command_classify](/docs/generated/tests-unit-t2919_budget_gate_command_classify) | tests_by | TODO: describe what this component does |
| [t2923_cmd_classify_heredoc](/docs/generated/tests-unit-t2923_cmd_classify_heredoc) | called_by | TODO: describe what this component does |
| [t2923_cmd_classify_heredoc](/docs/generated/tests-unit-t2923_cmd_classify_heredoc) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-cmd_classify.yaml`*
*Last verified: 2026-08-11*
