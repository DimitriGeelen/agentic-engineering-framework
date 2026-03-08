# git

> Git Agent - Structural Enforcement for Git Operations

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/git.sh`

## What It Does

Git Agent - Structural Enforcement for Git Operations
Ensures every commit connects to a task (T-XXX pattern)

### Framework Reference

**Location:** `agents/git/`

**When to use:** For all git operations that involve code changes. Enforces task traceability (P-002).

## Dependencies (6)

| Target | Relationship |
|--------|-------------|
| `agents/git/lib/common.sh` | calls |
| `agents/git/lib/commit.sh` | calls |
| `agents/git/lib/status.sh` | calls |
| `agents/git/lib/hooks.sh` | calls |
| `agents/git/lib/bypass.sh` | calls |
| `agents/git/lib/log.sh` | calls |

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `agents/handover/handover.sh` | called_by |
| `bin/fw` | called_by |
| `lib/init.sh` | called_by |
| `lib/setup.sh` | called_by |
| `lib/upgrade.sh` | called_by |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)
- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-348: Fix update-task.sh sed failing on macOS BSD sed

---
*Auto-generated from Component Fabric. Card: `agents-git-git.yaml`*
*Last verified: 2026-02-20*
