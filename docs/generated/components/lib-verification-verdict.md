# verification-verdict

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/verification-verdict.sh`

## What It Does

lib/verification-verdict.sh — unjudged-test-run detection (T-2738)
Single definition of the predicate. Sourced by:
- agents/task-create/update-task.sh  (the P-011 close gate)
- tests/unit/verification_unjudged_test_run.bats
It lives here rather than inline in the gate for the same reason as its sibling
lib/verification-port.sh: the regression suite has to run the REAL predicate
over the real corpus. A test that re-types the producer's expression into a
local helper can only ever check the sites its author already knew about
(L-533, from the T-2729/T-2730/T-2731 escape family).
Usage: source "$FRAMEWORK_ROOT/lib/verification-verdict.sh"

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |

---
*Auto-generated from Component Fabric. Card: `lib-verification-verdict.yaml`*
*Last verified: 2026-08-02*
