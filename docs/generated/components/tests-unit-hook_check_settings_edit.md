# hook_check_settings_edit

> Bats unit tests for agents/context/check-settings-edit.sh (T-1888).
6 cases covering: positive Edit match, positive Write match (absolute path),
negative non-match (unrelated file), defence-in-depth (Bash tool ignored),
malformed JSON tolerance, and wrong-directory look-alike rejection.

Pinned at T-1888 close; baseline for regression detection if the hook's
match logic changes.


**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/hook_check_settings_edit.bats`

**Tags:** `test`, `bats`, `hook`, `posttooluse`, `L-398`

## What It Does

T-1888: PostToolUse hook check-settings-edit.sh — fires advisory L-398 reminder
when .claude/settings.json is written/edited. Strictly advisory (exit 0).
Pattern matches existing check-fabric-new-file.sh tests: stdin JSON, stdout
either empty (no match) or a JSON envelope with additionalContext.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-settings-edit](/docs/generated/agents-context-check-settings-edit) | tests | PostToolUse hook (Write\|Edit matcher) that fires an advisory L-398 reminder when .claude/settings.json is written/edited. Reminds the agent to add `bin/fw enforcement baseline` to the active task's Verification block so the canonical hash refreshes at task-close. Strictly advisory (exit 0).  Origin: T-1886 RCA Candidate B — paired with T-1887 Candidate A (template hint). The enforcement-baseline-drift class accumulated for multiple sessions across T-1849/T-1730/T-1731 before T-1886 cleaned up. |
| [check-settings-edit](/docs/generated/agents-context-check-settings-edit) | calls | PostToolUse hook (Write\|Edit matcher) that fires an advisory L-398 reminder when .claude/settings.json is written/edited. Reminds the agent to add `bin/fw enforcement baseline` to the active task's Verification block so the canonical hash refreshes at task-close. Strictly advisory (exit 0).  Origin: T-1886 RCA Candidate B — paired with T-1887 Candidate A (template hint). The enforcement-baseline-drift class accumulated for multiple sessions across T-1849/T-1730/T-1731 before T-1886 cleaned up. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_check_settings_edit.yaml`*
*Last verified: 2026-05-17*
