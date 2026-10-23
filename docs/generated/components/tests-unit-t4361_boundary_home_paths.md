# t4361_boundary_home_paths

> T-4361 (GitHub #104): the project-boundary gate hard-coded /root/.local/ and /root/.claude/, so a non-root account was refused reads of its own ~/.local and writes to its own ~/.claude, with no setting to allow a path.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4361_boundary_home_paths.bats`

## What It Does

T-4361 (GitHub #104): the project-boundary gate hard-coded /root/.local/ and
/root/.claude/, so a non-root account was refused reads of its own ~/.local and
writes to its own ~/.claude, with no setting to allow a path. The zones now follow
the running account's $HOME, and BOUNDARY_EXTRA_READ_PATHS adds read-only paths.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4361_boundary_home_paths.yaml`*
*Last verified: 2026-10-20*
