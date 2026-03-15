# TermLink Agent

> Cross-terminal session communication for parallel dispatch, self-testing, and remote control.

## Purpose

TermLink is an **optional** external tool that enables the framework to:
- Spawn and manage Claude workers in real terminal sessions
- Run commands in remote/parallel terminals with structured output
- Coordinate multi-session workflows via events
- Observe terminal output from other sessions

TermLink is a separate Rust binary (`cargo install termlink`). This agent provides the
framework integration wrapper — it does NOT ship TermLink itself.

## Prerequisites

- TermLink installed: `cargo install termlink`
- Check: `fw termlink check`
- macOS: Terminal.app required for spawn/cleanup (osascript)
- Linux: spawn/cleanup use `x-terminal-emulator` or `gnome-terminal` fallback

## Commands

### check — Verify TermLink availability

```bash
fw termlink check
```

Prints version if installed, exits 1 if not. Use in scripts for conditional TermLink usage.

### spawn — Create a tagged terminal session

```bash
fw termlink spawn --task T-XXX [--name worker-1]
```

Opens a new terminal window, registers a TermLink session tagged with the task ID.
Tracks the window ID for cleanup. Waits up to 15s for registration.

### exec — Run command in a session

```bash
fw termlink exec <session-name> <command>
```

Wraps `termlink interact --json`. Returns structured output:
```json
{"output": "...", "exit_code": 0, "elapsed_ms": 123}
```

### status — List active sessions

```bash
fw termlink status
```

Shows all TermLink sessions with task tags and roles.

### cleanup — Deregister and close spawned sessions

```bash
fw termlink cleanup
```

**3-phase cleanup (critical — learned the hard way):**
1. Kill child processes via TTY (spare login/shell PID)
2. `do script "exit"` to each window (graceful shell exit)
3. Close remaining windows by tracked window ID

Never use `close` directly on Terminal windows — it can orphan processes.

### dispatch — Spawn a Claude worker

```bash
fw termlink dispatch --task T-XXX --name worker-1 --prompt "Analyze the auth module"
```

Spawns a `claude -p` worker in a real terminal. Fire-and-forget via `pty inject`.
Worker writes result to `/tmp/tl-dispatch-<name>/result.md`.
Completion signaled via `termlink event emit <name> worker.done`.

### wait — Wait for worker completion

```bash
fw termlink wait --name worker-1 [--timeout 300]
fw termlink wait --all [--timeout 600]
```

Blocks until the named worker (or all workers) emit `worker.done`.

### result — Read worker output

```bash
fw termlink result --name worker-1
```

Reads the result file from the dispatch working directory.

## Key TermLink Primitives

| Command | Purpose | Framework Use |
|---------|---------|---------------|
| `termlink interact <session> <cmd> --json` | Run command, get structured output | Star primitive. `termlink.sh exec` wraps this |
| `termlink discover --json` | Find sessions by tag/role/name | Worker discovery |
| `termlink event emit/wait/poll` | Inter-session signaling | Coordination backbone |
| `termlink event broadcast <topic> <data>` | Fan-out to all listeners | Multi-worker notification |
| `termlink list --json` | List all sessions | Status overview |
| `termlink status <session> --json` | Session details | Health check |
| `termlink output <session> --strip-ansi` | Read terminal output | Log observation |
| `termlink pty inject <session> --enter` | Send input (fire-and-forget) | Long-running command start |
| `termlink register --shell --name X --tag Y` | Create named session | Tagged session lifecycle |
| `termlink hub start [--tcp ADDR]` | Start hub (optional TCP) | Cross-machine coordination |

## Budget Rules

- **Do not spawn new sessions when context > 60%** — workers consume orchestrator context when results return
- **Always cleanup before session end** — `fw termlink cleanup` in session-end checklist
- **Max 5 parallel workers** — same as sub-agent dispatch protocol
- **Leave 40K tokens headroom** before dispatching workers

## Phase Roadmap

| Phase | Scope | Status |
|-------|-------|--------|
| 0 | fw doctor + agent wrapper + fw route + CLAUDE.md | Current |
| 1 | Self-test integration (move /self-test to fw subcommand) | Future |
| 2 | Parallel dispatch via TermLink (replace Agent tool mesh) | Future |
| 3 | Remote control + attach patterns | Future |
| 4 | TCP transport + cross-machine | Future |
