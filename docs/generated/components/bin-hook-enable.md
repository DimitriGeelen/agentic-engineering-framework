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

| Target | Relationship |
|--------|-------------|
| `.claude/settings.json` | writes |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

---
*Auto-generated from Component Fabric. Card: `bin-hook-enable.yaml`*
*Last verified: 2026-04-24*
