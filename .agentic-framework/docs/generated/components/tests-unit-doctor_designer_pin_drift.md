# doctor_designer_pin_drift

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/doctor_designer_pin_drift.bats`

## What It Does

T-2524 (T-2521 integration hardening): fw doctor content-compares (sha256, never
mtime) the vendored Workflow Designer build against policy/designer-pin.yaml.
Sibling of the MCP manifest + cron registry→generated drift checks.
Surface under test: bin/fw doctor designer-pin block.
States:
vendored sha256 == pin sha256           → OK    — t1
vendored sha256 != pin sha256           → WARN  — t2
vendored file absent (per pin path)     → SKIP  — t3
pin present but missing sha256/path     → SKIP  — t4
HERMETIC (T-2547): the pin drift check honors FW_DESIGNER_PIN_FILE. Each test points

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-doctor_designer_pin_drift.yaml`*
*Last verified: 2026-07-10*
