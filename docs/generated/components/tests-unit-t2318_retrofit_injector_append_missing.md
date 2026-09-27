# t2318_retrofit_injector_append_missing

> T-2318: retrofit injector must handle missing-Recommendation-section case (pre-T-1716 backlog inceptions). Pins detector↔corrector symmetry per RCA.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2318_retrofit_injector_append_missing.bats`

## What It Does

T-2318: retrofit injector must handle missing-Recommendation-section case
(pre-T-1716 backlog inceptions). Pins detector↔corrector symmetry per RCA.

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [inception_recommendation](/docs/generated/lib-inception_recommendation) | calls | Detection helper for the T-679 rule decay pattern (T-1715 meta-RCA, T-1716 implementation). Used by: - agents/audit/audit.sh — C-006 detective check - lib/inception.sh — Stream C sweep (do_inception_sweep --recommendation-fix) |
| [inception_recommendation](/docs/generated/lib-inception_recommendation) | tests | Detection helper for the T-679 rule decay pattern (T-1715 meta-RCA, T-1716 implementation). Used by: - agents/audit/audit.sh — C-006 detective check - lib/inception.sh — Stream C sweep (do_inception_sweep --recommendation-fix) |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2318_retrofit_injector_append_missing.yaml`*
*Last verified: 2026-06-10*
