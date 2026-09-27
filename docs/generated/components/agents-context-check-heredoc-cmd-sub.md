# check-heredoc-cmd-sub

> T-1945 — Heredoc-in-command-substitution edit-time guard.

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

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [heredoc_guard](/docs/generated/lib-heredoc_guard) | calls | T-1945 — Heredoc-in-cmd-substitution detector helper. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_heredoc_cmd_sub_guard](/docs/generated/tests-unit-test_heredoc_cmd_sub_guard) | called_by | T-1945 — PreToolUse heredoc-in-cmd-sub guard hook tests. |
| [test_heredoc_cmd_sub_guard](/docs/generated/tests-unit-test_heredoc_cmd_sub_guard) | tests_by | T-1945 — PreToolUse heredoc-in-cmd-sub guard hook tests. |
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | called_by | T-2710: a forced .claude/settings.json regenerate must not silently delete hooks that `fw hook-enable` added after init. |

---
*Auto-generated from Component Fabric. Card: `agents-context-check-heredoc-cmd-sub.yaml`*
*Last verified: 2026-05-20*
