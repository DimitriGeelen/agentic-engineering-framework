# bats-silent-skip

> Tests the silent-skip lint. Half the legs are false-positive controls: a detector that reddens legitimate optional-dependency skips gets suppressed wholesale, so the legs asserting it stays quiet are the ones that decide whether it survives. Includes the mutation control and the two heredoc-blindness regressions found by reconciling the census against a naive grep.

**Type:** script | **Subsystem:** tests | **Location:** `tests/lint/bats-silent-skip.bats`

**Tags:** `tests`, `bats`, `lint`, `T-3217`

## What It Does

T-3217 — a skipped bats test reports `ok`, and the repo-standard P-011
verification idiom cannot tell that apart from a test that ran.
timeout 300 bats <suite> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
A skip is not a `not ok`. Found while landing T-3213, whose root-guarded
`chmod 500` test skipped on every run that mattered — the suite runs as root
— so the AC it covered was measured nowhere while reporting ok.
This file tests the LINT. The blind spot itself is a property of TAP and needs
no pinning; what needs pinning is that the detector finds the two shapes it
claims to and, much more importantly, DOES NOT INVENT THEM. Most skips in this
corpus are correct — an optional dependency is absent — and a detector that

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bats-silent-skip-lint](/docs/generated/tools-bats-silent-skip-lint) | tests | Reports bats skips that the P-011 verification idiom cannot see. Static mode flags two guard shapes with no legitimate reading (unconditional, and guards fixed for a deployment rather than probing an optional dependency); --tap mode reports the skips a real run actually fired. Wired into fw test lint. |

---
*Auto-generated from Component Fabric. Card: `tests-lint-bats-silent-skip.yaml`*
*Last verified: 2026-08-29*
