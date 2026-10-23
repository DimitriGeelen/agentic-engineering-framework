# t4459_watchtower_log_fd_deleted

> T-4459 — the running Watchtower wrote stdout/stderr into a deleted watchtower.log.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4459_watchtower_log_fd_deleted.bats`

## What It Does

T-4459 — the running Watchtower wrote stdout/stderr into a deleted watchtower.log.
The file was tracked in git, so a `merge origin/master` (autostash cycle) replaced
its inode while the server kept the old fd open; tracebacks became unreadable.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4459_watchtower_log_fd_deleted.yaml`*
*Last verified: 2026-10-20*
