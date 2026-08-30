# t3219_verification_count_reconciliation

> Pins the P-011 verification gate against unreconciled counts: a stdin-reading verification command must not swallow the rest of the block, and pass+fail must equal total or the close is refused. Runs mutated copies of update-task.sh from a symlink farm because FRAMEWORK_ROOT is derived from script location.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3219_verification_count_reconciliation.bats`

**Tags:** `tests`, `bats`, `verification-gate`, `T-3219`

## What It Does

T-3219 — the P-011 gate must not pass on a count it cannot reconcile.
THE DEFECT. `run_verification_commands` counted `verify_total` before the loop,
ran `eval "$cmd"` with stdout/stderr redirected but STDIN LEFT ALONE, and fed the
loop from `done <<< "$verify_cmds"`. The command list was therefore the loop's own
stdin, so a command that reads stdin consumed the remaining verification lines.
The verdict asked only `[ "$verify_fail" -gt 0 ]`, which is green whenever nothing
failed — including when most of the block never ran. Measured on the real gate:
Running 4 verification command(s)...
PASS: echo one
PASS: cat > /dev/null

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3219_verification_count_reconciliation.yaml`*
*Last verified: 2026-08-29*
