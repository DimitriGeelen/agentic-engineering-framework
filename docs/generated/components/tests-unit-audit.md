# audit

> Unit tests for agents/audit/audit.sh (11 tests)

**Type:** test | **Subsystem:** tests | **Location:** `tests/unit/audit.bats`

**Tags:** `audit`, `bats`, `unit-test`

## What It Does

Unit tests for agents/audit/audit.sh
Origin: T-924

### Framework Reference

**Location:** `agents/audit/`

**When to use:** Periodically check framework compliance. Run after completing work or when suspecting drift.

```bash
./agents/audit/audit.sh
```

**Exit codes:** 0=pass, 1=warnings, 2=failures

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/audit/audit.sh` | calls |

## Related

### Tasks
- T-924: Add unit tests for agents/audit/audit.sh

---
*Auto-generated from Component Fabric. Card: `tests-unit-audit.yaml`*
*Last verified: 2026-04-05*
