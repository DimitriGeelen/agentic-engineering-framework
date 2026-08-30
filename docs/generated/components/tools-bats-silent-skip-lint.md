# bats-silent-skip-lint

> Reports bats skips that the P-011 verification idiom cannot see. Static mode flags two guard shapes with no legitimate reading (unconditional, and guards fixed for a deployment rather than probing an optional dependency); --tap mode reports the skips a real run actually fired. Wired into fw test lint.

**Type:** script | **Subsystem:** tests | **Location:** `tools/bats-silent-skip-lint.py`

**Tags:** `lint`, `tests`, `verification-gate`, `T-3217`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bats-silent-skip](/docs/generated/tests-lint-bats-silent-skip) | tested-by | Tests the silent-skip lint. Half the legs are false-positive controls: a detector that reddens legitimate optional-dependency skips gets suppressed wholesale, so the legs asserting it stays quiet are the ones that decide whether it survives. Includes the mutation control and the two heredoc-blindness regressions found by reconciling the census against a naive grep. |

---
*Auto-generated from Component Fabric. Card: `tools-bats-silent-skip-lint.yaml`*
*Last verified: 2026-08-29*
