# audit-anchor-task

> T-1856 anchor_task existence detection — extracted from agents/audit/audit.sh by T-3356 so the check is reachable without running the whole `--section structure` block.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/audit-anchor-task.sh`

## What It Does

T-1856 anchor_task existence detection — extracted from agents/audit/audit.sh
by T-3356 so the check is reachable without running the whole `--section
structure` block.
Why the extraction exists (T-3356 RCA): the check itself is ~20 lines and
runs in milliseconds, but it lived inline inside a 2400-line section that also
invokes `timeout 300 bats tests/lint/` (audit.sh check_invariant_suite). Any
test that wanted to exercise the anchor rule had to pay for a full nested
suite run, which put the file over 180s even against an empty fixture corpus
and made its four failure-path tests read as reds when they were timeouts.
Detection now lives here; audit.sh remains the sole emitter of warn/pass_over.

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit_anchor_task_existence](/docs/generated/tests-unit-audit_anchor_task_existence) | tests_by | T-1856 (T-NEW-8): anchor_task existence audit check. |

---
*Auto-generated from Component Fabric. Card: `lib-audit-anchor-task.yaml`*
*Last verified: 2026-09-09*
