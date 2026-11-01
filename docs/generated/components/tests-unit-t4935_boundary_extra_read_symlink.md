# t4935_boundary_extra_read_symlink

> T-4935 (GitHub #104 reply IC_kwDORdtOLc8AAAABhRyejw): a BOUNDARY_EXTRA_READ_PATHS entry that is a symbolic link was stored only in resolved form, while the command's path is compared as typed, so the link path the operator runs stayed…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4935_boundary_extra_read_symlink.bats`

## What It Does

T-4935 (GitHub #104 reply IC_kwDORdtOLc8AAAABhRyejw): a BOUNDARY_EXTRA_READ_PATHS
entry that is a symbolic link was stored only in resolved form, while the command's
path is compared as typed, so the link path the operator runs stayed blocked.
The submitter's steps: a script under $HOME/tools, a link to it, the link listed.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4935_boundary_extra_read_symlink.yaml`*
*Last verified: 2026-10-31*
