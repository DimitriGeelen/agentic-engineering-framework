# tier0_hash_normalization

> T-1500: Tier 0 hash drift on retry-after-approval.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/tier0_hash_normalization.bats`

## What It Does

Exact-text Tier 0 approvals hash the ORIGINAL command bytes (T-3593 round 7).
History: T-1500 collapsed whitespace before hashing so a reflowed retry still
matched its approval. That also merged different commands: quoted whitespace
is part of an argument, so `rm -rf ./ "a  b"` and `rm -rf ./ "a b"` (two
different paths) shared one approval (codex round 6 HIGH). Round 7 removes all
normalisation. Retries no longer need it: duplicate fires of ONE tool call are
recognised by tool_use_id (round 4), and mapped commands match by action.
(File name kept for history; the suite now pins the opposite rule.)

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-tier0](/docs/generated/agents-context-check-tier0) | calls | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [check-tier0](/docs/generated/agents-context-check-tier0) | tests | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |

---
*Auto-generated from Component Fabric. Card: `tests-unit-tier0_hash_normalization.yaml`*
*Last verified: 2026-04-26*
