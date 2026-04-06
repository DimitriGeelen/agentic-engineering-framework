# T-962 v4: TermLink ↔ Web Terminal Integration Architecture

**Task:** T-962 (Inception — web terminal in Watchtower)
**Date:** 2026-04-06
**Depends on:** v1 (xterm.js selected), v2/v3 (PTY bridges, full solutions)
**Purpose:** Define how TermLink (Rust CLI v0.9.0) integrates with xterm.js in the browser via Flask WebSocket bridge

---

## Executive Summary

Two viable architectures exist: **TermLink-bridged** (Flask polls `pty output`/`pty inject` and relays via WebSocket) and **Flask-native PTY** (Flask owns the PTY directly, registers with TermLink for discoverability). TermLink-bridged adds 50-200ms latency per keystroke from the polling layer but preserves TermLink as the single session authority. Flask-native gives sub-5ms latency but creates a dual-authority problem.

**Recommendation: hybrid.** Flask spawns PTYs directly for interactive terminals (latency-critical) and registers them with TermLink via `termlink register --shell`. Flask uses TermLink-bridged mode for attaching to pre-existing TermLink sessions (observation use case). Both session types appear in a unified session list.

---

## 1. Research Findings — Seven Vectors

### 1.1 Can `pty output` Be Polled via WebSocket? Latency?

**Yes, but with inherent latency that rules out interactive use.**

`termlink pty output <session> --strip-ansi` reads the terminal buffer of a TermLink-managed session. Each call is a **synchronous CLI invocation** — fork a process, read the PTY buffer, exit.

**Polling architecture:**
```
Browser ←WebSocket→ Flask ←poll loop→ termlink pty output <session>
```

**Latency breakdown per poll cycle:**

| Component | Latency | Notes |
|-----------|---------|-------|
| `termlink pty output` process spawn | 5-15ms | Rust binary, fast cold start |
| PTY buffer read | <1ms | Kernel buffer, memory-mapped |
| `--strip-ansi` processing | <1ms | Regex pass over buffer |
| Flask → WebSocket send | <1ms | In-process |
| WebSocket → browser render | 1-3ms | Network + xterm.js parse |
| **Total per poll cycle** | **8-20ms** | |
| **With 50ms poll interval** | **50-70ms worst case** | Keystroke echo delay |
| **With 200ms poll interval** | **200-220ms worst case** | Observation-quality |

**The problem is not per-call latency — it's poll frequency.** At 50ms intervals, Flask executes `termlink pty output` 20 times/second per connected session. Each invocation forks a process. With 5 concurrent bridged sessions, that's 100 process spawns/second — meaningful CPU load.

**Differential output challenge:** `pty output` returns the full visible buffer (or last N lines via `--lines`). Flask must diff successive reads to send only new content. This is fragile:
- Terminal redraws (vi, htop, resize) invalidate simple line-diffing
- Cursor movement creates false diffs
- `--strip-ansi` removes escape codes that xterm.js needs for rendering

**Workaround — raw output without `--strip-ansi`:** Send raw ANSI to xterm.js (it understands escape codes natively). Diff on raw byte content, not lines. This preserves colors and cursor positioning but increases diff complexity.

**Adaptive polling strategy:**
- **Active** (keystroke in last 2s): poll every 100ms
- **Idle** (no recent input): poll every 500ms
- **Background** (tab not visible): poll every 2000ms
- Reduces average CPU by ~60% during typical usage patterns

**Verdict:** Feasible for observation/monitoring (100-200ms refresh is fine for watching agent sessions). Not viable for interactive typing (50ms+ echo delay is perceptible; 100ms is sluggish for vim/emacs).

### 1.2 Can `pty inject` Receive Browser Keystrokes? Race Conditions?

**Yes, with caveats on ordering and special keys.**

`termlink pty inject <session> "text" --enter` writes bytes to the PTY's stdin. It is fire-and-forget — no acknowledgment, no output capture.

**Keystroke flow:**
```
Browser keypress → WebSocket msg → Flask handler → termlink pty inject <session> "x"
```

**Race conditions identified:**

**1. Input reordering.** If the user types "hello" fast (5 keystrokes in <100ms), Flask receives 5 WebSocket messages. Each spawns a separate `termlink pty inject` process. OS process scheduling is non-deterministic — "hello" could arrive at the PTY as "hlelo" or "hlloe".

*Mitigation:* Flask must serialize inject calls per session with a queue + sequential execution thread. Each session gets one inject-worker thread that drains the queue FIFO.

**2. Batch vs character-at-a-time trade-off.** Injecting one character per process spawn costs ~10ms overhead per character. Batching keystrokes (accumulate for 16ms, inject batch) reduces overhead by 5-10x but adds 16ms input latency.

*Recommendation:* 16ms batch window (one animation frame). Imperceptible to humans but cuts subprocess spawns dramatically. At 60 WPM (~5 chars/sec), most keystrokes arrive alone anyway — batching helps only during fast typing or paste operations.

**3. Special key translation.** `pty inject` sends raw text. Browser key events must be translated to ANSI escape sequences:

| Key | ANSI Sequence | `pty inject` call |
|-----|--------------|-------------------|
| Enter | `\r` | `--enter` flag |
| Ctrl+C | `\x03` | Raw byte injection |
| Arrow Up | `\x1b[A` | Raw byte injection |
| Tab | `\t` | Raw byte injection |
| Ctrl+D | `\x04` | Raw byte injection |
| Backspace | `\x7f` | Raw byte injection |
| Paste (multi-line) | text with `\r\n` | Batch inject |

xterm.js `onData()` callback already provides the correct byte sequences — it handles the keyboard-to-ANSI translation. Flask passes the raw data through to `pty inject` without interpretation.

**4. No flow control.** If the PTY's input buffer is full (unlikely in practice, possible with very large paste operations), `pty inject` has no backpressure mechanism. Pasted text could be truncated.

*Mitigation for paste:* Chunk large pastes (>4KB) into 1KB segments with 10ms delays between chunks.

**5. Echo verification gap.** After injecting input, there's no way to confirm the PTY received it without polling `pty output` and checking for the echo. If injection silently fails (session died between list check and inject), the user sees no feedback.

*Mitigation:* Optimistic UI — show input locally in xterm.js immediately (local echo), then verify via next `pty output` poll. If output doesn't reflect input within 2 poll cycles, show error indicator.

**Verdict:** Works for command-level interaction (type command, press enter). Marginal for character-at-a-time interactive use (vi, emacs, ncurses apps) due to serialization overhead and special-key latency. Combined with polling latency from §1.1, the full round-trip (type → inject → process → output → poll → render) for bridged sessions is 100-300ms. Adequate for monitoring with occasional command entry; inadequate for interactive editing.

### 1.3 Session Discovery for UI Presentation

**Well-supported via `termlink discover` and `termlink list`.**

```bash
# List all sessions
termlink list --json
# → [{"name":"worker-1","pid":12345,"tags":["task:T-962","role:worker"],"started":"2026-04-06T18:00:00Z",...}]

# Filter by tag
termlink discover --json --tag "task:T-962"
# → Sessions matching tag filter

# Filter by role
termlink discover --json --role worker
# → Worker sessions only
```

**TermLink field → UI element mapping:**

| TermLink field | UI element | Rendering |
|----------------|------------|-----------|
| `name` | Tab label / session title | Text |
| `tags` (`task:T-XXX`) | Task group header | Group sessions by task |
| `tags` (`role:worker`) | Badge icon | Worker=gear, master=crown, shell=terminal |
| `tags` (`source:watchtower`) | Ownership indicator | "Browser" vs "CLI" label |
| `pid` | Liveness indicator | Green=alive, gray=dead (check `/proc/<pid>/status`) |
| Start time | Duration tooltip | "Running for 5m 23s" |
| Session type | Capability badge | Interactive (full keyboard) vs Monitor (read + inject) |

**Refresh strategy:** 
- Poll `termlink list --json` every 5 seconds from a background thread
- Cache result in `SessionRegistry`
- Serve to browser via htmx polling (`hx-get="/terminal/sessions" hx-trigger="every 5s"`)
- Session list changes slowly (seconds, not milliseconds) — no WebSocket needed for discovery

**Session naming convention:**

| Source | Name pattern | Example |
|--------|-------------|---------|
| Browser-spawned | `web-<slug>-<seq>` | `web-shell-1`, `web-debug-3` |
| TermLink dispatch | `dispatch-<task>-<name>` | `dispatch-T962-worker-1` |
| Claude worker | `claude-<task>-<pid>` | `claude-T962-48721` |
| Manual terminal | User-chosen | `my-session`, `test-env` |

**Stale session detection:** Cross-reference `termlink list` PIDs with `/proc/<pid>/status`. If PID is dead but TermLink still lists it, mark as DEAD in UI and trigger `termlink clean` background task.

**Verdict:** Excellent fit. TermLink's tagging + JSON output maps directly to UI presentation needs. No TermLink changes required.

### 1.4 Attach Equivalent Through WebSocket + xterm.js

**This is the hardest problem.** `termlink attach` (Phase 3 roadmap, not yet implemented) would provide a full TUI mirror — bidirectional PTY proxying. Replicating this through a web browser requires:

```
xterm.js ←WebSocket→ Flask ←PTY proxy→ TermLink session's PTY fd
```

**The fundamental tension:** TermLink owns the PTY file descriptor. Flask cannot directly read/write it — only through `pty output`/`pty inject` CLI calls. This forces the polling architecture from §1.1.

**Four approaches to bridge the gap:**

| Approach | Latency | TermLink changes | Complexity |
|----------|---------|-------------------|------------|
| A. CLI polling (current) | 100-300ms | None | Low |
| B. Unix socket streaming | <10ms | Yes (stream API) | Medium |
| C. PTY fd passing | <5ms | Yes (fd export) | High |
| D. TermLink WebSocket mode | <10ms | Yes (WS server) | High |

**Approach A (what works today):** Poll `pty output` + serialize `pty inject`. Latency 100-300ms. Adequate for observation. No TermLink changes.

**Approach B (hypothetical):** TermLink opens a Unix domain socket per session that streams raw PTY output. Flask connects to the socket for non-blocking reads. `pty inject` remains CLI-based for input (input is low-frequency). This would bring output latency to <10ms without a full TermLink rewrite.

**Approach C (hypothetical):** TermLink exports the PTY master fd number. Flask opens `/proc/<tl_pid>/fd/<N>` or receives the fd via SCM_RIGHTS over Unix socket. Flask then has direct fd access — sub-5ms latency, identical to native PTY. Extremely powerful but requires TermLink to expose process-internal state.

**Approach D (hypothetical):** `termlink ws <session> --port 8765` starts a WebSocket server proxying the PTY. xterm.js `addon-attach` connects directly, bypassing Flask entirely. Eliminates Flask from the hot path. Requires TermLink to become a web server — significant scope.

**What's achievable today (no TermLink changes):**
- **Read-only observation:** `pty output` polling at 100-200ms — good for watching sessions
- **Command injection:** `pty inject` with batching — good for sending individual commands
- **Full interactive attach:** Not viable at acceptable latency

**What the hybrid architecture provides:**
- **New terminals from browser:** Flask-native PTY → sub-5ms latency → full interactive attach
- **Existing TermLink sessions:** Approach A (CLI polling) → observation quality
- **Future upgrade path:** When TermLink adds streaming (B) or WebSocket (D), swap TLBridge implementation without changing the WebSocket protocol or UI

**Verdict:** True interactive attach for external TermLink sessions requires TermLink changes. The hybrid architecture sidesteps this by owning the PTY for interactive sessions and accepting observation-quality for external sessions. This is the right trade-off: users who need interactive shells use browser-spawned sessions; users watching agent sessions use bridged sessions.

### 1.5 Spawning New Sessions from Web UI

**Straightforward — two spawn paths:**

**Path 1: Browser-interactive session (Flask-native PTY)**
```
1. Browser: POST /api/terminal/spawn {"name":"debug-1","shell":"/bin/bash","cols":120,"rows":30}
2. Flask:
   a. pid, fd = pty.fork()  →  child: exec("/bin/bash")
   b. Set TERM=xterm-256color, cwd=framework_root
   c. Register: termlink register --shell --name web-debug-1 --tags "source:watchtower,task:T-962"
   d. Store in SessionRegistry: {id, fd, pid, mode:"native", state:"spawned"}
   e. Return: {"session_id":"web-debug-1","ws_url":"/ws/terminal/web-debug-1"}
3. Browser: opens WebSocket → state transitions to CONNECTED
```

**Path 2: Attach to existing TermLink session (bridged)**
```
1. Session list shows TermLink session "claude-worker-T962"
2. Browser: POST /api/terminal/bridge {"session":"claude-worker-T962"}
3. Flask:
   a. Verify: termlink list --json | find session
   b. Fetch initial buffer: termlink pty output claude-worker-T962 --lines 500
   c. Store: {id, mode:"bridge", state:"bridging", poll_interval:200}
   d. Return: {"session_id":"claude-worker-T962","ws_url":"/ws/terminal/claude-worker-T962","mode":"bridge"}
4. Browser: opens WebSocket → receives initial buffer → state transitions to CONNECTED
```

**Spawn constraints:**

| Parameter | Constraint | Reason |
|-----------|-----------|--------|
| Shell binary | Allowlist: `/bin/bash`, `/bin/zsh`, `/bin/sh` | Prevent arbitrary execution |
| Working directory | Must be under framework root | Prevent filesystem traversal |
| Max native sessions | 5 | Thread + fd budget |
| Max bridged sessions | 20 | Poll CPU budget |
| Session name | `[a-zA-Z0-9_-]{1,64}` | Prevent command injection via name |
| Environment vars | TERM only (user-settable) | Prevent env-based attacks |

**Naming convention:** Browser-spawned sessions get `web-` prefix (e.g., `web-shell-1`, `web-debug-3`). This distinguishes them from CLI-spawned sessions in TermLink discovery and prevents name collisions.

**Verdict:** Clean integration point. Flask controls spawn, TermLink provides discoverability. No TermLink changes needed.

### 1.6 Session Lifecycle: Start / Reconnect / End / Cleanup

**Complete state machine:**

```
                          User clicks               Process
                          "New Terminal"             exits
                               │                      │
                               ▼                      ▼
  ┌────────────┐ spawn  ┌──────────┐ ws_open  ┌───────────┐ process_exit ┌──────┐
  │            │───────▶│ SPAWNED  │────────▶│ CONNECTED │────────────▶│ DEAD │
  │            │        └──────────┘         └───────────┘             └──────┘
  │            │                               │       ▲                  ▲
  │ DISCOVERED │                         ws_close  ws_open           timeout
  │ (TermLink  │                               │       │             (30s)
  │  found)    │ bridge ┌──────────┐ ws+buf   │       │                │
  │            │───────▶│ BRIDGING │────────▶├───────┤                │
  │            │        └──────────┘         │       │                │
  └────────────┘                               ▼       │                │
       ▲                                ┌──────────────┐               │
       │           re-discover          │DISCONNECTED  │───────────────┘
       └────────────────────────────────│(PTY alive,   │
                                        │ WS closed)   │
                                        └──────────────┘
```

**State transition table:**

| From | Event | To | Action |
|------|-------|----|--------|
| — | spawn request | SPAWNED | `pty.fork()` + TermLink register |
| — | termlink list finds session | DISCOVERED | Add to session list |
| SPAWNED | WebSocket connected | CONNECTED | Start I/O loop (select-based for native) |
| DISCOVERED | bridge request | BRIDGING | Fetch initial buffer via `pty output --lines 500` |
| BRIDGING | WS connected + buffer sent | CONNECTED | Start poll loop (for bridged) |
| CONNECTED | WS closed (browser tab close, network drop) | DISCONNECTED | Pause I/O, keep PTY alive |
| CONNECTED | Process exit (child shell exited) | DEAD | Close WS with `{"type":"ended","exit_code":N}` |
| CONNECTED | kill request | DEAD | Send SIGHUP to PTY child, close WS |
| DISCONNECTED | WS reconnected within 30s | CONNECTED | Replay buffered output, resume I/O |
| DISCONNECTED | 30s timeout (native session) | DEAD | SIGHUP to child, deregister TermLink |
| DISCONNECTED | 30s timeout (bridged session) | DISCOVERED | Return to discovery pool |
| DEAD | 30s | (removed) | Purge from registry, free resources |

**Reconnection protocol:**
1. Browser opens WS to `/ws/terminal/<session-id>` (same URL as initial connect)
2. Flask checks session state in registry
3. If DISCONNECTED:
   - Native: replay last 1000 lines from PTY scrollback buffer
   - Bridged: fetch `pty output --lines 500`, send full buffer
   - Transition to CONNECTED
4. If DEAD: return `{"type":"error","code":"SESSION_DEAD"}`, browser shows "Session ended" with respawn option
5. If never existed: return `{"type":"error","code":"SESSION_NOT_FOUND"}`

**Browser-side reconnection:**
```javascript
// Exponential backoff: 1s, 2s, 4s, 8s, max 30s
handleClose(event) {
  if (event.code === 4001) return; // Auth failure, don't retry
  const delay = Math.min(1000 * Math.pow(2, this.retryCount), 30000);
  setTimeout(() => this.connect(), delay);
  this.retryCount++;
}
```

**Cleanup responsibilities:**

| Event | Native session cleanup | Bridged session cleanup |
|-------|----------------------|------------------------|
| User clicks kill | SIGHUP to child → wait → deregister TermLink | Stop polling, remove from registry |
| Browser tab closes | Keep alive 30s (DISCONNECTED) | Stop polling, return to DISCOVERED |
| Flask server shutdown | SIGHUP all children → deregister all | Stop all polls |
| PTY child exits | Close WS, deregister TermLink, purge after 30s | Detect via next poll, show DEAD |
| Orphan detection (60s bg task) | Check `/proc/<pid>/status`, kill orphans | Check `termlink list`, remove stale |

**`beforeunload` behavior:** Browser sends `{"type":"detach"}` (not kill) on tab close. PTY survives — user can reconnect within 30s window. This enables page refresh without losing terminal state.

### 1.7 Performance: Polling vs Direct PTY fd

**Head-to-head comparison:**

| Metric | CLI Polling (50ms) | CLI Polling (200ms) | Direct PTY fd | TermLink WS (hypothetical) |
|--------|--------------------|---------------------|---------------|---------------------------|
| Keystroke echo (round-trip) | 50-100ms | 200-300ms | <5ms | <10ms |
| Output latency | 50-70ms | 200-220ms | <5ms | <10ms |
| Output throughput | ~200KB/s | ~50KB/s | ~50MB/s | ~10MB/s |
| CPU per session (idle) | ~2% (20 forks/s) | ~0.5% (5 forks/s) | <0.1% | <0.1% |
| CPU per session (active) | ~3% (fork + diff) | ~1% | ~1% (I/O shuttle) | ~0.5% |
| Memory per session | ~1MB (buffer cache) | ~1MB | ~2MB (PTY + buffers) | ~1MB |
| Max concurrent sessions | ~10 (CPU-limited) | ~50 (CPU-limited) | ~100+ (fd-limited) | Unlimited |
| Supports ncurses apps | Poorly (output desync) | No (too slow) | Yes (native) | Yes |
| Process spawns/sec | 20/session | 5/session | 0 | 0 |
| Resize support | No (TermLink lacks resize cmd) | No | Yes (ioctl TIOCSWINSZ) | Yes |

**Why direct PTY fd wins for interactive use:**

The direct PTY approach (`pty.fork()` + `select.select()` or `asyncio.add_reader()`) keeps the file descriptor open in the Flask process. I/O is a non-blocking read/write on the fd — no subprocess spawning, no serialization, no diffing. This is exactly how terminado (Jupyter), pyxtermjs, ttyd, and every production web terminal works.

```python
# Direct PTY I/O loop (simplified)
import pty, os, select

pid, fd = pty.fork()
if pid == 0:
    os.execvp("/bin/bash", ["/bin/bash"])

# Parent: shuttle bytes between WebSocket and PTY fd
while True:
    readable, _, _ = select.select([fd, ws_fd], [], [], 0.01)
    if fd in readable:
        data = os.read(fd, 4096)   # <1ms
        ws.send(data)              # <1ms
    if ws_fd in readable:
        data = ws.recv()
        os.write(fd, data)         # <1ms
```

**Total round-trip: 2-4ms.** Compare to 50-300ms for CLI polling.

**The trade-off for direct PTY:**
- Flask owns the PTY lifecycle — restart Flask = kill all native sessions
- Native sessions are Flask-internal — not automatically managed by TermLink
- Requires `termlink register` to make them visible to CLI users

**Scaling projection (hybrid: 5 native + 10 bridged at 200ms):**

| Resource | Usage | Budget |
|----------|-------|--------|
| CPU (one core) | 0.5% (native) + 5% (bridged) = ~5.5% | Plenty |
| Memory | 10MB (native) + 10MB (bridged) = ~20MB | Plenty |
| File descriptors | 10 (PTY) + 10 (WS) + 10 (misc) = ~30 | Default limit: 1024 |
| Threads | 5 (native WS) + 10 (bridged WS) + 2 (bg) = ~17 | Plenty |
| Process spawns/s | 0 (native) + 50 (bridged) = ~50 | Manageable |

---

## 2. Architecture: Hybrid (Recommended)

### 2.1 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Browser                                                     │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐               │
│  │ xterm.js  │  │ xterm.js  │  │ xterm.js  │               │
│  │ Tab 1     │  │ Tab 2     │  │ Tab 3     │               │
│  │ [SHELL]   │  │ [SHELL]   │  │ [AGENT]   │               │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘               │
│        │ws            │ws            │ws                     │
└────────┼──────────────┼──────────────┼───────────────────────┘
         │              │              │
┌────────┼──────────────┼──────────────┼───────────────────────┐
│ Flask  │              │              │                       │
│  ┌─────▼──────────────▼──────────────▼──────┐               │
│  │          WebSocket Router                 │               │
│  │    /ws/terminal/<session_id>              │               │
│  └─────┬──────────────┬──────────────┬──────┘               │
│        │              │              │                       │
│  ┌─────▼─────┐  ┌─────▼─────┐  ┌────▼──────┐              │
│  │ PTYBridge │  │ PTYBridge │  │ TLBridge  │← CLI poll    │
│  │ (native)  │  │ (native)  │  │ (bridged) │              │
│  └─────┬─────┘  └─────┬─────┘  └────┬──────┘              │
│        │fd           │fd           │subprocess             │
│  ┌─────▼─────┐  ┌─────▼─────┐      │                      │
│  │/dev/pts/1 │  │/dev/pts/2 │      │                      │
│  │  (bash)   │  │ (python)  │      │                      │
│  └───────────┘  └───────────┘      │                      │
│        │              │              │                      │
│  ┌─────▼──────────────▼──────────────▼──────┐              │
│  │       Session Registry                    │              │
│  │  Merges native sessions + TermLink list   │              │
│  └───────────────────────────────────────────┘              │
└──────────────────────────┬───────────────────────────────────┘
                           │ termlink register / list / pty output / pty inject
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ TermLink Registry                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ web-shell-1  │  │ web-shell-2  │  │ claude-worker-962 │  │
│  │ source:web   │  │ source:web   │  │ role:worker       │  │
│  │ registered   │  │ registered   │  │ task:T-962        │  │
│  └──────────────┘  └──────────────┘  └───────────────────┘  │
│  All sessions visible via `termlink list`                    │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Two Bridge Modes

| | PTYBridge (native) | TLBridge (bridged) |
|-|--------------------|--------------------|
| **Created by** | "New Terminal" from browser | "Connect" to TermLink session |
| **PTY owned by** | Flask process | TermLink / external process |
| **I/O method** | Direct fd read/write via select | `pty output` polling + `pty inject` |
| **Input latency** | <5ms | 16-50ms (batch + subprocess) |
| **Output latency** | <5ms | 100-200ms (poll interval) |
| **Resize** | Yes (ioctl TIOCSWINSZ) | No (TermLink lacks resize cmd) |
| **ncurses/vim** | Full support | Not recommended |
| **Kill behavior** | SIGHUP child | Stop polling (never kills external) |
| **TermLink visible** | Yes (registered) | Already registered |
| **CLI attach** | Via TermLink (if registered) | Already possible |
| **Max concurrent** | 5 | 20 |
| **UI badge** | `SHELL` (interactive) | `AGENT` / `TASK` (monitor) |

### 2.3 Component Responsibilities

| Component | File | Responsibility |
|-----------|------|---------------|
| **Terminal Blueprint** | `web/blueprints/terminal.py` | HTTP routes (list, spawn, kill) + WebSocket endpoint |
| **TerminalManager** | `web/terminal_manager.py` | Session registry, spawn/kill lifecycle, TermLink sync |
| **PTYBridge** | `web/bridges.py` | Direct fd I/O for native sessions |
| **TLBridge** | `web/bridges.py` | CLI polling for bridged sessions |
| **xterm.js client** | `web/static/js/terminal.js` | Terminal rendering, keyboard capture, WS client |
| **Terminal page** | `web/templates/terminal.html` | Tab bar, session list, terminal containers |

### 2.4 Data Flow: Native Session (Full Interactive)

```
1. User clicks "New Terminal"
   Browser: POST /api/terminal/spawn {"name":"shell-1","cols":120,"rows":30}

2. Flask TerminalManager.create_session():
   a. pid, fd = pty.fork()
      child: exec("/bin/bash"), env TERM=xterm-256color, cwd=PROJECT_ROOT
   b. os.set_blocking(fd, False)  # non-blocking for select loop
   c. Register: termlink register --shell --name web-shell-1 \
                  --tags "source:watchtower,task:T-962"
   d. sessions["web-shell-1"] = NativeSession(fd=fd, pid=pid, state=SPAWNED)
   e. Return: {"session_id":"web-shell-1","ws_url":"/ws/terminal/web-shell-1"}

3. Browser opens WebSocket to /ws/terminal/web-shell-1
   Flask: sessions["web-shell-1"].state = CONNECTED, assigns ws connection

4. I/O loop (in WebSocket handler thread):
   while session.state == CONNECTED:
     readable, _, _ = select.select([fd, ws.fileno()], [], [], 0.05)
     if fd in readable:
       data = os.read(fd, 4096)
       ws.send(json.dumps({"type":"output","data":base64.b64encode(data).decode()}))
     if ws.fileno() in readable:
       msg = json.loads(ws.receive())
       if msg["type"] == "input":
         os.write(fd, msg["data"].encode())
       elif msg["type"] == "resize":
         struct.pack_into('HHHH', winsize, 0, msg["rows"], msg["cols"], 0, 0)
         fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)

5. End-to-end latency: <5ms (verified by terminado/ttyd benchmarks)
```

### 2.5 Data Flow: Bridged Session (Observation)

```
1. Session list shows TermLink session "claude-worker-T962"
   User clicks "Connect" (eye icon)

2. Flask TerminalManager.bridge_session("claude-worker-T962"):
   a. Verify: termlink list --json → find session, check PID alive
   b. Fetch initial buffer: termlink pty output claude-worker-T962 --lines 500
   c. sessions["claude-worker-T962"] = BridgedSession(state=BRIDGING, poll_ms=200)
   d. Return: {"session_id":"claude-worker-T962","ws_url":"/ws/terminal/claude-worker-T962","mode":"bridge"}

3. Browser opens WebSocket
   Flask: send initial buffer, state = CONNECTED

4. Poll loop (in WebSocket handler thread):
   while session.state == CONNECTED:
     # Output: poll TermLink
     raw = subprocess.run(
       ["termlink","pty","output","claude-worker-T962","--lines","100"],
       capture_output=True, timeout=5
     ).stdout
     if raw != session.last_raw:
       delta = compute_delta(session.last_raw, raw)
       ws.send(json.dumps({"type":"output","data":base64.b64encode(delta).decode()}))
       session.last_raw = raw
     
     # Input: drain queue, batch inject
     if session.input_queue:
       batch = session.input_queue.drain()
       subprocess.run(
         ["termlink","pty","inject","claude-worker-T962",batch],
         timeout=5
       )
     
     # Adaptive sleep
     sleep(0.1 if session.recently_active else 0.5)

5. End-to-end latency: 100-300ms output, 16-50ms input
```

### 2.6 WebSocket Message Protocol

All messages JSON-encoded. Binary PTY data base64-encoded within JSON for uniformity and debuggability.

**Protocol version:** Included in server hello message. Current: `1`.

#### Client → Server

```jsonc
// Terminal input (keystrokes, paste)
// data: raw bytes from xterm.js onData(), UTF-8 encoded
// xterm.js handles keyboard → ANSI translation (Ctrl+C → \x03, arrows → \x1b[A, etc.)
{"type": "input", "data": "ls -la\r"}

// Terminal resize (from xterm.js fit addon)
{"type": "resize", "cols": 120, "rows": 30}

// Keepalive ping
{"type": "ping", "ts": 1712434800}

// Graceful detach (browser tab closing — don't kill session)
{"type": "detach"}

// Kill session (explicit user action)
{"type": "kill"}
```

#### Server → Client

```jsonc
// Hello (first message after WS connect)
{"type": "hello", "protocol": 1, "session_id": "web-shell-1",
 "mode": "native", "pid": 12345, "shell": "/bin/bash"}

// Terminal output (raw PTY bytes, base64-encoded)
// xterm.js decodes and renders ANSI escape codes natively
{"type": "output", "data": "dXNlckBob3N0On4kIA=="}

// Session state change
{"type": "state", "state": "connected"}
{"type": "state", "state": "disconnected", "reconnect_timeout_s": 30}

// Session ended (process exited or killed)
{"type": "ended", "reason": "exit", "exit_code": 0}
{"type": "ended", "reason": "killed"}
{"type": "ended", "reason": "timeout"}

// Error
{"type": "error", "code": "SESSION_NOT_FOUND", "message": "Session does not exist"}
{"type": "error", "code": "SESSION_DEAD", "message": "Process has exited"}
{"type": "error", "code": "AUTH_FAILED", "message": "Invalid session token"}
{"type": "error", "code": "LIMIT_REACHED", "message": "Maximum 5 native sessions"}

// Keepalive pong
{"type": "pong", "ts": 1712434800, "server_ts": 1712434801}
```

#### Session List (separate endpoint, not WebSocket)

Served via htmx polling (`hx-get="/terminal/sessions" hx-trigger="every 5s"`):

```jsonc
{
  "sessions": [
    {"id": "web-shell-1", "mode": "native", "state": "connected",
     "name": "shell-1", "pid": 12345, "uptime_s": 342,
     "tags": ["source:watchtower"], "capability": "interactive"},
    {"id": "claude-worker-T962", "mode": "bridge", "state": "connected",
     "name": "claude-worker-T962", "pid": 48721, "uptime_s": 1200,
     "tags": ["task:T-962", "role:worker"], "capability": "monitor"}
  ]
}
```

### 2.7 TermLink Registration of Flask-Owned Sessions

```bash
# On session create
termlink register --shell --name "web-shell-1" \
  --pid <child_pid> \
  --tags "source:watchtower,task:T-962,type:interactive"

# On session kill/cleanup
termlink deregister --name "web-shell-1"
```

**Effect:** CLI users see browser sessions:
```bash
$ termlink list
NAME              PID    TAGS                                    AGE
web-shell-1       12345  source:watchtower,task:T-962,type:inter 5m
claude-worker-962 48721  task:T-962,role:worker                  12m
```

**Graceful degradation:** If `termlink` binary is not installed, registration is skipped. Native sessions still work — they're just invisible to CLI discovery. The terminal page shows a warning: "TermLink not found — CLI discovery disabled."

---

## 3. Flask WebSocket Integration

### 3.1 Library: flask-sock

**Why `flask-sock`:**
- Minimal: wraps `simple-websocket`, adds `@sock.route()` decorator
- Works with Flask's WSGI model (no async migration needed)
- Threaded: one thread per WS connection (acceptable for <25 concurrent terminals)
- No eventlet/gevent dependency (avoids conflicts with existing SSE streaming in `web/ask.py`)

**Not flask-socketio:** Pulls in Socket.IO protocol (unnecessary), requires eventlet or gevent worker, conflicts with Gunicorn sync workers used by Watchtower.

### 3.2 Threading Model

```
Flask Process
├── Main thread: HTTP request handlers (existing Watchtower routes)
├── SSE thread: /search/ask streaming handler (existing)
├── WS threads (one per terminal connection):
│   ├── ws-1: PTYBridge for "web-shell-1" → select(pty_fd, ws_fd) loop
│   ├── ws-2: PTYBridge for "web-shell-2" → select(pty_fd, ws_fd) loop
│   └── ws-3: TLBridge for "claude-worker-T962" → poll + sleep loop
└── Background threads:
    ├── termlink-sync: every 5s, `termlink list --json` → update registry
    └── cleanup: every 60s, detect dead sessions, kill orphan PTYs
```

### 3.3 Gunicorn Compatibility

**Current:** Watchtower runs Gunicorn with sync workers.
**Required:** `flask-sock` needs threads within the worker (Python threading, not eventlet).

```python
# gunicorn.conf.py
workers = 2          # HTTP capacity
threads = 10         # Per-worker threads (handles WS connections)
worker_class = "gthread"  # Threaded worker (not sync)
```

**Impact:** Changing from sync to gthread workers. Existing HTTP routes and SSE streaming continue to work (gthread is backward-compatible with sync behavior). WebSocket connections each hold one thread for their lifetime.

**Worker budget:** 2 workers x 10 threads = 20 threads total. With 5 native + 10 bridged terminals + HTTP requests, comfortably within budget.

### 3.4 Traefik WebSocket Proxy

Traefik supports WebSocket upgrade by default. No configuration change needed for `/ws/terminal/*` routes. The existing `deploy/traefik-routes.yml` routes all traffic to the Watchtower backend — WebSocket upgrade headers pass through automatically.

**Verification (during build):** Connect to `wss://watchtower-dev.docker.ring20.geelenandcompany.com/ws/terminal/test` and confirm upgrade succeeds.

---

## 4. Security Model

### 4.1 Threat Surface

A web terminal exposes **shell access through HTTP**. Even on LAN, this is the highest-privilege endpoint in Watchtower.

| Threat | Severity | Mitigation |
|--------|----------|------------|
| Unauthorized shell access | Critical | Same-origin WS, CSRF token, Traefik basic auth in prod |
| Session hijacking | High | Signed session tokens in WS URL (HMAC, time-limited) |
| Cross-session leakage | Medium | Separate PTY processes, no shared state between sessions |
| Resource exhaustion (fork bomb) | Medium | Max 5 native sessions, PTY ulimit, session timeout |
| Command injection via session name | Low | Regex validation: `[a-zA-Z0-9_-]{1,64}` |
| XSS via terminal output | Low | xterm.js renders in canvas/WebGL, not DOM — inherently safe |

### 4.2 WebSocket Authentication

```
1. Browser: POST /api/terminal/spawn (with CSRF token from existing middleware)
   → Response: {"session_id": "web-shell-1", "ws_token": "<signed>"}

2. ws_token = HMAC-SHA256(session_id + timestamp, app.secret_key)
   Validity: 60 seconds

3. Browser: WebSocket /ws/terminal/web-shell-1?token=<ws_token>

4. Flask: verify HMAC, check timestamp < 60s
   If invalid → close WS with code 4001 (Unauthorized)
```

No cookies in WebSocket handshake (browser limitation varies by library). Token-in-URL is standard practice (VS Code, JupyterLab, Gitpod all use this pattern).

### 4.3 Defense in Depth

- **Network:** LAN-only deployment (Traefik basic auth adds password for external access)
- **Application:** CSRF + WS token + session validation
- **Process:** Each PTY runs as Watchtower process user, inherits ulimits
- **Session:** 30s reconnect timeout, 5 concurrent session limit, orphan cleanup
- **Input:** Shell allowlist, CWD restriction, name sanitization

---

## 5. Performance Assessment Summary

### 5.1 Expected Performance

| Scenario | Keystroke RTT | Output Latency | CPU (5 sessions) | Verdict |
|----------|--------------|----------------|-------------------|---------|
| Native (typing in bash) | <5ms | <5ms | ~0.5% | Excellent |
| Native (cat large file) | N/A | <5ms per chunk | ~5% burst | Excellent |
| Native (vim session) | <5ms | <5ms | ~1% | Excellent |
| Bridged (watching agent) | N/A | 100-200ms | ~5% | Good |
| Bridged (sending command) | 16-50ms | 100-200ms echo | ~5% | Adequate |
| Bridged (interactive vim) | 100-300ms | 200-400ms | ~10% | Poor — not recommended |

### 5.2 Scaling Limits

| Bottleneck | Native limit | Bridged limit | Combined limit |
|------------|-------------|---------------|----------------|
| Threads | ~50 | ~50 | ~25+25 |
| File descriptors | ~500 | N/A | ~500 |
| CPU (subprocess spawning) | N/A | ~50/s sustainable | ~50/s |
| Memory | ~100MB (50 sessions) | ~50MB (50 sessions) | ~150MB |
| **Practical limit** | **10** | **20** | **25** |

Well within needs. Watchtower is a single-user governance dashboard, not a multi-tenant terminal service. 5 native + 5 bridged sessions is the expected peak.

### 5.3 Optimization Path (If Ever Needed)

1. **Binary WebSocket frames:** Skip base64 for native sessions → ~33% bandwidth reduction
2. **Async I/O:** Replace threads with `asyncio` → 10x connection density
3. **TermLink Unix socket:** Hypothetical streaming API → eliminates poll overhead entirely
4. **Shared poll loop:** Single thread polls all bridged sessions via multiplexed `pty output` → reduces thread count
5. **Output compression:** zlib compress PTY output before WS send → reduces bandwidth for heavy output

None needed at projected scale.

---

## 6. Multi-Session UI Design

### 6.1 Session List Panel

```
┌─ Terminal Sessions ──────────────────────────────────────────┐
│                                                              │
│  INTERACTIVE (Flask-owned)                                   │
│  ┌────────────────────────────────────────────────────┐      │
│  │ ● [SHELL] shell-1    PID 4521   2m ago      [x]   │      │
│  │ ● [SHELL] debug-3    PID 4580   30s ago     [x]   │      │
│  └────────────────────────────────────────────────────┘      │
│                                                              │
│  MONITORING (TermLink sessions)                              │
│  ┌────────────────────────────────────────────────────┐      │
│  │ ● [AGENT] claude-T962  task:T-962  5m ago   [eye]  │      │
│  │ ○ [TASK]  worker-1     task:T-963  12m ago  [eye]  │      │
│  └────────────────────────────────────────────────────┘      │
│                                                              │
│  [+ New Terminal]        TermLink: ● connected (4 sessions)  │
└──────────────────────────────────────────────────────────────┘
```

| Badge | Meaning | Color |
|-------|---------|-------|
| `SHELL` | Browser-spawned interactive terminal | Blue |
| `AGENT` | Claude Code worker session | Purple |
| `TASK` | fw termlink spawn task session | Green |
| `REMOTE` | TermLink hub remote session (future) | Orange |

| Indicator | Meaning |
|-----------|---------|
| ● (filled green) | Connected + responsive |
| ● (filled yellow) | Disconnected (reconnectable) |
| ○ (hollow) | Discovered but not attached |
| ● (filled gray) | Dead (will be cleaned up) |

### 6.2 Tab Bar Behavior

- Tabs ordered: native first, bridged second (within each group, by creation time)
- Active tab has highlighted border + bold label
- Right-click tab → Kill / Detach / Rename
- Drag tabs to reorder (stretch goal)
- Badge icon on tab shows session type at a glance
- Close button on native tabs (kills session); detach button on bridged tabs (stops watching)

### 6.3 Orchestrator Readiness

The session registry already supports heterogeneous session types via `mode` and `tags`. Future orchestrator expansion adds:
- `provider` tag (e.g., `provider:anthropic`, `provider:openai`)
- Session routing rules (which provider for which task type)
- Aggregate session view (all agents across providers)

**No architectural changes needed.** The registry is a flat list with metadata. An orchestrator is a consumer of the registry, not a structural change to it.

---

## 7. Open Questions for Inception Decision

1. **`termlink register --shell` behavior:** Does registering a Flask-owned PTY allow `pty output`/`pty inject` to work on it from CLI? If yes, bidirectional CLI↔browser interop is possible out of the box. If not, Flask-native sessions are browser-only. **Needs empirical testing.**

2. **Gunicorn gthread workers:** Does switching from sync to gthread workers affect existing SSE streaming in `/search/ask`? **Likely fine (gthread is superset of sync), but needs verification.**

3. **Flask restart resilience:** Native sessions die when Flask restarts. For v1 this is acceptable (LAN dashboard, not production terminal). Session persistence (via tmux backend) could be added later if needed.

4. **TermLink `attach` Phase 3 timeline:** If `termlink attach` lands with streaming/WebSocket support, the TLBridge could be replaced with a direct TermLink-to-browser path. Worth checking the TermLink roadmap before building a sophisticated TLBridge.

5. **Output diffing for bridged sessions:** Simple last-N-lines comparison misses mid-screen updates (vim, htop). Options: (a) always send full buffer (wasteful), (b) hash-based line diffing (complex), (c) accept that bridged sessions have imperfect rendering for full-screen apps (pragmatic). **Recommend (c) for v1.**

---

## 8. Recommendation

**GO for hybrid architecture.** All go/no-go criteria from the task are met:

| Go/No-Go Criterion | Status | Evidence |
|---------------------|--------|----------|
| Mature OSS web terminal library | **GO** | xterm.js v6.0.0, MIT, 20.2k stars, VS Code (v1 report) |
| PTY bridge latency acceptable | **GO** | Native <5ms (pty.fork); bridged 100-200ms (pty output poll) |
| TermLink attachment feasible | **GO** | `pty output`+`pty inject` for observation; native PTY for interactive |
| Multi-session without frontend rewrite | **GO** | xterm.js is framework-agnostic; tab UI is vanilla JS + htmx |
| Security manageable for LAN | **GO** | WS tokens + same-origin + CSRF + Traefik basic auth |

**Build decomposition (post-GO):**

| Phase | Task | Scope |
|-------|------|-------|
| 1 | Flask WS + single native terminal | flask-sock, pty.fork, xterm.js, one tab |
| 2 | Multi-tab + session management | Tab bar, spawn/kill API, session list |
| 3 | TermLink bridge integration | TLBridge, discovery merge, monitoring badges |
| 4 | Reconnection + lifecycle polish | 30s reconnect, orphan cleanup, adaptive polling |
| 5 | Advanced (stretch) | Split panes, session sharing, task-tagged auto-spawn |

---

## Sources

- TermLink CLI: `agents/termlink/AGENT.md`, `agents/termlink/termlink.sh`
- TermLink dispatch: `agents/dispatch/preamble.md`
- Watchtower Flask app: `web/app.py`
- Watchtower SSE streaming: `web/ask.py`
- xterm.js v6 survey: `docs/reports/T-962-v1-oss-terminals.md`
- flask-sock: PyPI package (wraps `simple-websocket`)
- Python PTY: `pty.fork()` + `os.read()`/`os.write()` (stdlib)
- terminado: Jupyter's WebSocket-to-PTY bridge (reference implementation)
- POSIX PTY: `ioctl(fd, TIOCSWINSZ, ...)` for resize, `select.select()` for non-blocking I/O
