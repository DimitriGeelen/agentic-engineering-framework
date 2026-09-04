# conftest

> TODO: describe what this component does

**Type:** script | **Subsystem:** watchtower | **Location:** `web/conftest.py`

## What It Does

No fw env → assume framework-repo mode (local hacking).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `web-conftest.yaml`*
*Last verified: 2026-09-03*
