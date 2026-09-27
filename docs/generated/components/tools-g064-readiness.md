# g064-readiness

> G-064 closure-readiness gauge — substrate-aware check.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/g064-readiness.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [escalation-scan-v0.5](/docs/generated/tools-escalation-scan-v0-5) | calls | T-1727 — Layer B v0.5: per-candidate LLM augmentation of escalation-scan v0. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_fw_gaps_closure_check](/docs/generated/tests-unit-test_fw_gaps_closure_check) | tests_by | T-1752 — `fw gaps` honours optional closure_check_command field. |
| [test_enrich_bats_parser](/docs/generated/tests-unit-test_enrich_bats_parser) | called_by | T-1754 — Regression tests for fabric enrich's .bats parser. |
| [test_g064_readiness](/docs/generated/tests-unit-test_g064_readiness) | called_by | T-1750 — Regression tests for tools/g064-readiness.py. |
| [gaps](/docs/generated/lib-gaps) | called_by | Gap-register closure helpers. |

---
*Auto-generated from Component Fabric. Card: `tools-g064-readiness.yaml`*
*Last verified: 2026-05-05*
