# bats-dead-negation

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/lint/bats-dead-negation.bats`

## What It Does

T-3138 — no bats assertion in this repo may be one that cannot fail.
Bash exempts a `!`-inverted command from errexit. Bats takes a test's verdict
from its body's exit status. A `!` line that is not the last statement of its
body is therefore checked by nothing — and reads exactly like a working
assertion. 106 of them accumulated across 66 files before anything noticed,
because a dead assertion and a passing one produce identical output.
The mechanism itself is pinned by running bats on fixtures in
tests/unit/errexit_negation_mechanism.bats. This file tests the LINT: that it
finds the shape, and — as much as it matters — that it does not invent it.
Every fixture here is written into BATS_TEST_TMPDIR (L-599). None of the

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bats-dead-negation-lint](/docs/generated/tools-bats-dead-negation-lint) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-lint-bats-dead-negation.yaml`*
*Last verified: 2026-08-25*
