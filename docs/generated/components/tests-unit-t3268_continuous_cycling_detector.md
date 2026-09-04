# t3268_continuous_cycling_detector

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3268_continuous_cycling_detector.bats`

## What It Does

T-3268 (G-099 what_remains) — G-099 fixed the "wrapper says armed but turn
driver isn't" drift class and named, but did not build, the detector for a
sibling class: `last_terminated_reason` (bin/claude-fw:388) is a one-way
latch that replays verbatim on every restart attempt without re-evaluating
whether the thing that set it is still true. `.stop-driver.log` records one
`decision=stop reason=terminated[stored@TS](CAUSE)` line per attempt, and
neither existing check (fw doctor's continuous-run block, audit.sh's
check_continuous_run_turn_driver) reads that log — both only tail the
separate continuous-run.jsonl ledger.
`fw_continuous_cycling_facts <root> <window_seconds> <threshold>` closes

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [continuous-mode](/docs/generated/lib-continuous-mode) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3268_continuous_cycling_detector.yaml`*
*Last verified: 2026-09-03*
