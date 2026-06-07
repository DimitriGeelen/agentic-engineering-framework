# secret-scan

> TODO: describe what this component does

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/secret-scan.sh`

## What It Does

agents/git/lib/secret-scan.sh — Secret-scan library for the pre-commit hook (T-1844).
Origin: T-1828/T-1834 incident — an Azure DevOps PAT was committed to framework
history at 79e3361d (T-1736 spike). GitHub mirror blocked for 9+ hours.
The framework had no structural gate against secrets reaching commits.
This module is invoked by the pre-commit hook installed by
agents/git/lib/hooks.sh:install_hooks. It can also be run standalone:
secret-scan.sh scan-staged       Scan git staged diff (the hook's mode)
secret-scan.sh scan-tree         Scan the entire working tree (audit mode)
secret-scan.sh scan-file <path>  Scan a specific file
Configuration:

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [test_secret_scan](/docs/generated/tests-unit-test_secret_scan) | called_by | TODO: describe what this component does |
| [test_secret_scan](/docs/generated/tests-unit-test_secret_scan) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-secret-scan.yaml`*
*Last verified: 2026-05-15*
