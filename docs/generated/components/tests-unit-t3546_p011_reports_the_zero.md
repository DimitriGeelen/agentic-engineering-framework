# t3546_p011_reports_the_zero

> T-3546 / OBS-565 — P-011 must SAY when it runs zero commands.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3546_p011_reports_the_zero.bats`

## What It Does

T-3546 / OBS-565 — P-011 must SAY when it runs zero commands.
`run_verification_commands` returned at `[ -z "$verify_cmds" ] && return 0`
without printing anything, so a close that verified nothing was byte-identical
to a close that had nothing to verify.
Measured on T-3545 (2026-09-28): a splice put its `## Verification` heading
mid-sentence inside the Human-AC template comment — whose own text contains the
literal phrase "added to ## Verification" — so no heading existed at line start.
The task closed with `6/6 checked ✓` and no gate section at all. T-3544, eleven
minutes earlier, printed `Verification: 18/18 passed ✓`. One absent line was the
entire difference, and nobody notices an absence. Aggravating: `work-completed →

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3546_p011_reports_the_zero.yaml`*
*Last verified: 2026-09-28*
