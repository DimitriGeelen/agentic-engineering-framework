# tier0_hash_normalization

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/tier0_hash_normalization.bats`

## What It Does

T-1500: Tier 0 hash drift on retry-after-approval.
Root cause: check-tier0.sh hashed $COMMAND raw. When an agent regenerated
a blocked command for retry (extra whitespace, trailing newline, reflowed
args), the SHA-256 digest drifted from the stored approval and the hook
re-blocked. Approval was effectively single-use only for byte-identical
retries.
Fix: normalize whitespace before hashing — collapse runs of [:space:] to a
single space, trim leading/trailing. Same human-readable command yields
same hash regardless of incidental whitespace.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [check-tier0](/docs/generated/agents-context-check-tier0) | tests | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |

---
*Auto-generated from Component Fabric. Card: `tests-unit-tier0_hash_normalization.yaml`*
*Last verified: 2026-04-26*
