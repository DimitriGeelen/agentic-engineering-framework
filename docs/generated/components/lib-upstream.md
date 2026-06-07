# upstream

> Safe issue creation from field installations to framework upstream repo. Resolves upstream repo from .framework.yaml or git remotes. Supports dry-run, confirmation, fw doctor attachment, patch attachment, and sent-file tracking.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/upstream.sh`

**Tags:** `upstream`, `gh-cli`, `field-report`

## What It Does

lib/upstream.sh — Safe issue/PR creation from field installations to framework repo
Part of the Agentic Engineering Framework
Inception: T-451 | Build: T-454

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [init](/docs/generated/lib-init) | reads | fw init - Bootstrap a new project with the Agentic Engineering Framework |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [lib_upstream](/docs/generated/tests-unit-lib_upstream) | called-by | Unit tests for upstream (22 tests) |
| [lib_upstream](/docs/generated/tests-unit-lib_upstream) | called_by | Unit tests for upstream (22 tests) |
| [lib_upstream](/docs/generated/tests-unit-lib_upstream) | tests_by | Unit tests for upstream (22 tests) |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-upstream.yaml`*
*Last verified: 2026-03-12*
