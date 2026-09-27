# t3393_ewcr_traceability

> T-3393 — the §13 invariant traceability matrix resolves, and its fence bites.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3393_ewcr_traceability.bats`

## What It Does

T-3393 — the §13 invariant traceability matrix resolves, and its fence bites.
The Arc 0 headline mechanic promises an operator can pick any pilot invariant
and reach a contract, a refusal scenario, a component and a runnable fence.
This suite pins that the matrix covers all 20 invariants and that
tools/ewcr-trace-check.py goes red on each way the trace can rot.
Every green assertion has a control leg on a tampered copy (L-668) — a check
that cannot fail is not a check.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ewcr-trace-check](/docs/generated/tools-ewcr-trace-check) | tests | EWCR Arc 0 — fence for the §13 invariant traceability matrix (T-3393). |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3393_ewcr_traceability.yaml`*
*Last verified: 2026-09-19*
