# test_fabric_exclude

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_fabric_exclude.bats`

## What It Does

T-1842 — fabric expand_patterns helper honours exclude:.
Origin: Penelope (email-archive) T-1458 via framework:pickup offsets 5/6.
Both do_scan (register.sh) and do_drift (drift.sh) read patterns: only and
silently dropped exclude:. Penelope's .fabric had 5946/6339 (93.8%) junk
node_modules cards undetected for ~22 days because the bug appears
identically in both code paths.
These tests pin:
- per-pattern exclude removes matching files
- top-level exclude removes matching files across all patterns
- without exclude, behaviour is unchanged

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_fabric_exclude.yaml`*
*Last verified: 2026-05-14*
