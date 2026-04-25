# cron_install

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/integration/cron_install.bats`

## What It Does

Integration tests for fw cron install + fw doctor cron drift check (T-1112/T-1114)
Uses FW_CRON_INSTALL_DIR override to point at a temp directory instead of
/etc/cron.d/ so the tests run without root.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|

---
*Auto-generated from Component Fabric. Card: `tests-integration-cron_install.yaml`*
*Last verified: 2026-04-11*
