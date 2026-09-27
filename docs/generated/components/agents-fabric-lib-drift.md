# drift

> Fabric Agent - drift detection commands

**Type:** script | **Subsystem:** component-fabric | **Location:** `agents/fabric/lib/drift.sh`

## What It Does

Fabric Agent - drift detection commands
Implements: fw fabric drift, fw fabric validate

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fabric](/docs/generated/agents-fabric-fabric) | called_by | Fabric Agent - Component topology system for codebase self-awareness |
| [test_fabric_drift_absolute_paths](/docs/generated/tests-unit-test_fabric_drift_absolute_paths) | called_by | T-1673 — fabric drift orphan check honours absolute location paths. |
| [t3049_fabric_url_location](/docs/generated/tests-unit-t3049_fabric_url_location) | called_by | T-3049 — a card's `location:` is not always a filesystem path. |
| [t3049_fabric_url_location](/docs/generated/tests-unit-t3049_fabric_url_location) | tests_by | T-3049 — a card's `location:` is not always a filesystem path. |

## Documentation

- [Deep Dive: Component Fabric](docs/articles/deep-dives/07-component-fabric.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-fabric-lib-drift.yaml`*
*Last verified: 2026-02-20*
