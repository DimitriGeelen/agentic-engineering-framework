# provision

> Provisions the Antigravity/OpenGravity (AGY) provider package into a target project (T-2417)

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/sessions/antigravity/provision.sh`

## What It Does

provision.sh — Provision Antigravity / OpenGravity (AGY) provider package in target project

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [antigravity_steps](/docs/generated/lib-antigravity_steps) | called_by | antigravity_steps.py — Antigravity Workflow Step Engine for AEF |

---
*Auto-generated from Component Fabric. Card: `agents-sessions-antigravity-provision.yaml`*
*Last verified: 2026-09-08*
