# TermLink Agent

> Cross-terminal session communication for parallel dispatch, self-testing, and remote control.

## About TermLink

TermLink is our in-house cross-terminal communication tool (Rust, 26 commands, 264 tests).

- **Repo:** `https://onedev.docker.ring20.geelenandcompany.com/termlink`
- **Install:** `git clone https://onedev.docker.ring20.geelenandcompany.com/termlink && cd termlink && cargo install --path crates/termlink-cli`
- **Update:** `cd <termlink-repo> && git pull && cargo install --path crates/termlink-cli`
- **Check:** `fw termlink check`

This agent is a **thin wrapper** — it adds framework concerns (task-tagging, budget checks,
cleanup tracking) but delegates all real work to the `termlink` binary. Don't rebuild what
TermLink already provides.

## Commands

### check — Verify TermLink availability

```bash
fw termlink check
```

Prints version and path if installed, exits 1 if not.

### spawn — Create a tagged terminal session

```bash
fw termlink spawn --task T-XXX [--name worker-1]
```

Opens a new terminal window (macOS: Terminal.app via osascript, Linux: gnome-terminal/xterm),
registers a TermLink session tagged with the task ID. Tracks window ID for cleanup.
Waits up to 15s for registration.

### exec — Run command in a session

```bash
fw termlink exec <session-name> <command>
```

Wraps `termlink interact --json` — the star primitive. Returns structured JSON with
output, exit_code, elapsed_ms.

### status — List active sessions

```bash
fw termlink status
```

Shows dispatch workers with status + all TermLink sessions.

### cleanup — Deregister and close spawned sessions

```bash
fw termlink cleanup
```

**3-phase cleanup (T-074/T-143 lesson — NEVER close Terminal windows directly):**
1. Kill child processes via TTY (spare login/shell PID)
2. `do script "exit"` to each window (graceful shell exit)
3. Close remaining windows by tracked window ID

### dispatch — Spawn a Claude worker

```bash
fw termlink dispatch --task T-XXX --name worker-1 --prompt "Analyze the auth module"
```

Spawns `claude -p` in a real terminal. Fire-and-forget via `pty inject` (NOT `interact` —
claude takes minutes). Worker writes result to `/tmp/tl-dispatch/<name>/result.md`.
Completion signaled via `termlink event emit <name> worker.done`.

Adapted from `scripts/tl-dispatch.sh` in the TermLink repo (tested with 3 parallel workers).

### wait — Wait for worker completion

```bash
fw termlink wait --name worker-1 [--timeout 300]
fw termlink wait --all [--timeout 600]
```

Uses `termlink event wait` first (fast), file-polling as fallback.

### result — Read worker output

```bash
fw termlink result worker-1
```

## Key TermLink Primitives

| Command | Purpose | Framework Use |
|---------|---------|---------------|
| `termlink interact <session> <cmd> --json` | Run command, get structured output | **Star primitive.** `fw termlink exec` wraps this |
| `termlink discover --json` | Find sessions by tag/role/name | Worker discovery |
| `termlink event emit/wait/poll` | Inter-session signaling | Coordination backbone |
| `termlink event broadcast <topic> <data>` | Fan-out to all listeners | Multi-worker notification |
| `termlink list --json` | List all sessions | Status overview |
| `termlink status <session> --json` | Session details | Health check |
| `termlink pty output <session> --strip-ansi` | Read terminal output | Log observation |
| `termlink pty inject <session> --enter` | Send input (fire-and-forget) | Long-running command start |
| `termlink register --shell --name X --tag Y` | Create named session | Tagged session lifecycle |
| `termlink hub start [--tcp ADDR]` | Start hub (optional TCP) | Cross-machine coordination |

## Budget Rules

- **Do not spawn new sessions when context > 60%**
- **Always cleanup before session end** — `fw termlink cleanup`
- **Max 5 parallel workers** — same as sub-agent dispatch protocol
- **Leave 40K tokens headroom** before dispatching

## Phase Roadmap

| Phase | Scope | TermLink provides |
|-------|-------|-------------------|
| 0 | fw doctor + agent wrapper + fw route + CLAUDE.md | Binary on PATH |
| 1 | Self-test via termlink interact | interact, output, register |
| 2 | Parallel dispatch (replace Agent tool mesh) | pty inject, events, discover |
| 3 | Remote control + observation | attach, inject, output, stream |
| 4 | Cross-machine coordination | TCP hub, remote store, hybrid discover |
