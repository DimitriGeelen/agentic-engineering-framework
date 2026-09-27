# secret-scan

> agents/git/lib/secret-scan.sh — Secret-scan library for the pre-commit hook (T-1844).

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

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [test_secret_scan](/docs/generated/tests-unit-test_secret_scan) | called_by | T-1844 — pre-commit secret-scan hook (agents/git/lib/secret-scan.sh). |
| [test_secret_scan](/docs/generated/tests-unit-test_secret_scan) | tests_by | T-1844 — pre-commit secret-scan hook (agents/git/lib/secret-scan.sh). |
| [secret_scan_span_rule](/docs/generated/tests-unit-secret_scan_span_rule) | called_by | T-2898: the ANNOUNCED pair must match at NON-OVERLAPPING SPANS. |
| [secret_scan_span_rule](/docs/generated/tests-unit-secret_scan_span_rule) | tests_by | T-2898: the ANNOUNCED pair must match at NON-OVERLAPPING SPANS. |
| [upgrade_fresh_machine_simulation](/docs/generated/tests-unit-upgrade_fresh_machine_simulation) | tests_by | T-1635: fresh-machine simulation guard for fw upgrade. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-secret-scan.yaml`*
*Last verified: 2026-05-15*
