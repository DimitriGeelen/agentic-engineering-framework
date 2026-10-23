# t3735_config_set_no_fold

> T-3735: `fw config set` dumped .framework.yaml at the YAML default width (80), so a long scalar (upstream_repo) was folded onto a continuation line.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3735_config_set_no_fold.bats`

## What It Does

T-3735: `fw config set` dumped .framework.yaml at the YAML default width (80),
so a long scalar (upstream_repo) was folded onto a continuation line. The
line-wise reader in lib/update.sh (grep "^upstream_repo:" | sed) then read ''
and `fw update` failed "No upstream_repo" — consumers fell releases behind.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3735_config_set_no_fold.yaml`*
*Last verified: 2026-10-20*
