# preamble

> Mandatory dispatch preamble — output rules for sub-agents to prevent context explosion (T-073). Requires disk writes, <=5 line responses.

**Type:** template | **Subsystem:** framework-core | **Location:** `agents/dispatch/preamble.md`

**Tags:** `dispatch`, `sub-agent`, `context-budget`, `protocol`

## What It Does

Mandatory Dispatch Preamble

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-dispatch](/docs/generated/agents-context-check-dispatch) | referenced_by | Dispatch Guard — PostToolUse hook for Task/TaskOutput result size. Warns when sub-agent results exceed safe thresholds (G-008 enforcement). — _check-dispatch.sh warning messages direct users to this preamble_ |
| [check-dispatch](/docs/generated/agents-context-check-dispatch) | references_by | Dispatch Guard — PostToolUse hook for Task/TaskOutput result size. Warns when sub-agent results exceed safe thresholds (G-008 enforcement). |
| [check-dispatch-pre](/docs/generated/agents-context-check-dispatch-pre) | read_by | PreToolUse hook: gate agent dispatch count — blocks Agent tool when parallel limit reached (max 5). Prevents T-073-class context explosions. |

## Related

### Tasks
- T-820: Fix TermLink dispatch preamble — workers write to target files
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-dispatch-preamble.yaml`*
*Last verified: 2026-03-01*
