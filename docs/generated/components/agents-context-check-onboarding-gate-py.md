# check-onboarding-gate

> T-2815: refuse Write/Edit that adds an agent-unresolvable task to the gated onboarding set (T-532's check-active-task.sh onboarding block).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-onboarding-gate.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook_paths](/docs/generated/lib-hook_paths) | calls | Python-side hook project-root resolver — parity with lib/paths.sh:fw_reanchor_from_cwd. |
| [check-inception-recommendation](/docs/generated/agents-context-check-inception-recommendation-py) | calls | T-2205 (T-2204 Slice B): PreToolUse Write/Edit hook — refuse save when an inception task has a template-only `## Recommendation` block under |
| [hook_paths](/docs/generated/lib-hook_paths) | uses | Python-side hook project-root resolver — parity with lib/paths.sh:fw_reanchor_from_cwd. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [onboarding_gate_arc_tag_fp](/docs/generated/tests-unit-onboarding_gate_arc_tag_fp) | tests_by | T-2881 — the onboarding gate must distinguish an arc tag from set membership. |
| [check-onboarding-gate](/docs/generated/agents-context-check-onboarding-gate) | called_by | T-2815 PreToolUse Write/Edit hook — refuses adding an agent-unresolvable task (owner != human but agent-unresolvable: inception workflow_type or an unticked ### Human AC) to the T-532 gated onboarding set. Bash wrapper exec's the real logic in check-onboarding-gate.py. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-onboarding-gate-py.yaml`*
*Last verified: 2026-09-03*
