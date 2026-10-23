# no-hardcoded-checkout-root

> Invariant: no test under tests/ defaults its framework/project root to the literal path of the main checkout. A test derives its root from its own location ($BATS_TEST_DIRNAME/../.. in bats, Path(__file__) in python).

**Type:** script | **Subsystem:** tests | **Location:** `tests/lint/no-hardcoded-checkout-root.bats`

## What It Does

Invariant: no test under tests/ defaults its framework/project root to the literal
path of the main checkout. A test derives its root from its own location
($BATS_TEST_DIRNAME/../.. in bats, Path(__file__) in python).
Origin: T-4483. 50 bats files under tests/unit read
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-<main checkout path>}"
so run from a scratch clone, a worktree or a consumer they silently tested the
MAIN checkout. Proof (T-4380 phase 1): a syntax error planted in a scratch copy's
lib/arc.sh left four arc test files 43/43 green until FRAMEWORK_ROOT was pointed
at the copy. On the generating host the literal always resolves, so every run
here is green by construction and nothing ever looks.

---
*Auto-generated from Component Fabric. Card: `tests-lint-no-hardcoded-checkout-root.yaml`*
*Last verified: 2026-10-20*
