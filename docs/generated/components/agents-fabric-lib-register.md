# register

> Fabric Agent - register and scan commands

**Type:** script | **Subsystem:** component-fabric | **Location:** `agents/fabric/lib/register.sh`

## What It Does

Fabric Agent - register and scan commands
Implements: fw fabric register, fw fabric scan

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fabric](/docs/generated/agents-fabric-fabric) | called_by | Fabric Agent - Component topology system for codebase self-awareness |
| [t2457_fabric_atomic_card_write](/docs/generated/tests-unit-t2457_fabric_atomic_card_write) | called_by | T-2457 / OBS-080: fabric card writes must be atomic. |
| [t2457_fabric_atomic_card_write](/docs/generated/tests-unit-t2457_fabric_atomic_card_write) | tests_by | T-2457 / OBS-080: fabric card writes must be atomic. |
| [t3430_fabric_register_describe](/docs/generated/tests-unit-t3430_fabric_register_describe) | tests_by | T-3430: `fw fabric register` derives purpose/subsystem instead of writing placeholders — and says so out loud when it cannot. |

## Documentation

- [Deep Dive: Component Fabric](docs/articles/deep-dives/07-component-fabric.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-fabric-lib-register.yaml`*
*Last verified: 2026-02-20*
