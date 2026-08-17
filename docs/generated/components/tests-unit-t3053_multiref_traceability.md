# t3053_multiref_traceability

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3053_multiref_traceability.bats`

## What It Does

T-3053 — a commit subject may name more than one task. The traceability check
read only the first ref, so a commit whose leading ref did not resolve was
reported orphaned even when a later ref named a real task.
Two sites carried the same `head -1` shape and they ask opposite questions:
commit subject   "is this commit traceable?"   -> ANY ref resolving suffices
practice Origin  "are these citations valid?"  -> EVERY ref must resolve
So one defect was a false FAIL at one site and a false GREEN at the other, and
the two need opposite fixes. Every test below pins a direction, not just a
behaviour, and both fixes are mutation-checked against a copy of audit.sh with
the `head -1` form restored.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3053_multiref_traceability.yaml`*
*Last verified: 2026-08-16*
