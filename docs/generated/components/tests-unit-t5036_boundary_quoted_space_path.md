# t5036_boundary_quoted_space_path

> T-5036 (050 msg 86069e19): a quoted path containing a space is ONE path to the boundary hook.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5036_boundary_quoted_space_path.bats`

## What It Does

T-5036 (050 msg 86069e19): a quoted path containing a space is ONE path to the boundary
hook. Under a grant whose folder name has a space, typed commands were refused with
"Outside-path argument …/106" because the quoted argument was split at the space.
Refusals must not weaken: outside every grant, read-level write, never_write still refused.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5036_boundary_quoted_space_path.yaml`*
*Last verified: 2026-11-13*
