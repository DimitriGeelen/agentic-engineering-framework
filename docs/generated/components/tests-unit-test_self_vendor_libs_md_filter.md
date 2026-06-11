# test_self_vendor_libs_md_filter

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_self_vendor_libs_md_filter.bats`

## What It Does

T-2307 (T-2304 follow-on): `_self_vendor_libs` extended to recursive + `*.md` filter.
Surfaces under test:
- lib/upgrade.sh:_self_vendor_libs() — now mirrors `_self_vendor_agents` shape
(T-2266+T-2304): while-read-find loop, *.sh + *.md filter, recursive
traversal with parent-dir mkdir at real-run, dry-run/real-run wording split.
- Audit's libs-class drift scanner (agents/audit/audit.sh:1644) already scans
`*.sh + *.md` — this test pins the helper-SYNC side of the leg.
Sibling: tests/unit/test_self_vendor_agents_md_filter.bats (T-2304) pins the
same leg for `_self_vendor_agents`. Both helpers share the same shape; both
tests use the same fixture pattern (synthetic FRAMEWORK_ROOT with drift in

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_self_vendor_libs_md_filter.yaml`*
*Last verified: 2026-06-10*
