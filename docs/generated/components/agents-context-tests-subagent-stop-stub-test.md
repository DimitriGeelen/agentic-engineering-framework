# subagent-stop-stub-test

> Stub test for agents/context/subagent-stop.sh (T-1213)

**Type:** script | **Subsystem:** tests | **Location:** `agents/context/tests/subagent-stop-stub-test.sh`

## What It Does

Stub test for agents/context/subagent-stop.sh (T-1213)
Exercises both paths:
1. Under-threshold return (500B) → telemetry line written, no fw bus entry, migrated=false
2. Over-threshold return (20KB)  → telemetry line written, fw bus R-NNN entry, migrated=true
Runs in an isolated temp dir (does NOT pollute real .context/working) and uses a
synthesized transcript JSONL file.

---
*Auto-generated from Component Fabric. Card: `agents-context-tests-subagent-stop-stub-test.yaml`*
*Last verified: 2026-09-08*
