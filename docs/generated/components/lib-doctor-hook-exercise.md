# doctor-hook-exercise

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/doctor-hook-exercise.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | called_by | Session Resume Hook — Reinject structured context on session recovery |

---
*Auto-generated from Component Fabric. Card: `lib-doctor-hook-exercise.yaml`*
*Last verified: 2026-05-01*
