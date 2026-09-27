# bats_red_attribution

> T-3126 — attribute each RED bats test to the paths it is about.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/bats_red_attribution.py`

## What It Does

A repo-relative path: has a directory separator and an extension. Anchored on
a word boundary so trailing punctuation in prose does not attach.

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `lib-bats_red_attribution.yaml`*
*Last verified: 2026-08-24*
