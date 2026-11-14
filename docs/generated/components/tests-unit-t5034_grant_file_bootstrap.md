# t5034_grant_file_bootstrap

> T-5034 (ring20-dashboard a14cb4c1, MEDIUM): with NO grant file yet, the agent must not be able to create policy/access-grants.yaml by a typed command (self-grant bootstrap).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5034_grant_file_bootstrap.bats`

## What It Does

T-5034 (ring20-dashboard a14cb4c1, MEDIUM): with NO grant file yet, the agent must not be able
to create policy/access-grants.yaml by a typed command (self-grant bootstrap). A policy/ folder
that does not exist is guarded too (creating it could carry a prepared grant file); an existing
policy/ stays ordinary (T-4988 control).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5034_grant_file_bootstrap.yaml`*
*Last verified: 2026-11-13*
