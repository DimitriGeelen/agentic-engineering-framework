# revisit_undated_signal

> T-2865 — DEFER decisions carrying no revisit date must be surfaced, separately.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/revisit_undated_signal.bats`

## What It Does

T-2865 — DEFER decisions carrying no revisit date must be surfaced, separately.
Origin: agents/context/revisit-due-scan.sh filtered on
[[ "$revisit_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || continue
and `continue`d on empty — so a task whose `## Decision` block records DEFER but
which carries no `revisit_at` was skipped before any reporting logic ran. The
scanner also removes its output file when nothing is ripe, deliberately making
"absent" and "empty" the same signal. Composed, those two facts meant the ripe
file's absence read as "no deferrals pending" while 14 of 14 active DEFER
decisions sat unscheduled and unobservable.
WHAT IS PINNED: the real scanner, driven against a synthetic PROJECT_ROOT. Not a

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [revisit-due-scan](/docs/generated/agents-context-revisit-due-scan) | calls | revisit-due-scan.sh — Daily scan for ripe revisit_at deferrals (T-1452 / G-053) |
| [revisit-due-scan](/docs/generated/agents-context-revisit-due-scan) | tests | revisit-due-scan.sh — Daily scan for ripe revisit_at deferrals (T-1452 / G-053) |

---
*Auto-generated from Component Fabric. Card: `tests-unit-revisit_undated_signal.yaml`*
*Last verified: 2026-08-08*
