# cron_flock_parity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/cron_flock_parity.bats`

## What It Does

T-1558 — Regression: fw doctor must warn when the cron registry declares
more flock-wrapped jobs than the deployed crontab carries (T-1556 prevention
5). Origin: T-1556 destroyed all 9 orphan-prevention wrappers in production
while the existing file-diff check stayed green — flock parity was never
verified structurally.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-cron_flock_parity.yaml`*
*Last verified: 2026-04-27*
