# t2762_upgrade_foreign_source_sha

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2762_upgrade_foreign_source_sha.bats`

## What It Does

T-2762: a source repo that cannot resolve the consumer's recorded commit is not
a valid upgrade source.
THE DEFECT
fw_version_relation resolves the consumer's commit inside $froot — the framework
doing the upgrading (lib/version-relation.sh:86,89). A stale or foreign source is
exactly the repo that does NOT contain the consumer's sha or version tag, so cref
comes back empty and the relation is `undecidable`. With
FW_UNDECIDABLE_VERSION_PROCEED defaulting to 1, that WARNs and proceeds — and the
consumer is downgraded by a source that never held its code.
Measured before the fix, with the field numbers from the 2026-08-03 report:

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [version-relation](/docs/generated/lib-version-relation) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [version-relation](/docs/generated/lib-version-relation) | calls | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2762_upgrade_foreign_source_sha.yaml`*
*Last verified: 2026-08-03*
