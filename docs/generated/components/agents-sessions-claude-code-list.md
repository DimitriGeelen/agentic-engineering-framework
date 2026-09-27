# list

> Claude Code session adapter for fw sessions (T-2417): reads `claude agents --all --json` and emits canonical JSONL per agents/sessions/SCHEMA.md.

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/sessions/claude-code/list.sh`

## What It Does

Named .sh for adapter-protocol convention (consistent with other agent dirs);
shebang routes to python3. Bash never executes a line here.

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [sessions_claude_code_adapter](/docs/generated/tests-unit-sessions_claude_code_adapter) | called_by | T-2417: Claude Code session adapter — verifies canonical-JSONL emission per agents/sessions/SCHEMA.md from a stubbed `claude agents --all --json` response. |
| [sessions_claude_code_adapter](/docs/generated/tests-unit-sessions_claude_code_adapter) | tests_by | T-2417: Claude Code session adapter — verifies canonical-JSONL emission per agents/sessions/SCHEMA.md from a stubbed `claude agents --all --json` response. |

---
*Auto-generated from Component Fabric. Card: `agents-sessions-claude-code-list.yaml`*
*Last verified: 2026-06-16*
