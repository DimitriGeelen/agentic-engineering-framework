# t5077_sed_i_keeps_file_meta

> T-5077 (832 T-1393) — _sed_i rewrote a file through mktemp (0600) + mv, so every file it edited became 0600.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5077_sed_i_keeps_file_meta.bats`

## What It Does

T-5077 (832 T-1393) — _sed_i rewrote a file through mktemp (0600) + mv, so every
file it edited became 0600. On a repo reached through a POSIX ACL, 0600 also
zeroes the ACL mask: named users lost all access (832: 634 task files; AEF:
1,639). `fw task update` writes task files through _sed_i.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5077_sed_i_keeps_file_meta.yaml`*
*Last verified: 2026-11-11*
