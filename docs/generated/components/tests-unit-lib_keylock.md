# lib_keylock

> Unit tests for keylock (9 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/lib_keylock.bats`

**Tags:** `keylock`, `bats`, `unit-test`

## What It Does

Unit tests for lib/keylock.sh
Tests keylock_acquire, keylock_release, _keylock_path, _keylock_clean_stale

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [keylock](/docs/generated/lib-keylock) | calls | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |
| [keylock](/docs/generated/lib-keylock) | tests | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-lib_keylock.yaml`*
*Last verified: 2026-04-05*
