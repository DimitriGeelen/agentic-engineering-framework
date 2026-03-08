# mcp-reaper

> Detects and kills orphaned MCP server processes (playwright-mcp, context7-mcp) left behind when Claude Code sessions crash. Identifies orphans via PPID=1, MCP command pattern, age threshold, and dead PGID leader.

**Type:** script | **Subsystem:** healing | **Location:** `agents/mcp/mcp-reaper.sh`

## What It Does

mcp-reaper.sh — Detect and kill orphaned MCP processes
When Claude Code sessions crash or end, MCP server processes (playwright-mcp,
context7-mcp) become orphaned (PPID=1), accumulating ~50-270MB each.
Detection: PPID=1 + MCP command pattern + age threshold + PGID leader dead
Cleanup: SIGTERM -> 5s grace -> SIGKILL survivors
Usage:
mcp-reaper.sh                    # Interactive: detect + confirm before killing
mcp-reaper.sh --dry-run          # Detect only, no killing
mcp-reaper.sh --force --quiet    # Automated: kill silently (for cron)
mcp-reaper.sh --age 60           # Set age threshold to 60 minutes

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

---
*Auto-generated from Component Fabric. Card: `agents-mcp-mcp-reaper.yaml`*
*Last verified: 2026-02-20*
