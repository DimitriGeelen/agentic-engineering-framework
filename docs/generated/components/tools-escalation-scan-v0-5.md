# escalation-scan-v0.5

> T-1727 — Layer B v0.5: per-candidate LLM augmentation of escalation-scan v0.

**Type:** script | **Subsystem:** framework-core | **Location:** `tools/escalation-scan-v0.5.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | calls | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [outcome](/docs/generated/lib-outcome) | calls | Outcome enrichment — default evaluator + back-prop + read-path join. |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [escalation_scan_v05](/docs/generated/tests-unit-escalation_scan_v05) | called_by | T-1727 — escalation-scan v0.5 unit coverage. |
| [escalation_scan_v05](/docs/generated/tests-unit-escalation_scan_v05) | tests_by | T-1727 — escalation-scan v0.5 unit coverage. |
| [reparse-historical-parsefails](/docs/generated/tools-reparse-historical-parsefails) | called_by | T-1756 — Re-parse historical PARSE-FAIL outcomes through the post-T-1748 parser. |
| [test_cron_generate_shape](/docs/generated/tests-unit-test_cron_generate_shape) | tests_by | T-1769 — Pin the shape of `fw cron generate` output. Origin: T-1720 found that the generator silently produced unrunnable lines (no cwd for `python3 -m lib.X` invocations; stderr swallowed by `2>/dev/null`). |
| [g064-readiness](/docs/generated/tools-g064-readiness) | called_by | G-064 closure-readiness gauge — substrate-aware check. |
| [test_escalation_v05_parser](/docs/generated/tests-unit-test_escalation_v05_parser) | called_by | T-1748 / T-1727 forward work — parse_verdict_envelope hardening. |

---
*Auto-generated from Component Fabric. Card: `tools-escalation-scan-v0-5.yaml`*
*Last verified: 2026-05-05*
