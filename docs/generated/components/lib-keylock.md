# keylock

> Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/keylock.sh`

## What It Does

keylock.sh — Per-key serialization primitive using flock
T-587: Keyed async queue for concurrent framework operations
Usage:
source lib/keylock.sh
keylock_acquire "T-042"   # Blocks until lock acquired
... critical section ...
keylock_release "T-042"   # Releases lock
Cross-key parallelism: locks on different keys do not block each other.
Same-key serialization: locks on the same key execute sequentially.
Stale lock cleanup: locks older than KEYLOCK_TIMEOUT (default 300s) are auto-released.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/config.sh` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `agents/task-create/update-task.sh` | called_by |
| `tests/unit/lib_keylock.bats` | called-by |
| `tests/unit/lib_keylock.bats` | called_by |
| `agents/task-create/create-task.sh` | called_by |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-845: Run bats test suite and fix any failures

---
*Auto-generated from Component Fabric. Card: `lib-keylock.yaml`*
*Last verified: 2026-03-28*
