# check-active-task

> Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-active-task.sh`

## What It Does

Task-First Enforcement Hook — PreToolUse gate for Write/Edit/Bash tools
Blocks file modifications when no active task is set in focus.yaml.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
Receives JSON on stdin with tool_name and tool_input.
For Write/Edit: checks tool_input.file_path
For Bash: checks tool_input.command against safe-command allowlist (T-650)
Exempt paths (framework operations that don't need task context):
.context/   — Context fabric management

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `agents/context/lib/safe-commands.sh` | calls |
| `lib/paths.sh` | calls |
| `lib/config.sh` | calls |

## Used By (7)

| Component | Relationship |
|-----------|-------------|
| `C-009` | triggered_by |
| `agents/audit/self-audit.sh` | verified_by |
| `agents/onboarding-test/test-onboarding.sh` | called_by |
| `agents/audit/self-audit.sh` | read_by |
| `agents/context/check-project-boundary.sh` | related_by |
| `C-009` | triggers_by |
| `.claude/settings.json` | used-by |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)

## Related

### Tasks
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

---
*Auto-generated from Component Fabric. Card: `agents-context-check-active-task.yaml`*
*Last verified: 2026-03-01*
