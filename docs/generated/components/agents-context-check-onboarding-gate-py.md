# check-onboarding-gate

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-onboarding-gate.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook_paths](/docs/generated/lib-hook_paths) | calls | TODO: describe what this component does |
| [check-inception-recommendation](/docs/generated/agents-context-check-inception-recommendation-py) | calls | TODO: describe what this component does |
| [hook_paths](/docs/generated/lib-hook_paths) | uses | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [onboarding_gate_arc_tag_fp](/docs/generated/tests-unit-onboarding_gate_arc_tag_fp) | tests_by | TODO: describe what this component does |
| [check-onboarding-gate](/docs/generated/agents-context-check-onboarding-gate) | called_by | T-2815 PreToolUse Write/Edit hook — refuses adding an agent-unresolvable task (owner != human but agent-unresolvable: inception workflow_type or an unticked ### Human AC) to the T-532 gated onboarding set. Bash wrapper exec's the real logic in check-onboarding-gate.py. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-onboarding-gate-py.yaml`*
*Last verified: 2026-09-03*
