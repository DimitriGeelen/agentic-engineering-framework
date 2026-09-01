# t3232_verification_extractor_failure

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3232_verification_extractor_failure.bats`

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

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3232_verification_extractor_failure.yaml`*
*Last verified: 2026-08-31*
