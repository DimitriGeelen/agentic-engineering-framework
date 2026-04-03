# handover

> Handover Agent - Mechanical Operations

**Type:** script | **Subsystem:** handover | **Location:** `agents/handover/handover.sh`

## What It Does

Handover Agent - Mechanical Operations
Creates handover documents for session continuity

### Framework Reference

**Location:** `agents/handover/`

**When to use:** MANDATORY at end of every session.

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `agents/task-create/create-task.sh` | calls |
| `C-008` | calls |
| `agents/git/git.sh` | calls |
| `lib/paths.sh` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `agents/context/pre-compact.sh` | called_by |
| `bin/fw` | called_by |
| `C-008` | called_by |
| `agents/onboarding-test/test-onboarding.sh` | called_by |

## Documentation

- [Deep Dive: Context Budget Management](docs/articles/deep-dives/03-context-budget.md) (deep-dive)

## Related

### Tasks
- T-595: Migrate highest-risk inline Python blocks to fw-util calls
- T-709: Wire ntfy notifications into framework hooks — Tier 0, task complete, audit, handover
- T-795: Fix shellcheck warnings across agent scripts — SC2155, SC2144, SC2034, SC2044
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts

---
*Auto-generated from Component Fabric. Card: `agents-handover-handover.yaml`*
*Last verified: 2026-02-20*
