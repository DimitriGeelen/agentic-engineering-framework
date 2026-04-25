# handover

> Unit tests for agents/handover/handover.sh (10 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/handover.bats`

**Tags:** `handover`, `bats`, `unit-test`

## What It Does

Unit tests for agents/handover/handover.sh
Origin: T-923, T-944 (isolation fix)

### Framework Reference

- **Generate handover AFTER work is done, not before**
- Never generate a skeleton handover "to fill in later" — the session may not survive to fill it
- When generating handover: fill in ALL [TODO] sections immediately in the same operation
- For mid-session checkpoints: `fw handover --checkpoint`

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/handover/handover.sh` | calls |

## Related

### Tasks
- T-923: Add unit tests for agents/handover/handover.sh
- T-944: Fix handover.bats test pollution — handover tests overwrite real LATEST.md

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover.yaml`*
*Last verified: 2026-04-05*
