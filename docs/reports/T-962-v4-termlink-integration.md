# T-962: TermLink-to-Browser Terminal Integration Design

**Task:** T-962 | **Date:** 2026-04-06 | **Status:** Research Complete

---

## Executive Summary

This document designs how TermLink sessions map to browser terminal tabs/panes in Watchtower. The core finding: **pure TermLink polling is adequate for monitoring but not for interactive use.** The recommended architecture is a hybrid: Flask-owned PTYs for interactive sessions (registered with TermLink for discoverability), and TermLink polling for observing existing CLI-spawned sessions.

---

## 1. Research Findings

### 1.1 TermLink PTY Primitives — Latency Profile

| Operation | Measured Latency | Notes |
|-----------|-----------------|-------|
| `pty output --lines N` | <50ms | Reads tmux capture-pane buffer |
| `pty inject <text> --enter` | <50ms | Fire-and-forget, non-blocking |
| `interact <cmd> --json` | ~200ms | Synchronous, waits for completion |
| `event emit` | <10ms | Local socket write |
| `spawn --wait` | ~2s | Shell init + registration |

**Key constraint:** `pty output` reads a snapshot of the terminal buffer. It does not stream. Polling at 50ms intervals (20 Hz) yields:
- ~20 subprocess spawns/second (fork+exec `termlink` binary each time)
- Potential for missed output between polls if content scrolls fast
- CPU overhead: non-trivial for multiple concurrent sessions

### 1.2 Watchtower Current Architecture

- **Framework:** Flask 3.x + Gunicorn (WSGI)
- **Frontend:** htmx + Pico CSS (classless), no xterm.js
- **Real-time:** SSE via `htmx-ext-sse.js` (used for RAG token streaming)
- **No WebSocket:** Flask-SocketIO not installed
- **Blueprints:** 20 registered (modular, well-structured)
- **Static JS:** htmx, d3, marked, highlight.js, purify, custom chat/search

### 1.3 Interactive Terminal Requirements

For a usable web terminal (comparable to VS Code integrated terminal):
- **Input latency:** <50ms keystroke-to-echo (human perception threshold: ~100ms)
- **Output throughput:** Handle `cat large_file` (~1MB/s scroll)
- **Bidirectional:** Simultaneous input and output
- **Terminal emulation:** ANSI escape sequences, cursor positioning, colors
- **Resize:** SIGWINCH on window resize

---

## 2. Architecture Options Evaluated

### Option A: Pure TermLink Polling

```
Browser (xterm.js) ←→ Flask ←→ termlink CLI ←→ tmux session
                   SSE/POST    subprocess      capture-pane
```

- **Output:** Flask polls `termlink pty output --lines N --strip-ansi` at 20Hz, streams delta via SSE
- **Input:** Browser POSTs keystrokes → Flask calls `termlink pty inject`
- **Pros:** All sessions managed by TermLink; consistent CLI/browser experience
- **Cons:** 20 fork+exec/sec per session; missed output; `--strip-ansi` removes formatting xterm.js needs; no cursor positioning; resize not supported

**Verdict: REJECTED for interactive use.** Polling a CLI binary cannot match direct PTY I/O. Adequate for monitoring/log-tail only.

### Option B: Direct PTY Only (No TermLink)

```
Browser (xterm.js) ←→ WebSocket ←→ Flask PTY manager ←→ /dev/pts/N
```

- Flask uses Python `pty.openpty()` to create PTY pairs
- WebSocket streams raw bytes bidirectionally
- **Pros:** Native performance, proven pattern (ttyd, wetty, Jupyter)
- **Cons:** Sessions invisible to TermLink; cannot observe from CLI; duplicates session management

**Verdict: REJECTED.** Loses TermLink's cross-terminal discoverability — the whole point of integration.

### Option C: Hybrid — Flask PTY + TermLink Registration (RECOMMENDED)

```
┌─────────────────────────────────────────────────────┐
│ Browser                                             │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐       │
│  │ xterm.js  │  │ xterm.js  │  │ xterm.js  │       │
│  │ (tab 1)   │  │ (tab 2)   │  │ (tab 3)   │       │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘       │
│        │ws            │ws            │ws             │
└────────┼──────────────┼──────────────┼───────────────┘
         │              │              │
┌────────┼──────────────┼──────────────┼───────────────┐
│ Flask  │              │              │               │
│  ┌─────▼─────────────────────────────▼─────┐        │
│  │         WebSocket Router                 │        │
│  │   /ws/terminal/<session_id>              │        │
│  └─────┬─────────────┬──────────────┬──────┘        │
│        │              │              │               │
│  ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼─────┐        │
│  │ PTY Bridge│ │ PTY Bridge│ │ TL Bridge │ ← poll  │
│  │ (owned)   │ │ (owned)   │ │ (external)│         │
│  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘        │
│        │fd           │fd            │subprocess     │
└────────┼─────────────┼──────────────┼───────────────┘
         │              │              │
   ┌─────▼─────┐ ┌─────▼─────┐ ┌─────▼──────────┐
   │ /dev/pts/1│ │ /dev/pts/2│ │ termlink       │
   │ (bash)    │ │ (python)  │ │ pty output/    │
   │           │ │           │ │ inject         │
   └───────────┘ └───────────┘ └────────────────┘
         │              │              │
         ▼              ▼              ▼
   ┌─────────────────────────────────────────┐
   │ TermLink Registry (all sessions visible)│
   │  - Flask-owned: registered via API      │
   │  - CLI-spawned: already registered      │
   └─────────────────────────────────────────┘
```

**Two bridge types:**

| Bridge Type | Use Case | I/O Method | Latency |
|-------------|----------|------------|---------|
| **PTY Bridge** (owned) | New sessions from browser | Direct fd read/write | <5ms |
| **TL Bridge** (external) | Observe CLI-spawned sessions | `pty output` polling | ~100ms |

**Pros:**
- Interactive sessions get native PTY performance
- All sessions (browser + CLI) visible in TermLink registry
- CLI users can `termlink attach` browser-spawned sessions
- Browser can observe CLI-spawned sessions (monitoring mode)

**Cons:**
- Two I/O paths (complexity)
- Requires WebSocket addition to Flask stack

**Verdict: RECOMMENDED.** Best of both worlds.

---

## 3. Detailed Design

### 3.1 New Dependencies

```
# web/requirements.txt additions
flask-sock>=0.7          # WebSocket support (thin wrapper over werkzeug)
```

**Why flask-sock over flask-socketio:** flask-sock is minimal (WebSocket only, no Socket.IO protocol overhead), works with Gunicorn+gevent, and we only need raw bidirectional bytes for terminal I/O. Socket.IO's event system is unnecessary here.

**Frontend:**
```
# web/static/ additions
xterm.min.js             # Terminal emulator
xterm.css                # Terminal styles
xterm-addon-fit.min.js   # Auto-resize addon
xterm-addon-web-links.js # Clickable URLs (optional)
```

### 3.2 WebSocket Message Protocol

All messages are JSON over WebSocket at `/ws/terminal/<session_id>`.

**Client → Server:**

```jsonc
// Keystroke input (most frequent — optimized)
{"type": "input", "data": "ls -la\r"}

// Resize terminal
{"type": "resize", "cols": 120, "rows": 40}

// Request session info
{"type": "ping"}
```

**Server → Client:**

```jsonc
// Terminal output (raw bytes, base64-encoded for binary safety)
{"type": "output", "data": "dXNlckBob3N0On4kIA=="}

// Session metadata (on connect + on change)
{"type": "session", "id": "web-T962-1", "name": "bash", "pid": 12345,
 "mode": "owned", "termlink_registered": true}

// Heartbeat response
{"type": "pong", "uptime_s": 342}

// Error
{"type": "error", "message": "Session terminated", "code": "SESSION_DEAD"}
```

**For TL Bridge (monitoring) sessions, input is relayed via:**
```jsonc
// Same client message
{"type": "input", "data": "ls\r"}
// Server translates to: termlink pty inject <session> "ls" --enter
```

### 3.3 Component Responsibilities

#### `web/blueprints/terminal.py` — Terminal Blueprint

```
Routes:
  GET  /terminal                    → Terminal page (tab container)
  GET  /terminal/sessions           → htmx partial: session list
  POST /terminal/sessions/create    → Spawn new session, return session_id
  POST /terminal/sessions/<id>/kill → Kill session
  WS   /ws/terminal/<session_id>    → WebSocket for terminal I/O
```

Responsibilities:
- Session lifecycle management (create, kill, list)
- WebSocket connection handling
- Bridge selection (PTY vs TL) based on session type
- TermLink registration of owned sessions

#### `web/terminal_manager.py` — Session Manager

```python
class TerminalManager:
    """Manages terminal sessions — both Flask-owned and TermLink-external."""

    sessions: dict[str, TerminalSession]  # Active sessions

    def create_session(self, name, shell="/bin/bash", cols=120, rows=40,
                       env=None, cwd=None, tags=None) -> str:
        """Spawn PTY, register with TermLink, return session_id."""

    def attach_termlink_session(self, tl_session_name) -> str:
        """Create TL Bridge for existing TermLink session."""

    def list_sessions(self) -> list[dict]:
        """Merge Flask-owned + TermLink-discovered sessions."""

    def kill_session(self, session_id):
        """Kill PTY, deregister from TermLink, cleanup."""

    def get_bridge(self, session_id) -> PTYBridge | TLBridge:
        """Get I/O bridge for session."""
```

#### `web/bridges.py` — I/O Bridges

```python
class PTYBridge:
    """Direct PTY file descriptor I/O for Flask-owned sessions."""
    fd: int                    # PTY master fd
    pid: int                   # Child process PID

    async def read(self) -> bytes:
        """Non-blocking read from PTY fd (select/epoll)."""

    def write(self, data: bytes):
        """Write to PTY fd (keystrokes)."""

    def resize(self, cols: int, rows: int):
        """Send SIGWINCH + ioctl TIOCSWINSZ."""


class TLBridge:
    """TermLink CLI polling for external sessions."""
    session_name: str
    poll_interval: float = 0.1  # 100ms
    last_line_count: int = 0

    async def read(self) -> bytes:
        """Poll termlink pty output, return delta."""

    def write(self, data: bytes):
        """Call termlink pty inject."""

    def resize(self, cols: int, rows: int):
        """Not supported for TL sessions (logged, ignored)."""
```

### 3.4 Session Lifecycle State Machine

```
                    ┌──────────────────────────────────────────┐
                    │                                          │
                    ▼                                          │
    ┌──────────┐  spawn  ┌──────────┐  ws_connect  ┌─────────┴──┐
    │          │────────→│          │─────────────→│             │
    │  INIT    │         │ READY    │              │  CONNECTED  │
    │          │         │          │←─────────────│             │
    └──────────┘         └────┬─────┘  ws_close    └──────┬──────┘
                              │                           │
                              │ timeout (no connect       │ kill / exit
                              │ within 30s)               │
                              ▼                           ▼
                         ┌──────────┐              ┌──────────┐
                         │          │              │          │
                         │ EXPIRED  │              │  DEAD    │
                         │          │              │          │
                         └──────────┘              └──────────┘
                              │                         │
                              └────────┬────────────────┘
                                       ▼
                                  ┌──────────┐
                                  │ CLEANUP  │ → deregister TermLink
                                  │          │ → close PTY fd
                                  └──────────┘

For external (TL Bridge) sessions:
    DISCOVERED → ATTACHED (browser viewing) → DETACHED (browser closed)
    External sessions are never killed by Watchtower.
```

**Reconnect behavior:** When a WebSocket closes (browser refresh, network blip), the session stays in READY for 30 seconds. If the browser reconnects within that window, the session resumes with buffered output replayed. After 30s with no reconnect, owned sessions are killed; external sessions return to DISCOVERED.

### 3.5 Session Discovery and UI Mapping

The terminal page merges two sources:

```
┌─ Session List ──────────────────────────────────────────┐
│                                                         │
│  ● My Sessions (Flask-owned)                            │
│    ┌──────────────────────────────────────────────┐     │
│    │ [bash] web-1    PID 4521   2m ago    [x]     │     │
│    │ [bash] web-2    PID 4580   30s ago   [x]     │     │
│    └──────────────────────────────────────────────┘     │
│                                                         │
│  ○ TermLink Sessions (external, read-mostly)            │
│    ┌──────────────────────────────────────────────┐     │
│    │ [tmux] worker-1   task:T-962   5m ago  [eye] │     │
│    │ [tmux] claude-fw  task:T-963  12m ago  [eye] │     │
│    └──────────────────────────────────────────────┘     │
│                                                         │
│  [+ New Session]                                        │
└─────────────────────────────────────────────────────────┘
```

- **My Sessions:** Full interactive control. [x] kills.
- **TermLink Sessions:** Monitoring mode (output only by default). [eye] icon indicates observe-only. Input can be enabled with a toggle (sends via `pty inject`), but with a confirmation ("This session was spawned from CLI. Send input?").

**Discovery merge logic:**
```python
def list_sessions():
    owned = terminal_manager.sessions  # Flask-owned
    tl_raw = json.loads(subprocess.run(
        ["termlink", "list", "--json"], capture_output=True).stdout)
    # Filter out sessions that are already owned by Flask
    tl_external = [s for s in tl_raw if s["name"] not in owned]
    return {"owned": owned, "external": tl_external}
```

### 3.6 TermLink Registration of Flask-Owned Sessions

When Flask spawns a PTY, it registers with TermLink for CLI discoverability:

```bash
# Registration (on session create)
termlink register --name "web-1" \
  --pid <child_pid> \
  --tags "source=watchtower,task=T-962,type=interactive" \
  --metadata '{"url":"/terminal?session=web-1"}'

# Deregistration (on session kill/cleanup)
termlink deregister --name "web-1"
```

This means CLI users can:
```bash
termlink list          # See browser sessions
termlink attach web-1  # Full TUI mirror of browser terminal
termlink pty output web-1 --lines 20  # Read browser terminal output
```

**Caveat:** TermLink registration requires the `termlink` binary. If not installed, Flask-owned sessions still work — they just aren't discoverable from CLI. `fw termlink check` status shown on terminal page.

### 3.7 New Session Spawning from Browser

```
POST /terminal/sessions/create
Content-Type: application/json

{
  "shell": "/bin/bash",        // default: $SHELL or /bin/bash
  "cwd": "/opt/project",      // default: framework root
  "name": "debug-1",          // optional, auto-generated if omitted
  "cols": 120,                // from xterm.js fit addon
  "rows": 40,
  "env": {                    // optional extra env vars
    "TERM": "xterm-256color"
  },
  "tags": ["task:T-962"]      // TermLink tags
}
```

**Security considerations:**
- CSRF token required (existing Watchtower CSRF middleware)
- Shell restricted to allowlist: `/bin/bash`, `/bin/zsh`, `/bin/sh`
- CWD restricted to framework root and subdirectories
- No arbitrary command injection — shell spawns clean, user types commands
- Session limit: max 5 concurrent browser sessions (matches TermLink dispatch limit)

### 3.8 xterm.js Integration

```javascript
// web/static/js/terminal.js

class TerminalTab {
  constructor(sessionId, container) {
    this.term = new Terminal({
      cursorBlink: true,
      fontSize: 14,
      fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
      theme: { background: '#1a1b26', foreground: '#c0caf5' }
    });
    this.fitAddon = new FitAddon();
    this.term.loadAddon(this.fitAddon);
    this.term.open(container);
    this.fitAddon.fit();

    // WebSocket connection
    this.ws = new WebSocket(
      `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/ws/terminal/${sessionId}`
    );

    // Output: server → terminal
    this.ws.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.type === 'output') {
        this.term.write(atob(msg.data));
      } else if (msg.type === 'session') {
        this.updateStatus(msg);
      }
    };

    // Input: terminal → server
    this.term.onData((data) => {
      this.ws.send(JSON.stringify({ type: 'input', data: data }));
    });

    // Resize: terminal → server
    new ResizeObserver(() => {
      this.fitAddon.fit();
      this.ws.send(JSON.stringify({
        type: 'resize',
        cols: this.term.cols,
        rows: this.term.rows
      }));
    }).observe(container);
  }

  // Reconnect on WebSocket close
  handleClose() {
    setTimeout(() => this.reconnect(), 1000);  // 1s backoff
  }
}
```

---

## 4. Performance Assessment

### 4.1 PTY Bridge (Flask-Owned Sessions)

| Metric | Expected | Basis |
|--------|----------|-------|
| Input latency | <5ms | Direct fd write, no subprocess |
| Output latency | <5ms | epoll/select on fd, no polling |
| Throughput | >1MB/s | Limited by WebSocket, not PTY |
| CPU per session | ~0.1% idle, ~2% active | fd monitoring, no polling |
| Memory per session | ~2MB | PTY buffers + xterm.js state |

**Assessment:** Fully adequate for interactive use. Comparable to VS Code integrated terminal.

### 4.2 TL Bridge (External TermLink Sessions)

| Metric | Expected | Basis |
|--------|----------|-------|
| Input latency | ~50ms | Subprocess spawn for `pty inject` |
| Output latency | 50-150ms | Poll interval + subprocess overhead |
| Throughput | ~100KB/s | Limited by poll frequency and capture-pane buffer |
| CPU per session | ~3% | 10 subprocess spawns/sec at 100ms polling |
| Memory per session | ~0.5MB | Minimal (no PTY state) |

**Assessment:** Adequate for monitoring and light interaction (typing commands, reading output). Not suitable for vim, htop, or fast-scrolling content. UI should indicate "monitoring mode" for TL Bridge sessions.

### 4.3 Scaling

| Sessions | PTY Bridge CPU | TL Bridge CPU | Total |
|----------|---------------|---------------|-------|
| 1 | 0.1% | 3% | 3.1% |
| 3 | 0.3% | 9% | 9.3% |
| 5 (max) | 0.5% | 15% | 15.5% |

TL Bridge sessions are the scaling bottleneck due to subprocess spawning. Mitigation: reduce poll rate to 200ms for inactive sessions (no recent input), increase to 100ms on keypress.

---

## 5. Alternatives Considered and Rejected

### 5.1 SSE + POST (No WebSocket)

Using existing SSE infrastructure for output and POST requests for input.

- **Why rejected:** POST requests add ~10-30ms HTTP overhead per keystroke. Acceptable for occasional commands but poor for interactive typing. Also, SSE is unidirectional — the POST-based input path is a workaround, not a design.
- **When to reconsider:** If WebSocket deployment proves difficult (proxy issues, Gunicorn workers).

### 5.2 tmux pipe-pane for TermLink Sessions

Instead of polling `pty output`, use `tmux pipe-pane` to stream output to a named pipe, then read the pipe from Flask.

- **Why rejected:** Requires knowing tmux session name (TermLink abstraction leak), pipe lifecycle management is fragile, and pipe-pane captures raw PTY output that may differ from what `pty output` returns.
- **When to reconsider:** If TL Bridge polling proves too slow for a specific use case.

### 5.3 TermLink Native WebSocket Server

Add WebSocket support directly to TermLink (Rust side).

- **Why rejected:** Requires upstream changes to TermLink. Adds web concerns to a CLI tool. Watchtower already has the web layer — adding another server creates port/routing complexity.
- **When to reconsider:** If TermLink grows a daemon mode (planned Phase 3/4), a native WebSocket would be natural.

---

## 6. Implementation Roadmap

### Phase 1: Single Interactive Terminal (MVP)

**Scope:** One browser terminal tab with Flask-owned PTY. No TermLink integration yet.

- Add `flask-sock` dependency
- Add `xterm.js` + `xterm-addon-fit` to static assets
- Create `web/terminal_manager.py` (PTYBridge only)
- Create `web/blueprints/terminal.py` (WebSocket route + page)
- Create `web/templates/terminal.html`
- Create `web/static/js/terminal.js`

**Validates:** WebSocket works through Gunicorn/Traefik, xterm.js renders correctly, input/output latency is acceptable.

### Phase 2: Multi-Tab + Session Management

**Scope:** Multiple browser terminal tabs, session list, create/kill.

- Tab container UI (htmx-driven tab bar)
- Session create/kill API
- Session persistence across page navigation (WebSocket stays open)
- Max 5 sessions enforced

### Phase 3: TermLink Integration

**Scope:** Discover and attach to existing TermLink sessions.

- Add TLBridge (polling-based I/O)
- Merge Flask-owned + TermLink sessions in session list
- Register Flask-owned sessions with TermLink
- "Monitoring mode" indicator for TL Bridge sessions
- Adaptive polling (100ms active, 500ms idle)

### Phase 4: Advanced Features

**Scope:** Polish and power-user features.

- Session reconnect after browser refresh (30s buffer replay)
- Split panes (multiple terminals in one view)
- Session sharing URL (read-only observer link)
- Task-tagged sessions (auto-create terminal for active task)
- TermLink event integration (highlight sessions with new events)

---

## 7. Open Questions for Inception Decision

1. **Gunicorn + WebSocket:** Flask-sock requires async workers (`geventwebsocket` or similar). Current Watchtower deployment uses sync Gunicorn workers. Need to validate worker type change doesn't affect existing SSE streaming.

2. **Traefik WebSocket proxy:** Both prod (`:5050`) and dev (`:5051`) are behind Traefik. WebSocket upgrade headers must pass through. Likely works (Traefik supports WS by default) but needs verification.

3. **Security model:** Current Watchtower has no authentication (internal network only). A web terminal is a shell — should auth be added before this feature? Or is network-level security sufficient?

4. **TermLink `register` command:** The design assumes `termlink register --name --pid --tags` exists. Need to verify this command is available in TermLink 0.9.0. If not, registration can be deferred to Phase 3.

5. **Gunicorn worker count:** Each WebSocket connection holds a worker. With 4 workers and 5 terminal sessions, other HTTP requests could be starved. May need to increase worker count or use async workers for terminal WebSocket only.

---

## 8. Decision: Recommended Architecture

**Option C (Hybrid)** with phased implementation.

**Rationale:**
- Interactive terminals need direct PTY I/O (Option A too slow, proven by latency analysis)
- TermLink discoverability is the unique value-add over generic web terminals (Option B misses this)
- Phased approach validates assumptions early (Phase 1 is a standalone MVP)
- Existing SSE infrastructure is orthogonal — kept for RAG streaming, WebSocket added for terminal

**Risk mitigation:**
- Phase 1 has zero TermLink dependency (pure Flask PTY) — works even if TermLink questions unresolved
- TL Bridge (Phase 3) is additive, not structural — can be deferred or simplified
- Max 5 sessions + CSRF + shell allowlist address security surface
