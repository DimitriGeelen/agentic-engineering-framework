# check-settings-edit

> PostToolUse hook (Write|Edit matcher) that fires an advisory L-398 reminder
when .claude/settings.json is written/edited. Reminds the agent to add
`bin/fw enforcement baseline` to the active task's Verification block so
the canonical hash refreshes at task-close. Strictly advisory (exit 0).

Origin: T-1886 RCA Candidate B — paired with T-1887 Candidate A (template
hint). The enforcement-baseline-drift class accumulated for multiple
sessions across T-1849/T-1730/T-1731 before T-1886 cleaned up.


**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-settings-edit.sh`

**Tags:** `hook`, `posttooluse`, `governance`, `baseline`, `L-398`

## What It Does

Enforcement-baseline refresh nudge — PostToolUse hook for Write|Edit on .claude/settings.json
When the agent edits .claude/settings.json (adding/removing/reorganising hooks), emits an
advisory reminder to add `bin/fw enforcement baseline` to the active task's Verification
block. Otherwise the canonical hash diverges and `fw doctor` reports FAIL.
Exit code: always 0 (advisory only, never blocks).
Output: JSON with additionalContext when reminder needed; nothing otherwise.
Origin: T-1886 RCA Candidate B — deployed after T-1887 Candidate A (template hint).
Pairs with L-398. See also: T-1849, T-1730, T-1731 (the hook-additions that originally
left the baseline in FAIL across multiple sessions).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | triggers | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [hook_check_settings_edit](/docs/generated/tests-unit-hook_check_settings_edit) | tested_by | Bats unit tests for agents/context/check-settings-edit.sh (T-1888). 6 cases covering: positive Edit match, positive Write match (absolute path), negative non-match (unrelated file), defence-in-depth (Bash tool ignored), malformed JSON tolerance, and wrong-directory look-alike rejection.  Pinned at T-1888 close; baseline for regression detection if the hook's match logic changes. |
| [hook_check_settings_edit](/docs/generated/tests-unit-hook_check_settings_edit) | called_by | Bats unit tests for agents/context/check-settings-edit.sh (T-1888). 6 cases covering: positive Edit match, positive Write match (absolute path), negative non-match (unrelated file), defence-in-depth (Bash tool ignored), malformed JSON tolerance, and wrong-directory look-alike rejection.  Pinned at T-1888 close; baseline for regression detection if the hook's match logic changes. |
| [hook_check_settings_edit](/docs/generated/tests-unit-hook_check_settings_edit) | tests_by | Bats unit tests for agents/context/check-settings-edit.sh (T-1888). 6 cases covering: positive Edit match, positive Write match (absolute path), negative non-match (unrelated file), defence-in-depth (Bash tool ignored), malformed JSON tolerance, and wrong-directory look-alike rejection.  Pinned at T-1888 close; baseline for regression detection if the hook's match logic changes. |
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-settings-edit.yaml`*
*Last verified: 2026-05-17*
