# sidecar_inbox_hook

> T-3407 — sidecar-inbox UserPromptSubmit hook: silent-when-empty, surfaces when pending, peeks (never consumes), fails open.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/sidecar_inbox_hook.bats`

## What It Does

T-3407 — sidecar-inbox UserPromptSubmit hook: silent-when-empty, surfaces
when pending, peeks (never consumes), fails open.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [sidecar-inbox](/docs/generated/agents-context-sidecar-inbox) | tests | sidecar-inbox.sh — UserPromptSubmit hook: surface pending peer consults. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-sidecar_inbox_hook.yaml`*
*Last verified: 2026-09-21*
