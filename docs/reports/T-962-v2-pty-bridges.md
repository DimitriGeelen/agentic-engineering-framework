# T-962: Server-Side PTY Bridge Research (v2)

**Date:** 2026-04-06
**Task:** T-962 (Inception — web terminal in Watchtower)
**Goal:** Evaluate approaches for serving interactive terminal sessions from Flask to browsers via WebSocket.

---

## Executive Summary

Five approaches were evaluated for bridging server-side PTY processes to browser-based xterm.js terminals. The **recommended path** is a hybrid: use **Flask-SocketIO** as the WebSocket transport (minimal change to existing Flask stack) with a custom PTY manager based on pyxtermjs's pattern but extended for multi-session support. For production-grade needs or if async migration is acceptable, **ttyd as a sidecar** (reverse-proxied through existing Traefik) offers the most battle-tested solution with zero Python PTY code.

| Approach | Flask Compat | Multi-Session | Maintenance | Complexity | Verdict |
|----------|-------------|---------------|-------------|------------|---------|
| terminado | None (Tornado-only) | Yes | Active (Jupyter) | High | Reject |
| pyxtermjs | Native Flask | No (single PTY) | Stale (2023) | Low | Fork/adapt |
| Flask-SocketIO + custom PTY | Native Flask | Yes (build it) | Active (SocketIO) | Medium | **Recommended** |
| websockify | Sidecar only | N/A (TCP proxy) | Active | Low | Wrong tool |
| ttyd sidecar | Via reverse proxy | Yes (native) | Active (C) | Low | **Alt recommended** |
| FastAPI/aiohttp | Requires migration | Yes | Active | High | Future option |

---

## 1. terminado

**Repo:** [jupyter/terminado](https://github.com/jupyter/terminado)
**Version:** 0.18.1 (March 2024)
**License:** BSD-2-Clause
**Downloads:** ~7.5M/week (Jupyter dependency)

### Architecture

Terminado is a Tornado WebSocket backend for xterm.js. It provides three modules:
- `terminado.management` — PTY lifecycle (spawn, resize, kill, multi-terminal)
- `terminado.websocket` — `TermSocket` handler (149 lines, subclass of `tornado.web.WebSocketHandler`)
- `terminado.uimodule` — Tornado UI template integration

### Wire Protocol

JSON arrays where the first element is the message type:

```
["setup", {}]                    # Server -> Client: connection established
["stdout", "terminal output"]    # Server -> Client: PTY output
["stdin", "user input"]          # Client -> Server: keyboard input
["set_size", rows, cols]         # Client -> Server: resize
["disconnect", 1]                # Server -> Client: PTY died
```

Supports alternative formats: MessagePack, LightPayload (reduced latency). Client can request format switch after connect.

### PTY Lifecycle

- **Spawn:** `SingleTermManager` or `UniqueTermManager` (one PTY per WebSocket)
- **Resize:** `terminal.resize_to_smallest()` — adjusts to smallest connected client
- **Kill:** Deregisters client on WebSocket close, manager handles cleanup
- **Reconnect:** `SingleTermManager` allows reconnection to existing PTY with buffered output replay

### Multi-Session

Yes — `UniqueTermManager` creates one PTY per connection. `SingleTermManager` shares one PTY across all connections (Jupyter notebook model).

### Flask Compatibility: NONE

**Hard dependency on Tornado's event loop and WebSocket handler.** `TermSocket` extends `tornado.web.WebSocketHandler`. There is no adapter pattern — you would need to run Tornado alongside Flask (separate process/port) or rewrite the WebSocket handler. This defeats the purpose.

### Verdict: REJECT for Watchtower

The protocol design is excellent and worth studying, but the Tornado coupling makes it unusable in a Flask application without running a separate server. The 7.5M downloads are entirely from Jupyter — no evidence of standalone Flask integration in the wild.

**Salvageable:** The wire protocol (JSON arrays with type prefix) and `UniqueTermManager` pattern are worth borrowing for a custom implementation.

---

## 2. pyxtermjs

**Repo:** [cs01/pyxtermjs](https://github.com/cs01/pyxtermjs)
**Version:** 0.5.0.2 (October 2022)
**Last commit:** May 2023
**License:** MIT
**Total code:** ~152 lines (app.py)

### Architecture

Flask + Flask-SocketIO + Python `pty` module. Single-file application:

1. Browser connects via SocketIO to `/pty` namespace
2. Server spawns bash via `pty.fork()`, stores `(child_pid, fd)` globally
3. Background task polls PTY fd with `select.select()` every 10ms
4. PTY output emitted as `pty-output` event
5. Browser input received as `pty-input` event, written to fd via `os.write()`

### Key Code Patterns

```python
# PTY spawn (on SocketIO connect)
(child_pid, fd) = pty.fork()
if child_pid == 0:
    subprocess.run(app.config["cmd"])

# PTY read loop (background task)
while True:
    socketio.sleep(0.01)  # 10ms poll interval
    (data_ready, _, _) = select.select([fd], [], [], 0)
    if data_ready:
        output = os.read(fd, 1024 * 20).decode(errors="ignore")
        socketio.emit("pty-output", {"output": output}, namespace="/pty")

# Resize
winsize = struct.pack("HHHH", row, col, 0, 0)
fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)
```

### SocketIO Events

| Event | Direction | Payload |
|-------|-----------|---------|
| `connect` | Client -> Server | Triggers PTY spawn |
| `pty-input` | Client -> Server | `{"input": "ls\r"}` |
| `pty-output` | Server -> Client | `{"output": "file1 file2\n"}` |
| `resize` | Client -> Server | `{"cols": 80, "rows": 24}` |
| `disconnect` | Client -> Server | (implicit) |

### Multi-Session: NO

```python
if app.config["child_pid"]:
    return  # already started, don't start another
```

Single global PTY. All connecting clients share the same terminal. No session isolation.

### Limitations

1. **Single session only** — global state, no per-client PTY
2. **No reconnection** — if WebSocket drops, PTY output is lost
3. **10ms polling** — adds up to 10ms latency on every keystroke echo
4. **No PTY cleanup** — child process not explicitly killed on disconnect
5. **No error handling** — `os.read()` can raise `OSError` when PTY dies
6. **Stale** — no updates since May 2023, 41 commits total

### Verdict: USEFUL AS REFERENCE, NOT AS DEPENDENCY

The 152-line implementation is the clearest example of the Flask-SocketIO + PTY pattern. Worth forking the pattern (not the package) and extending with:
- Per-session PTY tracking (dict keyed by SocketIO session ID)
- Proper cleanup (`os.kill(pid, SIGTERM)` on disconnect)
- Output buffering for reconnection
- Error handling around `os.read()`

---

## 3. Flask-SocketIO + Custom PTY Manager (RECOMMENDED)

**Repo:** [miguelgrinberg/Flask-SocketIO](https://github.com/miguelgrinberg/Flask-SocketIO)
**Version:** 5.x (actively maintained)
**License:** MIT

### Why This Approach

Flask-SocketIO is the standard WebSocket library for Flask. It adds bidirectional real-time communication without replacing the web framework. Combined with Python's built-in `pty` module and the pyxtermjs pattern, this gives us native Flask integration with full control over the PTY lifecycle.

### Architecture (Proposed)

```
Browser (xterm.js)
    |
    | SocketIO events (pty-input, pty-output, resize)
    |
Flask-SocketIO server
    |
    | Per-session PTY manager
    |
PTY process (bash/sh per session)
```

### What Flask-SocketIO Provides

- WebSocket transport with automatic fallback to long-polling
- Namespace support (isolate terminal events on `/terminal`)
- Room/session management (built-in per-client tracking)
- Background task support (`socketio.start_background_task()`)
- Async modes: eventlet, gevent, or threading

### What We Must Build (~200 lines estimated)

**PTY Session Manager:**
```python
class PTYSession:
    pid: int          # Child process PID
    fd: int           # Master PTY file descriptor
    cols: int         # Terminal width
    rows: int         # Terminal height
    created: float    # Timestamp
    buffer: deque     # Recent output for reconnection (ring buffer)

sessions: dict[str, PTYSession] = {}  # keyed by SocketIO sid
```

**Required handlers:**
1. `on_connect` — spawn PTY via `pty.fork()`, store in sessions dict
2. `on_pty_input` — `os.write(session.fd, data.encode())`
3. `on_resize` — `fcntl.ioctl(session.fd, TIOCSWINSZ, struct.pack(...))`
4. `on_disconnect` — `os.kill(session.pid, SIGTERM)`, cleanup fd
5. Background reader — poll all active fds with `select.select()`, emit per-session

**Key design decisions:**
- One background task polling ALL fds (not one thread per PTY) — scales better
- Ring buffer (e.g., last 4KB) per session for reconnection replay
- `SIGCHLD` handler to detect dead PTYs and notify clients
- Configurable shell command (default: `$SHELL` or `/bin/bash`)

### Async Mode Considerations

| Mode | WebSocket | PTY compat | Notes |
|------|-----------|------------|-------|
| threading | Via Werkzeug | Good | Simplest, `select()` works natively |
| eventlet | Native | Needs monkey-patching | `eventlet.monkey_patch()` wraps `select` |
| gevent | Native | Needs monkey-patching | Similar to eventlet |

**Recommendation:** Start with **threading** mode for simplicity. Eventlet/gevent add complexity and can interfere with `pty.fork()` and `os.read()`. Threading mode supports real WebSockets (not just long-polling) when paired with `simple-websocket` package.

### Integration with Watchtower

```python
# In watchtower app factory or blueprint
from flask_socketio import SocketIO

socketio = SocketIO(app, async_mode='threading')

# Terminal blueprint
from watchtower.terminal import register_terminal_handlers
register_terminal_handlers(socketio)

# Run with SocketIO instead of bare Flask
socketio.run(app, host='0.0.0.0', port=3000)
```

**Breaking change:** `app.run()` must become `socketio.run()`. This is the main integration cost — all existing HTTP routes continue to work, but the server entry point changes.

### Dependencies Added

```
flask-socketio>=5.3
simple-websocket>=1.0  # For threading mode WebSocket support
```

Both are pure Python, no C extensions needed. Total additional dependency footprint: ~3 packages.

### Latency Characteristics

- **Input:** Client -> SocketIO -> `os.write()` — near-instant (<1ms)
- **Output:** PTY -> `select()` poll (configurable, 10ms default) -> SocketIO emit — 0-10ms
- **Optimization:** Use `eventlet`/`gevent` for event-driven reads instead of polling (eliminates the 10ms)
- **Practical:** 10ms is imperceptible for terminal use. Vim, htop, etc. work fine.

### Verdict: RECOMMENDED PATH

Lowest integration cost with existing Flask stack. ~200 lines of custom code. Well-maintained transport layer (Flask-SocketIO). Full control over PTY lifecycle. Multi-session by design.

---

## 4. websockify

**Repo:** [novnc/websockify](https://github.com/novnc/websockify)
**Version:** 0.13.0 (February 2025)
**License:** LGPL-3.0

### Architecture

WebSocket-to-TCP proxy. Accepts WebSocket connections from browsers, translates to raw TCP, and forwards to a target host:port. Primary use case: noVNC (browser VNC client).

### Program Wrapping

Can launch a local program and proxy to it via `--wrap-mode`:
```bash
websockify 8080 -- ./my_program --port 5000
```
Uses `LD_PRELOAD` with `rebind.so` to intercept `bind()` calls and redirect to localhost.

### Why It Doesn't Fit

1. **TCP-oriented** — bridges WebSocket to TCP sockets, not to PTY file descriptors
2. **Binary-only protocol** — since v0.5.0, only HyBi/IETF 6455 binary frames
3. **No PTY awareness** — no resize, no signal handling, no terminal lifecycle
4. **External process** — runs as standalone proxy, not embeddable in Flask
5. **xterm.js incompatibility** — xterm.js `attach` addon expects text frames for terminal data; websockify sends binary

### Verdict: WRONG TOOL

Websockify solves WebSocket-to-TCP bridging (VNC, telnet). It has no concept of PTY terminals. You'd need a separate program that listens on a TCP port and bridges to a PTY, then websockify in front of that — adding unnecessary indirection. The `attach` addon protocol mismatch makes it even worse.

---

## 5. ttyd (Sidecar Approach — ALTERNATIVE RECOMMENDED)

**Repo:** [tsl0922/ttyd](https://github.com/tsl0922/ttyd)
**Binary:** C implementation, ~2MB
**License:** MIT

### Architecture

Standalone web terminal server. C binary using libwebsockets + libuv + xterm.js:

```
Browser (xterm.js, bundled)
    |
    | Native WebSocket
    |
ttyd (C binary, port 7681)
    |
    | PTY via forkpty()
    |
Shell process
```

### Why Consider It

- **Battle-tested:** Used in production by thousands of projects
- **Multi-session native:** Each WebSocket connection gets its own PTY
- **Full terminal support:** Resize, colors, 256-color, true-color, Unicode, CJK
- **Authentication:** Basic auth, OAuth2 (via headers)
- **Read-only mode:** Viewers can watch without typing
- **Minimal resource usage:** C binary, ~5MB RSS per session
- **Reverse proxy friendly:** Works behind Nginx, Traefik, Caddy

### Integration Pattern

```
Browser
    |
    |-- /terminal/* --> ttyd (port 7681)  [via Traefik]
    |-- /*          --> Watchtower Flask (port 5050)  [via Traefik]
```

Watchtower embeds ttyd in an iframe or loads xterm.js pointing at the ttyd WebSocket endpoint. No Python PTY code needed.

**Traefik route (addition to existing config):**
```yaml
- rule: "Host(`watchtower.example.com`) && PathPrefix(`/terminal`)"
  service: ttyd
  middlewares:
    - strip-terminal-prefix
```

### Multi-Terminal Support

Start multiple ttyd instances on different ports, or use ttyd's built-in multi-client support (each connection gets a new PTY).

### Limitations

1. **Separate process** — not in-process with Flask, needs process management
2. **Less control** — PTY lifecycle managed by ttyd, not by Watchtower
3. **Session correlation** — harder to associate terminal sessions with Watchtower concepts (tasks, agents)
4. **Authentication sync** — if Watchtower adds auth, must sync with ttyd
5. **Installation** — requires C binary (apt/brew/docker, not pip)

### Verdict: BEST FOR PRODUCTION, IF INTEGRATION DEPTH IS LOW

If the terminal is primarily a "view" that shows output (like watching a build log or agent session), ttyd is the right choice — zero PTY code, battle-tested, low maintenance. If the terminal needs deep integration with Watchtower state (auto-connecting to specific PTYs, session management via Watchtower API, custom keybindings), the Flask-SocketIO approach gives more control.

---

## 6. FastAPI / aiohttp (Async Frameworks)

### FastAPI + WebSocket

**Reference impl:** [abhishekkrthakur/webterm](https://github.com/abhishekkrthakur/webterm)

WebTerm shows the FastAPI pattern:
- `GET /ws/terminal` WebSocket endpoint
- JSON messages: `{"type": "input|output|resize|stats", ...}`
- PTY manager with session tracking (`WEBTERM_MAX_SESSIONS=10`)
- Session timeout support (`WEBTERM_SESSION_TIMEOUT=3600`)
- ~200 lines of Python for the terminal server

**Advantages over Flask:**
- Native `async/await` — no polling loop needed, use `asyncio.get_event_loop().add_reader(fd, callback)`
- Native WebSocket support (no extra package)
- Better performance under concurrent connections
- Built-in JSON schema validation

**Disadvantages:**
- Requires migrating from Flask to FastAPI (or running both)
- Different template engine (Jinja2 works but needs config)
- Different extension ecosystem (no Flask-Login, Flask-Caching, etc.)

### aiohttp

Similar to FastAPI but lower-level. The `aiohttp.web.WebSocketResponse` can bridge PTY output using the same `add_reader` pattern. Less boilerplate than FastAPI but also less structure.

### Verdict: NOT NOW, MAYBE LATER

Migrating Watchtower from Flask to FastAPI is a separate architectural decision. If that migration happens, the WebSocket terminal becomes trivially easy. But doing it just for the terminal feature is overkill.

---

## Comparison Matrix

| Feature | terminado | pyxtermjs | Flask-SocketIO+PTY | websockify | ttyd sidecar | FastAPI |
|---------|-----------|-----------|-------------------|------------|-------------|---------|
| Flask native | No | Yes | Yes | No | No (proxy) | No |
| Multi-session | Yes | No | Yes (build) | N/A | Yes | Yes |
| Resize | Yes | Yes | Yes (build) | No | Yes | Yes |
| Reconnection | Yes (buffer) | No | Yes (build) | No | No | Possible |
| Dependencies | tornado | flask-socketio | flask-socketio | standalone | C binary | uvicorn |
| Code to write | 0 (but can't use) | ~50 (patch) | ~200 | 0 | 0 | ~150 |
| Maintained | Active | Stale | Active | Active | Active | Active |
| Protocol | JSON arrays | SocketIO events | SocketIO events | Binary TCP | Custom binary | JSON WS |
| Latency | <1ms (event-driven) | ~10ms (polling) | ~10ms (polling) | <1ms | <1ms | <1ms |
| Multi-platform | Linux/macOS | Linux/macOS | Linux/macOS | Linux/macOS | All | Linux/macOS |

---

## Recommendation

### Primary: Flask-SocketIO + Custom PTY Manager

**Why:** Minimum disruption to existing Watchtower stack. Flask-SocketIO adds WebSocket to Flask with 2 lines of setup. The PTY bridge is ~200 lines following the pyxtermjs pattern. Full control over session lifecycle, resize, cleanup. Can correlate terminal sessions with Watchtower task/agent state.

**Effort estimate:** ~200 lines Python (PTY manager) + ~50 lines JavaScript (xterm.js setup) + ~20 lines template.

**Risk:** Threading mode has lower WebSocket throughput than eventlet/gevent. Acceptable for terminal use (low bandwidth). If scaling becomes an issue, switch async mode later without changing application code.

### Alternative: ttyd Sidecar

**When to prefer:** If the terminal is view-only (watching output), if there's no need to correlate sessions with Watchtower state, or if time-to-working is critical (ttyd works out of the box).

**Effort estimate:** `apt install ttyd`, one Traefik route, one iframe in template.

### Do NOT Use

- **terminado** — Tornado lock-in, no Flask path
- **websockify** — TCP proxy, wrong abstraction layer
- **Full framework migration** (FastAPI/aiohttp) — disproportionate to the feature

---

## Key Implementation Notes

### xterm.js Client Setup

For Flask-SocketIO approach, use xterm.js with Socket.IO directly (NOT the `attach` addon, which expects raw WebSocket):

```javascript
const term = new Terminal();
const socket = io('/terminal');

term.onData(data => socket.emit('pty-input', {input: data}));
term.onResize(size => socket.emit('resize', {cols: size.cols, rows: size.rows}));
socket.on('pty-output', data => term.write(data.output));
```

For ttyd sidecar, xterm.js is bundled — no client code needed.

### PTY Gotchas (Python)

1. **`pty.fork()` vs `pty.openpty()`:** Use `pty.fork()` — it forks and sets up the slave as the child's controlling terminal. `openpty()` just creates the pair without forking.
2. **`os.read()` after child dies:** Raises `OSError` — always wrap in try/except.
3. **`SIGCHLD` handling:** Register handler to detect dead children and clean up sessions.
4. **File descriptor leaks:** Close master fd after child exits. Use `try/finally` or context manager.
5. **macOS vs Linux:** `pty.fork()` works on both. `TIOCSWINSZ` ioctl works on both. No platform-specific code needed for basic functionality.

### Security Considerations

- Terminal sessions execute as the server process user — never run Watchtower as root
- Consider restricting shell to specific commands (e.g., `ttyd bash -c "fw status"`)
- Rate-limit new session creation
- Set session timeout (kill idle PTYs after N minutes)
- If exposed beyond localhost, require authentication

---

## Sources

- [jupyter/terminado](https://github.com/jupyter/terminado) — Tornado terminal server
- [cs01/pyxtermjs](https://github.com/cs01/pyxtermjs) — Flask terminal proof of concept
- [Flask-SocketIO docs](https://flask-socketio.readthedocs.io/) — WebSocket for Flask
- [novnc/websockify](https://github.com/novnc/websockify) — WebSocket-to-TCP proxy
- [tsl0922/ttyd](https://github.com/tsl0922/ttyd) — C web terminal server
- [abhishekkrthakur/webterm](https://github.com/abhishekkrthakur/webterm) — FastAPI terminal
- [terminado PyPI](https://pypi.org/project/terminado/) — Package metadata
- [xterm.js attach addon](https://github.com/xtermjs/xterm.js/tree/master/addons/addon-attach) — Client-side WebSocket attach
- [Flask-SocketIO PTY gist](https://gist.github.com/phoemur/461c97aa5af5c785062b7b4db8ca79cd) — Basic webshell example
- [xtermjs/xterm.js](https://github.com/xtermjs/xterm.js/) — Terminal emulator for the web
