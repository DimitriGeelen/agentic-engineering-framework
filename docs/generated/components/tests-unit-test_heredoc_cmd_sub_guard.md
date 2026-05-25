# test_heredoc_cmd_sub_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_heredoc_cmd_sub_guard.bats`

## What It Does

T-1945 — PreToolUse heredoc-in-cmd-sub guard hook tests.
The hook surfaces L-332/L-408 at edit time when the agent proposes
adding a `$(... <<TAG ... TAG)` block to bin/fw — closing the
task-create → edit-time prevention gap that bit T-1942 twice.

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `agents/context/check-heredoc-cmd-sub.sh` | calls |
| `agents/context/check-heredoc-cmd-sub.sh` | tests |
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_heredoc_cmd_sub_guard.yaml`*
*Last verified: 2026-05-20*
