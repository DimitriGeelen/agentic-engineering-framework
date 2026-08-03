# t2446_project_root_cwd_consistency

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2446_project_root_cwd_consistency.bats`

## What It Does

T-2446: bin/fw trusts CLAUDE_PROJECT_DIR ONLY when the cwd is not genuinely inside
a *different* real project. Origin: F10 / T-2441 dogfood — a TermLink shell rooted
in a consumer (/opt/505) inherited CLAUDE_PROJECT_DIR=/opt/999 from the long-lived
CC-spawned daemon and mis-resolved /opt/999's Watchtower. Same daemon-poison class
T-2391 fixed for inherited PROJECT_ROOT, extended to CLAUDE_PROJECT_DIR via the
shared _project_root_is_stale discriminator (=$HOME / no-marker = poison/hook).
Surface under test: bin/fw "Resolve PROJECT_ROOT" block (CLAUDE_PROJECT_DIR branch).
Observed via `fw version` ("Project: <root>").
Dual-case (the two halves of the contract):
(a) CC-hook / $HOME-poison: cwd-root is $HOME (or no marker) → CLAUDE_PROJECT_DIR wins

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2446_project_root_cwd_consistency.yaml`*
*Last verified: 2026-06-21*
