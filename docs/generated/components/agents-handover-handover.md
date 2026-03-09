# handover

> Handover Agent - Mechanical Operations

**Type:** script | **Subsystem:** handover | **Location:** `agents/handover/handover.sh`

## What It Does

Handover Agent - Mechanical Operations
Creates handover documents for session continuity

### Framework Reference

**Location:** `agents/handover/`

**When to use:** MANDATORY at end of every session.

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `agents/task-create/create-task.sh` | calls |
| `C-008` | calls |
| `agents/git/git.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `agents/context/pre-compact.sh` | called_by |
| `bin/fw` | called_by |
| `C-008` | called_by |

## Documentation

- [Deep Dive: Context Budget Management](docs/articles/deep-dives/03-context-budget.md) (deep-dive)

## Related

### Tasks
- T-260: Fix LATEST.md handover sync — symlink instead of copy
- T-372: Investigate blind task-completion suggestion pattern + mitigate
- T-373: Investigate agent pattern: suggesting closure of untested Human ACs

---
*Auto-generated from Component Fabric. Card: `agents-handover-handover.yaml`*
*Last verified: 2026-02-20*
