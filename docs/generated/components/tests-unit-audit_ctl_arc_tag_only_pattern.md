# audit_ctl_arc_tag_only_pattern

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/audit_ctl_arc_tag_only_pattern.bats`

## What It Does

T-1881 (T-NEW-16): pin the ctl-arc-tag-only-pattern audit check.
Verifies that:
1. A clean tree (allowlist-only matches) → PASS line emitted
2. A synthetic violation under web/blueprints/ → FAIL line emitted
3. Matches under tests/ and lib/arc.sh / lib/arc_membership.sh / lib/migrations/
are exempt (allowlist works)
Strategy: exercise only the check block — extract the AWK-pattern logic
directly. Running the full audit.sh per-test would be slow + flaky.

## Dependencies (7)

| Target | Relationship |
|--------|-------------|
| `lib/arc_membership.sh` | calls |
| `lib/arc.sh` | calls |
| `lib/migrations/arc-id-migration.sh` | calls |
| `lib/arc.sh` | tests |
| `lib/arc_membership.sh` | tests |
| `lib/migrations/arc-id-migration.sh` | tests |
| `C-004` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit_ctl_arc_tag_only_pattern.yaml`*
*Last verified: 2026-05-17*
