# t5373_locks_gitignore

> T-5373 — keylock's flock anchors (.context/locks/*.lock) persist by design. Only the framework repo's root .gitignore ignored .context/locks/, so a consumer saw `.context/locks/T-486.lock` untracked after `fw inception decide`.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5373_locks_gitignore.bats`

## What It Does

T-5373 — keylock's flock anchors (.context/locks/*.lock) persist by design.
Only the framework repo's root .gitignore ignored .context/locks/, so a
consumer saw `.context/locks/T-486.lock` untracked after `fw inception decide`.
`fw init` and `fw upgrade` must write a consumer-side rule, idempotently, and
never touch the consumer's top-level .gitignore.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5373_locks_gitignore.yaml`*
*Last verified: 2026-11-23*
