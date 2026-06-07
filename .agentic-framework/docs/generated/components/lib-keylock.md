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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [lib_keylock](/docs/generated/tests-unit-lib_keylock) | called-by | Unit tests for keylock (9 tests) |
| [lib_keylock](/docs/generated/tests-unit-lib_keylock) | called_by | Unit tests for keylock (9 tests) |
| [create-task](/docs/generated/agents-task-create-create-task) | called_by | Task Creation Agent - Mechanical Operations |
| [keylock_subshell_close](/docs/generated/tests-unit-keylock_subshell_close) | called_by | TODO: describe what this component does |
| [keylock_subshell_close](/docs/generated/tests-unit-keylock_subshell_close) | tests_by | TODO: describe what this component does |
| [lib_keylock](/docs/generated/tests-unit-lib_keylock) | tests_by | Unit tests for keylock (9 tests) |
| [task_id_race](/docs/generated/tests-unit-task_id_race) | tests_by | Regression test — concurrent fw work-on invocations must allocate distinct task IDs. Prior bug: generate_id() read max_id then (later) wrote the file; N parallel invocations all observed the same max_id and wrote T-${max+1}. Fix: keylock around read-compute-write sequence. |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-845: Run bats test suite and fix any failures

---
*Auto-generated from Component Fabric. Card: `lib-keylock.yaml`*
*Last verified: 2026-03-28*
