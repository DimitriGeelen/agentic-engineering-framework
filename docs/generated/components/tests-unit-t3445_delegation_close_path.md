# t3445_delegation_close_path

> T-3445 — the delegated close path, end to end, on two fixtures.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3445_delegation_close_path.bats`

## What It Does

T-3445 — the delegated close path, end to end, on two fixtures.
The classifier has its own unit tests; this file pins the thing those cannot
see: that a criterion the classifier called `deterministic` actually reaches
`work-completed` through the real reviewer and the real close gates, with no
human tick anywhere in the chain. Every step is the shipped code — `fw task
delegate`, `fw reviewer` (auto-tick v1.5, T-1985), `update-task.sh`. Nothing
is stubbed, because the defect this guards against lives at the joins.
Fixture 1 — two deterministic Human criteria. Delegate converts both, takes
ownership, reviewer PASSes, close moves the file to completed/.
Fixture 2 — the same two plus one taste criterion. Delegate converts two,

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3445_delegation_close_path.yaml`*
*Last verified: 2026-09-24*
