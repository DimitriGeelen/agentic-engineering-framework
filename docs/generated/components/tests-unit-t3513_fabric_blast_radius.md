# t3513_fabric_blast_radius

> T-3513: blast_radius falls back to paths NAMED in the task body, resolved through the component fabric — and unknown stays unknown (None), never 0.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3513_fabric_blast_radius.bats`

## What It Does

T-3513: blast_radius falls back to paths NAMED in the task body, resolved
through the component fabric — and unknown stays unknown (None), never 0.
Hermetic: a fixture project with its own .fabric/components graph (incl. a
cycle). Never anchored to the live fabric, whose size changes weekly (T-3326).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3513_fabric_blast_radius.yaml`*
*Last verified: 2026-11-23*
