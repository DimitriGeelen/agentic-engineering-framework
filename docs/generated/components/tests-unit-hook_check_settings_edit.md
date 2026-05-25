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

| Target | Relationship |
|--------|-------------|
| `agents/context/check-settings-edit.sh` | tests |
| `agents/context/check-settings-edit.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_check_settings_edit.yaml`*
*Last verified: 2026-05-17*
