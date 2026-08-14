# check-onboarding-gate

> T-2815 PreToolUse Write/Edit hook — refuses adding an agent-unresolvable task (owner != human but agent-unresolvable: inception workflow_type or an unticked ### Human AC) to the T-532 gated onboarding set. Bash wrapper exec's the real logic in check-onboarding-gate.py.


**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-onboarding-gate.sh`

## What It Does

T-2815: agent-unresolvable onboarding-task invariant hook (bash wrapper for Python).
The fw hook dispatcher (bin/fw:5489) loads .sh files; the actual logic
lives in check-onboarding-gate.py to keep parsing clean.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `agents/context/check-onboarding-gate.py` | calls | — |
| [check-active-task](/docs/generated/agents-context-check-active-task) | reads | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `tests/unit/check_onboarding_gate.bats` | reads | — |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-onboarding-gate.yaml`*
*Last verified: 2026-08-05*
