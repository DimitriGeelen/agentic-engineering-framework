# test_doctor_consumer_version_ahead

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_doctor_consumer_version_ahead.bats`

## What It Does

T-1838 — fw doctor asymmetric version-skew detection.
Origin: T-1828 surfaced a Layer 3 consequence — framework VERSION rolled back
(tag-counter reset) leaves consumers AHEAD of framework. The pre-T-1838 doctor
emitted a single direction-blind remediation ("Run: fw upgrade $consumer_dir")
for any version mismatch. In the consumer-ahead case that command would
silently downgrade the consumer's pinned version.
These tests pin the asymmetric remediation surface in bin/fw:
- version_relation (match | behind | ahead) is computed via sort -V
- behind branch preserves the "Run: fw upgrade" suggestion
- ahead branch emits a distinct "is AHEAD of framework" reason and the

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_doctor_consumer_version_ahead.yaml`*
*Last verified: 2026-05-14*
