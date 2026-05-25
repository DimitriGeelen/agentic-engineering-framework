# hook-enable

> Register framework hooks in .claude/settings.json idempotently — adds { type "command", command ".agentic-framework/bin/fw hook <name>" } entries under specified event/matcher pair. Built under T-1189 to repair T-977 false-complete (G-015).

**Type:** script | **Subsystem:** cli-entrypoints | **Location:** `bin/hook-enable.sh`

**Tags:** `hook`, `registration`, `settings`

## What It Does

fw hook-enable — register a framework hook in .claude/settings.json
Usage: fw hook-enable --name <hook> --matcher <pat> --event <evt> [--file <path>] [--dry-run]
Adds a { type: "command", command: ".agentic-framework/bin/fw hook <name>" } entry
under the specified event/matcher in .claude/settings.json. Idempotent — if the exact
(event, matcher, command) tuple already exists, exits 0 with "already registered".
Written 2026-04-22 under T-1189 to repair T-977 false-complete (G-015 Hit #2).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | writes | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [hook_enable_absolute_path](/docs/generated/tests-unit-hook_enable_absolute_path) | called_by | TODO: describe what this component does |
| [hook_enable_absolute_path](/docs/generated/tests-unit-hook_enable_absolute_path) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `bin-hook-enable.yaml`*
*Last verified: 2026-04-24*
