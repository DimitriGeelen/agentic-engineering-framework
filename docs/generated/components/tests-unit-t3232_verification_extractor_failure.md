# t3232_verification_extractor_failure

> T-3232 — extraction FAILURE must not read as "this task has no Verification section".

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3232_verification_extractor_failure.bats`

## What It Does

T-3232 — extraction FAILURE must not read as "this task has no Verification section".
Finding C3 of the arc-012 review. `extract_verification_block` ended in
`|| true`, so every failure of every stage collapsed into the exact value the
function returns for a task that legitimately has no `## Verification` block:
empty stdout, exit 0. update-task.sh read that as "nothing to verify" and
returned green having run ZERO commands and printed NOTHING.
The defect was never that extraction can fail. It is that failure was
INDISTINGUISHABLE from success-with-nothing-to-do. Measured before the fix:
clean block            -> 12 bytes, rc=0
same block + one 0xff  ->  0 bytes, rc=0     <-- same answer, different world

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [verification-port](/docs/generated/lib-verification-port) | tests | lib/verification-port.sh — hard-coded Watchtower port detection (T-2732) |
| [verify_queue](/docs/generated/lib-verify_queue) | tests | T-2765: re-run stored ## Verification for the human review queue. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3232_verification_extractor_failure.yaml`*
*Last verified: 2026-08-31*
