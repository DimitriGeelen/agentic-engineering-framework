# t3549_inception_handoff_refusal

> T-3549 — an inception handoff is REFUSED when the decision it invites would be

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3549_inception_handoff_refusal.bats`

## What It Does

T-3549 — an inception handoff is REFUSED when the decision it invites would be
refused.
`emit_review` detected the under-disposed state from T-3279 onward and WARNED,
then handed over anyway. T-3540 added a footer so the blocker travelled with
the handoff. Both kept emission unblocked, on two reasons this file's fixture
set now pins as false:
1. "Refusing would strand a task whose only problem is that nobody has
answered its questions yet." `deferred` is always an available
disposition, so no question is undisposable and nothing can be stranded.
2. "The blocker travels WITH the handoff, so an agent cannot hand it over

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3549_inception_handoff_refusal.yaml`*
*Last verified: 2026-09-29*
