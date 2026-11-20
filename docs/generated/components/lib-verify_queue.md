# verify_queue

> T-2765: re-run stored ## Verification for the human review queue.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/verify_queue.py`

## What It Does

T-5268: the refusal rule (UNSAFE_PATTERNS, process control, the
`# needs: fixture` marker) lives in lib/unattended_verification.py and is
shared with CTL-013 — one predicate for both unattended rails. Skips are
reported as SKIPPED, never as PASS.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [verification-port](/docs/generated/lib-verification-port) | calls | lib/verification-port.sh — hard-coded Watchtower port detection (T-2732) |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | called_by | T-2991: P-011 must never eval a line bash cannot parse. |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | tests_by | T-2991: P-011 must never eval a line bash cannot parse. |
| [t3232_verification_extractor_failure](/docs/generated/tests-unit-t3232_verification_extractor_failure) | tests_by | T-3232 — extraction FAILURE must not read as "this task has no Verification section". |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `lib-verify_queue.yaml`*
*Last verified: 2026-08-03*
