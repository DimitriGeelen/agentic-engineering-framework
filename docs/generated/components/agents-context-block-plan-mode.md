# block-plan-mode

> PreToolUse hook that blocks EnterPlanMode tool calls. Enforces D-027 (plan mode prohibition) by returning exit code 2 when agent attempts to use built-in plan mode.

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/block-plan-mode.sh`

**Tags:** `hook`, `enforcement`

## What It Does

Block built-in EnterPlanMode — bypasses framework governance (T-242)
Use /plan skill instead (requires active task, writes to docs/plans/)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `?` | uses |

## Related

### Tasks
- T-242: Block built-in EnterPlanMode from bypassing framework governance

---
*Auto-generated from Component Fabric. Card: `agents-context-block-plan-mode.yaml`*
*Last verified: 2026-03-04*
