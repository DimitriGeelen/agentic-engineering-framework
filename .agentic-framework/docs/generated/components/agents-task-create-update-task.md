# update-task

> Task Update Agent - Status transitions with auto-triggers

**Type:** script | **Subsystem:** task-management | **Location:** `agents/task-create/update-task.sh`

## What It Does

Task Update Agent - Status transitions with auto-triggers
Updates task frontmatter and triggers structural actions:
issues/blocked  → auto-diagnose via healing agent
work-completed  → set date_finished, move to completed/, generate episodic
Usage:
./agents/task-create/update-task.sh T-XXX --status issues
./agents/task-create/update-task.sh T-XXX --status work-completed
./agents/task-create/update-task.sh T-XXX --owner claude-code
./agents/task-create/update-task.sh T-XXX --status blocked --reason "Waiting on API key"

## Dependencies (6)

| Target | Relationship |
|--------|-------------|
| `C-001` | calls |
| `agents/healing/healing.sh` | calls |
| `lib/paths.sh` | calls |
| `lib/enums.sh` | calls |
| `lib/keylock.sh` | calls |
| `lib/review.sh` | calls |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `C-004` | called_by |
| `bin/fw` | called_by |

## Documentation

- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-518: Fix bash 3.2 compat — replace declare -A with POSIX-safe lookups (macOS)
- T-535: Build onboarding gate — tag-based PreToolUse enforcement + SessionStart injection
- T-587: Keyed async queue — per-key serialization primitive for concurrent operations
- T-692: Learning capture prompt for bugfix tasks — structural nudge in update-task.sh when completing fix tasks without a learning entry
- T-693: Fix learning prompt false positive — match task names starting with Fix, not containing fix anywhere

---
*Auto-generated from Component Fabric. Card: `agents-task-create-update-task.yaml`*
*Last verified: 2026-02-20*
