# inception_decide_atomicity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/inception_decide_atomicity.bats`

## What It Does

T-1503: do_inception_decide must be atomic — either fully succeeds (Decision
section + Updates entry + status=work-completed) or leaves the task body
untouched. The original bug: Decision/Updates writes happened BEFORE the
AC gate ran, so a task with custom (non-auto-tick) Agent ACs would have
Decision=GO recorded but status stuck at started-work. Retries then
duplicated the Updates entry.
Live evidence: 003-NTB-ATC-Plugin T-131 watchtower.log:
stdout=...ERROR: Cannot complete — 5/5 agent AC unchecked...
POST /inception/T-131/decide HTTP/1.1 500
Fix (preflight pattern): tick first, count remaining unchecked Agent ACs,

## Dependencies (8)

| Target | Relationship |
|--------|-------------|
| `lib/colors.sh` | calls |
| `lib/errors.sh` | calls |
| `lib/tasks.sh` | calls |
| `lib/inception.sh` | calls |
| `lib/colors.sh` | tests |
| `lib/errors.sh` | tests |
| `lib/tasks.sh` | tests |
| `lib/inception.sh` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-inception_decide_atomicity.yaml`*
*Last verified: 2026-04-26*
