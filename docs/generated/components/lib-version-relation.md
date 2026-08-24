# version-relation

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/version-relation.sh`

## What It Does

T-2713 — one truthful answer to "is this consumer ahead or behind?".
THE DEFECT THIS REPLACES
Three sites open-coded the same comparison:
[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" = "$a" ] && ahead || behind
bin/fw:2015          doctor's consumer-fleet ahead/behind badge
lib/upgrade.sh:849   pre-step-1 runtime downgrade guard  (T-1912)
lib/upgrade.sh:1742  pin-rewrite downgrade guard         (T-1839)
`sort -V` orders version STRINGS. VERSION here is a tag counter that RESETS —
this repo's tags run v1.6.763, v1.6.762, v1.6.761, then v1.6.10, v1.6.9, and
VERSION itself has gone 1.6.354 -> 1.6.121 -> 1.6.176. A counter that resets

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t2762_upgrade_foreign_source_sha](/docs/generated/tests-unit-t2762_upgrade_foreign_source_sha) | tests_by | TODO: describe what this component does |
| [version_relation](/docs/generated/tests-unit-version_relation) | tests_by | TODO: describe what this component does |
| [upgrade](/docs/generated/lib-upgrade) | called_by | fw upgrade - Sync framework improvements to a consumer project |
| [t2762_upgrade_foreign_source_sha](/docs/generated/tests-unit-t2762_upgrade_foreign_source_sha) | called_by | TODO: describe what this component does |
| [version_relation](/docs/generated/tests-unit-version_relation) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-version-relation.yaml`*
*Last verified: 2026-08-01*
