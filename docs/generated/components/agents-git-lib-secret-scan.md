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

| Component | Relationship |
|-----------|-------------|
| `agents/git/lib/hooks.sh` | called_by |
| `C-004` | called_by |
| `tests/unit/test_secret_scan.bats` | called_by |
| `tests/unit/test_secret_scan.bats` | tests_by |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-secret-scan.yaml`*
*Last verified: 2026-05-15*
