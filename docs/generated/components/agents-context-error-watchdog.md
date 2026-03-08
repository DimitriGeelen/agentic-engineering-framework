# error-watchdog

> Error Watchdog — PostToolUse hook for Bash error detection

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/error-watchdog.sh`

## What It Does

Error Watchdog — PostToolUse hook for Bash error detection
Detects failed Bash commands and injects investigation reminder (L-037/FP-007)
When a Bash command fails with a high-confidence error pattern, this hook
outputs JSON with additionalContext telling the agent to investigate the
root cause before proceeding — structural enforcement of CLAUDE.md §Error Protocol.
Detection strategy (conservative to avoid false positives):
1. Only fires for Bash tool calls
2. Skips exit code 0 (success)
3. For exit code 1: only warns on high-confidence stderr patterns
4. For exit codes 126, 127, 137, 139: always warns (never benign)

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `C-004` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-context-error-watchdog.yaml`*
*Last verified: 2026-02-20*
