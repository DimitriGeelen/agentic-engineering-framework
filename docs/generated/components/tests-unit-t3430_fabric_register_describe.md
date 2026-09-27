# t3430_fabric_register_describe

> T-3430: `fw fabric register` derives purpose/subsystem instead of writing placeholders — and says so out loud when it cannot.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3430_fabric_register_describe.bats`

## What It Does

T-3430: `fw fabric register` derives purpose/subsystem instead of writing
placeholders — and says so out loud when it cannot.
The card is the artefact a human (and every index over .fabric/) reads, so
the properties pinned here are: a described file gets a real sentence plus
its provenance; an undescribed file keeps the TODO *and* prints the refusal;
and the subsystem routes off .fabric/subsystems.yaml paths: patterns rather
than the hard-coded case block register.sh used to carry.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [register](/docs/generated/agents-fabric-lib-register) | tests | Fabric Agent - register and scan commands |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3430_fabric_register_describe.yaml`*
*Last verified: 2026-09-22*
