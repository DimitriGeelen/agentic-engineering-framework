# audit_anchor_task_existence

> T-1856 (T-NEW-8): anchor_task existence audit check.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/audit_anchor_task_existence.bats`

## What It Does

T-1856 (T-NEW-8): anchor_task existence audit check.
When an arc YAML declares anchor_task: T-XXX and that task does not exist
in .tasks/{active,completed}/, audit emits a WARN — never FAIL.
Symmetric to T-1849's arc_id validation (which guards task→arc); this
guards arc→task. Matches T-1846 §4 D4 (warn not block).
T-3356 restructure. These tests previously drove `audit.sh --section structure`
end-to-end. That section nests `timeout 300 bats tests/lint/` (108 invariants,
audit.sh check_invariant_suite), so the file exceeded 180s even against an
EMPTY fixture corpus and its four failure-path tests were killed mid-run —
reported as reds when they were timeouts (T-3356 RCA; measured rc=124).

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-anchor-task](/docs/generated/lib-audit-anchor-task) | tests | T-1856 anchor_task existence detection — extracted from agents/audit/audit.sh by T-3356 so the check is reachable without running the whole `--section structure` block. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_anchor_task_existence.yaml`*
*Last verified: 2026-05-16*
