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

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [hook-config](/docs/generated/hook-config) | triggers_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [hook-config](/docs/generated/hook-config) | used-by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called-by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `agents-context-error-watchdog.yaml`*
*Last verified: 2026-02-20*
