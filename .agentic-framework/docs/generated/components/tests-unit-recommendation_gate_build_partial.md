# recommendation_gate_build_partial

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/recommendation_gate_build_partial.bats`

## What It Does

T-2421 (T-2419 GO): Recommendation gate for partial-complete BUILD-class tasks.
Sibling of T-2204 inception filing-time gate. This suite pins:
- emit_review refuses URL emission for partial-complete build/refactor/test/decommission
when ## Recommendation is missing or empty (the T-2417 close-cascade class).
- emit_review honours FW_ALLOW_EMPTY_RECOMMENDATION=1 env-var bypass with Tier-2 log.
- emit_review still fires for inception tasks (no regression of T-2206).
- emit_review passes when build is fully-complete (no unticked Human ACs).
- emit_review passes when build has zero Human ACs.
- update-task.sh check_recommendation_for_review honours FW_ALLOW_EMPTY_RECOMMENDATION=1
env-var bypass in addition to the existing --skip-recommendation flag (T-1890 parity).

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [review](/docs/generated/lib-review) | calls | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [review](/docs/generated/lib-review) | tests | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-recommendation_gate_build_partial.yaml`*
*Last verified: 2026-06-16*
