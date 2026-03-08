# check-dispatch

> Dispatch Guard — PostToolUse hook for Task/TaskOutput result size. Warns when sub-agent results exceed safe thresholds (G-008 enforcement).

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-dispatch.sh`

## What It Does

Dispatch Guard — PostToolUse hook for Task/TaskOutput result size
Warns when sub-agent results exceed safe thresholds (G-008 enforcement)
Three incidents (T-073, T-158, T-170) proved that unbounded tool output
crashes sessions. This hook provides a structural warning layer.
Detection:
1. Only fires for Task and TaskOutput tool calls
2. Measures tool_response content length
3. Warns if >5K chars (indicates agent returned content instead of writing to disk)
Exit code: always 0 (PostToolUse hooks are advisory, cannot block)
Output: JSON with additionalContext when oversized results detected

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/dispatch/preamble.md` | references |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `C-009` | triggered_by |
| `agents/audit/self-audit.sh` | verified_by |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-dispatch.yaml`*
*Last verified: 2026-03-01*
