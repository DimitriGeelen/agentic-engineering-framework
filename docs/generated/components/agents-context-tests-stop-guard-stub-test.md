# stop-guard-stub-test

> Stub test for agents/context/stop-guard.sh nudge thresholds — 3 counter/focus scenarios (T-1211)

**Type:** script | **Subsystem:** tests | **Location:** `agents/context/tests/stop-guard-stub-test.sh`

## What It Does

Stub test for agents/context/stop-guard.sh (T-1211)
Exercises 3 scenarios:
A. stop_counter below threshold (5) → no nudge
B. stop_counter at threshold (15), tool_counter=0, no focus → nudge fired
C. stop_counter at threshold (15), tool_counter>0 → no nudge (productive)
Runs in an isolated sandbox (overrides PROJECT_ROOT); does NOT pollute real
`.context/working/`.

---
*Auto-generated from Component Fabric. Card: `agents-context-tests-stop-guard-stub-test.yaml`*
*Last verified: 2026-09-08*
