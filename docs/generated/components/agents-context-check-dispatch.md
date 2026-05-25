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

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [preamble](/docs/generated/agents-dispatch-preamble) | references | Mandatory dispatch preamble — output rules for sub-agents to prevent context explosion (T-073). Requires disk writes, <=5 line responses. — _Warning messages direct agents to include the dispatch preamble_ |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | triggered_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. — _PostToolUse hook on Task\|TaskOutput (.claude/settings.json)_ |
| [self-audit](/docs/generated/agents-audit-self-audit) | verified_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. — _self-audit checks existence and executable bit_ |
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [hook-config](/docs/generated/hook-config) | triggers_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [hook-config](/docs/generated/hook-config) | used-by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-dispatch.yaml`*
*Last verified: 2026-03-01*
