# T-599: MCP Server for TermLink — Research Artifact

## Problem Statement

**For whom:** AI agents (Claude Code, Cursor, etc.) that want to discover and use TermLink session management as structured tools.
**Why now:** MCP (Model Context Protocol) is the standard for AI agent tool discovery. TermLink commands are currently invoked via bash wrappers — opaque to agent tool catalogs.

## Critical Finding: TermLink Already Has `termlink mcp serve`

**TermLink v1.x already includes a built-in MCP server.** It is a subcommand (`termlink mcp serve`) that runs on stdio, compatible with Claude Code and other MCP clients.

This means the inception question has shifted from "should we build an MCP server?" to "should we wire the existing one into the framework's .mcp.json?"

## Current State

### TermLink MCP server
- Command: `termlink mcp serve` (stdio transport)
- Available: Yes (installed on .112)
- Tools exposed: Unknown without running it (would need to test)
- Integration: NOT in `.mcp.json` — not discoverable by Claude Code currently

### Framework MCP configuration
- `.mcp.json` has 2 servers: context7 (docs), playwright (browser)
- No TermLink MCP server configured
- T-646 (MCP auto-config) seeds `.mcp.json` during `fw init` — could include TermLink

### TermLink command surface (26 commands)
High-value candidates for MCP tools:
1. `register/list/discover` — session lifecycle and discovery
2. `interact` — synchronous command execution in session
3. `spawn` — create new terminal sessions
4. `event emit/wait/broadcast` — inter-session signaling
5. `file send` — chunked file transfer
6. `hub start` — cross-machine routing
7. `dispatch` — multi-worker coordination

## Analysis

### What wiring would require
1. Add to `.mcp.json`: `"termlink": { "command": "termlink", "args": ["mcp", "serve"] }`
2. Verify tools are discoverable by Claude Code
3. Test tool invocation end-to-end
4. Document which tools are available and what they do

### Value assessment
- **For this framework:** Low incremental value. The `fw termlink` wrapper already provides all commands, and Claude Code invokes them via Bash tool. MCP would make tools discoverable in the tool catalog but doesn't add new capability.
- **For external users:** Medium value. Users who install TermLink could get structured tool access without learning bash commands. But TermLink is optional (most users won't have it).
- **For other agents (Cursor, Windsurf):** Medium-high value. Non-Claude Code agents can't use framework hooks. MCP tools would be their primary interface to TermLink.

### Risks
- **MCP server stability:** TermLink's MCP server is new/untested in the framework
- **Conflicting invocations:** Agent might use MCP tools AND bash wrappers for the same operation
- **Security:** MCP tools bypass the framework's hook system (no task gate, no tier-0 check)
- **Maintenance:** Another moving part in the MCP config

## Assumption Testing

- A1: TermLink MCP server exposes useful tools (NOT YET TESTED — need to run and inspect)
- A2: MCP integration provides value beyond bash wrappers (PARTIALLY VALID — for non-Claude Code agents yes, for Claude Code minimal)
- A3: Security model is adequate (NOT VALIDATED — MCP tools bypass PreToolUse hooks)
- A4: Framework should manage TermLink MCP config (VALID — T-646 already seeds .mcp.json)

## Recommendation: CONDITIONAL GO

**GO for minimal wiring** (add to .mcp.json + test):
1. Add `termlink mcp serve` to `.mcp.json` — one line change
2. Test what tools are exposed
3. Document in CLAUDE.md
4. Effort: <1 hour

**DEFER advanced integration** (custom tools, hub management via MCP) until:
- The built-in MCP server is tested and stable
- D4 (Portability) demands non-Claude Code agent support
- Hub infrastructure is deployed (T-598)

**Security note:** MCP tools bypass framework hooks. This is acceptable for read-only operations (list, discover, status) but concerning for write operations (spawn, signal, dispatch). May need MCP-level tool gating if write tools are exposed.
