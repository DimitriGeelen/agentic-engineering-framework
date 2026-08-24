# check-heredoc-cmd-sub

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-heredoc-cmd-sub.sh`

## What It Does

T-1945 — Heredoc-in-command-substitution edit-time guard.
PreToolUse hook on Write/Edit. When the agent proposes editing
bin/fw and the proposed content/new_string contains an inline
`$(... <<TAG ... TAG)` block (or `python3 - <<TAG`), emit a one-line
stderr warning naming L-332 and L-408 with the canonical fix.
Advisory only — exit 0. The class is a self-lockout failure mode but
not every heredoc-in-cmd-sub is dangerous (the stable multi-line-clean
`<<PYEOF\n...\nPYEOF\n)` shape works fine). Blocking would obstruct
legitimate maintenance edits to an existing heredoc.
Exit codes:

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [heredoc_guard](/docs/generated/lib-heredoc_guard) | calls | TODO: describe what this component does |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_heredoc_cmd_sub_guard](/docs/generated/tests-unit-test_heredoc_cmd_sub_guard) | called_by | TODO: describe what this component does |
| [test_heredoc_cmd_sub_guard](/docs/generated/tests-unit-test_heredoc_cmd_sub_guard) | tests_by | TODO: describe what this component does |
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-heredoc-cmd-sub.yaml`*
*Last verified: 2026-05-20*
