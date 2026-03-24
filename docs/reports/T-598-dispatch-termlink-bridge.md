# T-598: Bridge fw dispatch to TermLink file/remote

## Status
Captured — not yet explored. T-599 (MCP server) and T-600 (attach-self) were originally created here but pivoted to TermLink pickup prompts.

## Initial Research (2026-03-24)

### Current State
- `fw dispatch send` sends JSON text envelopes over SSH pipe → `fw bus receive`
- TermLink has native `file send/receive`, `remote send-file/exec`, and `hub` commands
- These two systems are completely disconnected

### TermLink Capabilities Available
- `termlink file send <target> <path>` — chunked file transfer between sessions
- `termlink remote send-file <hub> <session> <path>` — cross-machine file transfer
- `termlink remote exec <hub> <session> <cmd>` — remote command execution
- `termlink hub start` — cross-session routing server

### Gap
Framework dispatch (`fw dispatch`) bypasses all of this and uses raw SSH pipes. The TermLink capabilities exist but are not wired into the framework layer.

### Related Pickups Sent
- `/tmp/termlink-pickup-002-mcp-server.md` → TermLink MCP server proposal
- `/tmp/termlink-pickup-003-attach-self.md` → TermLink attach-self proposal
