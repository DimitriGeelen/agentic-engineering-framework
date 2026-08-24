# t3050_b005_block_message

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3050_b005_block_message.bats`

## What It Does

T-3050 — the B-005 refusal must name the way forward.
The gate itself is NOT relaxed here and must not be. A matcher entry carries
`{"type":"command","command":"<arbitrary shell>"}`, so an "additive" edit adds
code that runs before every matching tool call and can delete the other
matchers. Additive describes the declarative shape; the effect is unbounded.
What was actually broken: the refusal ended at "requires human review" and
named no mechanism, so agents escalated to the operator for a JSON paste-in —
for a capability (`fw hook-enable`) that has shipped since T-1189. A gate with
no exit is a gate people route around, and routing around it is what B-005 is
for.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3050_b005_block_message.yaml`*
*Last verified: 2026-08-17*
