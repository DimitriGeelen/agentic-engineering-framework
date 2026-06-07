# test_secret_scan

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_secret_scan.bats`

## What It Does

T-1844 — pre-commit secret-scan hook (agents/git/lib/secret-scan.sh).
Origin: T-1828/T-1834 — an Azure DevOps PAT was committed at 79e3361d
(T-1736 Spike B, 2026-05-05). GitHub mirror has been GH013-blocked for
9+ hours. The framework had no structural gate against secrets reaching
commits. These tests pin the scanner's pattern catalogue + allowlist
semantics and the hook's bypass behaviour.
IMPORTANT: This file contains pattern-shaped strings used as test
fixtures. The .secret-scan-allowlist exempts this file by path so
the scanner doesn't self-trigger when running on the repo. The strings
below are synthesized to MATCH the patterns but are not real secrets.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | calls | TODO: describe what this component does |
| [secret-scan](/docs/generated/agents-git-lib-secret-scan) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_secret_scan.yaml`*
*Last verified: 2026-05-15*
