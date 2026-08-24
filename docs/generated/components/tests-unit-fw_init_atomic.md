# fw_init_atomic

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/fw_init_atomic.bats`

## What It Does

T-2801 — fw init must leave either nothing or a working project.
do_vendor's include list copies `bin` FIRST, and .framework.yaml is not written
until ~120 lines after the vendor call. So from roughly one second into an init
until it finishes, the target directory holds an executable
.agentic-framework/bin/fw belonging to a framework that is not all there yet.
T-2805 update: FRAMEWORK.md used to be copied eighth of twelve, inside that
window. It is now written LAST, after every other vendor write, and the router
tests for it — so the window is closed by an observed signal as well as by the
declared marker this file was written for. See tests/unit/fw_vendor_completeness.bats.
bin/fw-router routed on `[ -x <dir>/.agentic-framework/bin/fw ]` alone, so it

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-fw_init_atomic.yaml`*
*Last verified: 2026-08-04*
