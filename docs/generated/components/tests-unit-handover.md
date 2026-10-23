# handover

> Unit tests for agents/handover/handover.sh (10 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/handover.bats`

**Tags:** `handover`, `bats`, `unit-test`

## What It Does

Unit tests for agents/handover/handover.sh
Origin: T-923, T-944 (isolation fix)
T-4522: every test runs handover.sh against a throwaway fixture project, not
the framework repo. Against the live repo each run walks ~3,600 task files
with a fork per file (~75 s on a many-core host); eight runs hung the file to
the 900 s cap on a clean 4-vCPU machine, and each one also rewrote the shared
checkout's .context/handovers/LATEST.md under any session using it. Each call
is bounded by `timeout` so a regression reads as a failure, not a hang.

### Framework Reference

- **Generate handover AFTER work is done, not before**
- Never generate a skeleton handover "to fill in later" — the session may not survive to fill it
- When generating handover: fill in ALL [TODO] sections immediately in the same operation
- For mid-session checkpoints: `fw handover --checkpoint`

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [handover](/docs/generated/agents-handover-handover) | tests | Handover Agent - Mechanical Operations |

## Related

### Tasks
- T-923: Add unit tests for agents/handover/handover.sh
- T-944: Fix handover.bats test pollution — handover tests overwrite real LATEST.md

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover.yaml`*
*Last verified: 2026-04-05*
