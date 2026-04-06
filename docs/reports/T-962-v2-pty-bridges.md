# T-962: Server-Side PTY Bridge Libraries — Deep Analysis

**Task:** T-962 (Inception — web terminal in Watchtower)
**Date:** 2026-04-06
**Version:** v2 (supersedes skeleton)
**Purpose:** Evaluate server-side PTY bridge approaches for connecting xterm.js to real shell sessions in Watchtower
**Prerequisite:** v1 report selected xterm.js as frontend. This report evaluates the backend: PTY-to-browser bridging.

---

## Executive Summary

**Flask-SocketIO with `pty.fork()` in threading mode is the simplest viable path.** It requires no architectural changes to Watchtower (stays WSGI/Flask), supports multi-session via Socket.IO rooms keyed by `request.sid`, and the core bridging logic is ~80 lines of Python. Terminado has the best PTY management code but its hard Tornado dependency makes Flask integration impractical. pyxtermjs is abandoned but serves as a clear reference implementation. websockify solves the wrong problem (TCP proxy, not PTY bridge). FastAPI/aiohttp offer superior async performance via `loop.add_reader()` but require WSGI-to-ASGI migration.

**Key decision:** Start with Flask-SocketIO + threading. If scale demands it later (>50 concurrent terminals), migrate the WebSocket layer to FastAPI mounted as the outer app with Flask via `WSGIMiddleware`.

| Approach | Flask Compat | Multi-Session | Maintenance | LOC to Write | Verdict |
|----------|-------------|---------------|-------------|--------------|---------|
| Terminado | None (Tornado) | Yes (3 managers) | Maintenance mode | ~200 (reimpl protocol) | Reject (borrow patterns) |
| pyxtermjs | Native | No (single PTY) | Abandoned | ~120 (refactor) | Reference only |
| Flask-SocketIO + custom PTY | Drop-in | Yes (rooms/SID) | Active | ~80 | **Recommended** |
| websockify | Separate server | N/A (TCP proxy) | Active | N/A | Wrong tool |
| FastAPI/aiohttp | Requires ASGI migration | Yes (manual) | Active | ~60 + migration | Phase 2 option |

---

## 1. Terminado

| Attribute | Value |
|-----------|-------|
| Version | 0.18.1 (March 2024) |
| Python | >= 3.8 |
| License | BSD-2-Clause |
| Maintainer | Project Jupyter |
| GitHub stars | 375 |
| PyPI downloads | ~7.5M/week (Jupyter dependency) |
| Last commit | March 2024 (>2 years ago) |
| Dependencies | `tornado >= 6.1.0`, `ptyprocess` (Linux/macOS), `pywinpty` (Windows) |
| Status | **Maintenance mode** — stable but not evolving |

### Architecture

Three modules:

- **`management.py`** -- PTY process lifecycle (spawn, read, resize, kill). Uses Tornado's `IOLoop.add_handler()` for fd polling. Reads up to 64KB per 100ms cycle.
- **`websocket.py`** -- `TermSocket(tornado.websocket.WebSocketHandler)` bridges WebSocket to PTY manager. ~149 lines.
- **`uimodule.py`** -- Tornado UI module for template rendering.

Data flow: `Browser (xterm.js) <--WebSocket--> TermSocket <--fd read/write--> PTY process (ptyprocess/pywinpty)`

### WebSocket Protocol

JSON arrays where index 0 is the message type:

| Direction | Format | Purpose |
|-----------|--------|---------|
| Server -> Client | `["setup", {}]` | Connection established |
| Server -> Client | `["stdout", text]` | PTY output |
| Server -> Client | `["disconnect", 1]` | Terminal died |
| Client -> Server | `["stdin", text]` | User input |
| Client -> Server | `["set_size", cols, rows]` | Resize request |

stdin writes are dispatched to a thread executor to avoid blocking the event loop.

### PTY Lifecycle

- **Spawn:** `PtyProcessUnicode.spawn(argv, env, cwd)` via `ptyprocess` on POSIX, `pywinpty` on Windows. Non-UTF-8 output handled with replacement characters.
- **Read:** Polls PTY fd via Tornado's `IOLoop`, 100ms timeout, 64KB read buffer. Distributes output to all connected clients on that terminal.
- **Resize:** `resize_to_smallest()` -- syncs terminal dimensions to the smallest connected client via `setwinsize()/getwinsize()`. No per-client sizing.
- **Kill:** Graceful signal escalation: `SIGHUP -> SIGCONT -> SIGINT -> SIGTERM -> SIGKILL` with `delayafterterminate` sleep between each. Windows uses `SIGINT -> SIGTERM`.
- **Reconnect:** Deque buffer (maxlen=1000) stores historical output. On reconnect, buffered output drains to new client, providing session continuity.

### Multi-Session Support

Three manager classes:

| Manager | Sessions | Disconnect behavior | Use case |
|---------|----------|---------------------|----------|
| `SingleTermManager` | 1 shared | Terminal persists | Shared demo terminal |
| `UniqueTermManager` | 1 per connection | SIGHUP kills PTY | Isolated per-user terminals |
| `NamedTermManager` | N named, persistent | Terminal persists by name | Jupyter-style named terminals |

`NamedTermManager` supports auto-numbering, explicit `kill(name)`/`terminate(name)`, and multiple clients viewing the same named terminal simultaneously. This is what Jupyter uses.

Jupyter's integration pattern registers four route types:
```
/terminals/(\w+)            -> HTML page
/terminals/websocket/(\w+)  -> WebSocket (TermSocket)
/api/terminals              -> REST: list/create
/api/terminals/(\w+)        -> REST: get/delete
```

### Flask Integration: IMPRACTICAL

**Hard coupling to Tornado.** Options and their costs:

1. **Separate port** -- Tornado on :3001, Flask on :3000. Reverse proxy routes `/ws/terminal` to Tornado. Works but doubles process management, deployment complexity, and health checking.
2. **WSGIContainer** -- Wrap Flask inside Tornado via `tornado.wsgi.WSGIContainer`. Serves both from one process but ties deployment to Tornado's event loop. Incompatible with gunicorn/uwsgi.
3. **Reimplement protocol** -- The WebSocket protocol is 5 message types (trivial). The `management.py` Tornado coupling is limited to `IOLoop.add_handler()` for fd polling -- replaceable with `asyncio.loop.add_reader()`. This is feasible but you're essentially writing your own library.
4. **flask-terminado** -- Exists (github.com/nathanielobrown/flask-terminado) but abandoned: last commit April 2017, 6 total commits. Replaces Flask's WSGI server with Tornado -- can't use gunicorn/uwsgi/waitress.

**Key insight:** The protocol is trivial to reimplement. Terminado's value is the PTY management logic (spawn, resize, graceful kill, reconnect buffering), not the WebSocket handler. The management patterns are worth borrowing.

### Known Issues

- Python 3.14 build failure (#243, Feb 2025, no response)
- No flow control mechanism for stdout floods (#162)
- `resize_to_smallest` forces all clients to smallest viewport -- no per-client sizing
- No authentication, rate limiting, or backpressure
- No idle connection timeout by default (#56)

### Verdict: REJECT for Direct Use, BORROW Patterns

The Tornado dependency makes direct Flask integration impractical without running a separate server. However, three patterns are worth extracting:

1. **Graceful kill escalation** (SIGHUP -> SIGCONT -> SIGINT -> SIGTERM -> SIGKILL)
2. **Reconnect buffer** (deque maxlen for output replay)
3. **NamedTermManager concept** (persistent named sessions with multi-client viewing)

---

## 2. pyxtermjs

| Attribute | Value |
|-----------|-------|
| Version | 0.5.0.2 (October 2022) |
| Python | >= 3.6 (classifiers list 3.6, 3.7 only) |
| License | MIT |
| Author | Chad Smith (cs01, also created pipx and gdbgui) |
| GitHub stars | ~395 |
| Total commits | 41 |
| Dependent packages | 0 on PyPI |
| Status | **Abandoned** -- no activity for 3+ years |

### Architecture

Single Flask app (~120 lines in `app.py`):

```
Browser (xterm.js 4.11.0 + socket.io 4.0.1)
    |  Socket.IO (/pty namespace)
    v
Flask 2.0.1 + Flask-SocketIO 5.1.1
    |  pty.fork() + os.read/os.write
    v
PTY process (bash)
```

Parent stores fd in `app.config["fd"]` (global). A background thread polls the fd via `select.select()` every 10ms, reads up to 20KB chunks, and emits `pty-output` events to all connected Socket.IO clients.

### Protocol

Three Socket.IO events on `/pty` namespace:

| Event | Direction | Payload | Handler |
|-------|-----------|---------|---------|
| `pty-input` | client -> server | `{input: string}` | `os.write(fd, data)` |
| `pty-output` | server -> client | `{output: string}` | `term.write(data)` |
| `resize` | client -> server | `{cols: int, rows: int}` | `fcntl.ioctl(fd, TIOCSWINSZ, ...)` |

No custom framing. Raw terminal data over Socket.IO JSON messages.

### PTY Lifecycle

- **Spawn:** `pty.fork()` on first Socket.IO connect. Child runs `subprocess.run(cmd)`. Initial size set to 50x50.
- **Read:** Background thread: `select.select([fd], [], [], 0)` then `os.read(fd, 20480)`. 10ms sleep between iterations via `socketio.sleep(0.01)`.
- **Resize:** `fcntl.ioctl(fd, TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))`.
- **Kill:** **None.** No cleanup on disconnect. No SIGCHLD handling. PTY process leaks if server doesn't exit.
- **Reconnect:** **None.** Dropped WebSocket = lost output. Reconnecting shows blank terminal sharing same PTY.

### Multi-Session: NO

Single global PTY:
```python
if app.config["child_pid"]:
    return  # already started, don't start another
```

All clients share one terminal. All see the same output (broadcast). No session isolation.

### Pinned Dependencies (all 2-4 versions behind current)

| Package | Pinned | Current |
|---------|--------|---------|
| Flask | 2.0.1 | 3.1.x |
| Flask-SocketIO | 5.1.1 | 5.6.x |
| Werkzeug | 2.0.1 | 3.1.x |
| xterm.js (CDN) | 4.11.0 | 6.0.x |
| socket.io (CDN) | 4.0.1 | 4.7.x |

### Verdict: REFERENCE ARCHITECTURE ONLY

The ~120-line implementation is the clearest example of the Flask + Socket.IO + `pty.fork()` pattern. Its value is showing HOW to wire the pieces together, not as production code. Use its patterns, discard its code.

**What to borrow:** Event names, `pty.fork()` + `select.select()` pattern, resize ioctl.
**What to replace:** Global state -> per-session dict, add cleanup, add reconnect buffer, update all deps.

---

## 3. Flask-SocketIO for PTY Bridging (RECOMMENDED)

| Attribute | Value |
|-----------|-------|
| Version | 5.6.1 (February 2026) |
| Python | >= 3.10 (CI dropped 3.8/3.9 in v5.6.0; likely still works on 3.9) |
| License | MIT |
| Maintainer | Miguel Grinberg |
| Status | **Actively maintained** -- regular releases |

### Why This Approach

Flask-SocketIO is the standard WebSocket library for Flask. Combined with Python's built-in `pty` module and the pyxtermjs event pattern, it provides native Flask integration with full control over PTY lifecycle in ~80 lines.

### Production PTY Bridge Pattern

```python
import pty, os, select, fcntl, struct, termios, signal
from collections import deque
from flask_socketio import SocketIO, emit
from flask import request

sessions = {}  # {sid: {'fd': int, 'pid': int, 'buffer': deque}}

@socketio.on('connect', namespace='/terminal')
def on_connect():
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe('/bin/bash', ['/bin/bash'], os.environ)
    sessions[request.sid] = {
        'fd': fd, 'pid': pid,
        'buffer': deque(maxlen=1000)
    }
    socketio.start_background_task(read_pty, request.sid)

@socketio.on('pty-input', namespace='/terminal')
def on_input(data):
    fd = sessions[request.sid]['fd']
    os.write(fd, data['input'].encode())

@socketio.on('resize', namespace='/terminal')
def on_resize(data):
    fd = sessions[request.sid]['fd']
    fcntl.ioctl(fd, termios.TIOCSWINSZ,
                struct.pack('HHHH', data['rows'], data['cols'], 0, 0))

@socketio.on('disconnect', namespace='/terminal')
def on_disconnect():
    session = sessions.pop(request.sid, None)
    if session:
        try:
            os.kill(session['pid'], signal.SIGTERM)
        except ProcessLookupError:
            pass
        os.close(session['fd'])

def read_pty(sid):
    session = sessions.get(sid)
    if not session:
        return
    fd = session['fd']
    while sid in sessions:
        try:
            if select.select([fd], [], [], 0.01)[0]:
                data = os.read(fd, 20480).decode('utf-8', errors='replace')
                session['buffer'].append(data)
                socketio.emit('pty-output', {'output': data},
                              room=sid, namespace='/terminal')
        except OSError:
            socketio.emit('pty-exit', {}, room=sid, namespace='/terminal')
            break
        socketio.sleep(0.01)
```

### Threading Model

| Mode | Transport | Concurrency | Recommendation |
|------|-----------|-------------|----------------|
| `threading` | simple-websocket | OS threads | **Use this** |
| `eventlet` | native | green threads | **Deprecated** -- maintainer says "not a good option anymore" |
| `gevent` | gevent-websocket | green threads | Risk: monkey-patching can interfere with `pty.fork()`, `select()`, `os.read()` |

**Recommendation: `threading` mode.** PTY syscalls (`pty.fork`, `select`, `os.read/write`, `fcntl.ioctl`) are real OS calls that work cleanly without monkey-patching. For Watchtower's scale (<50 concurrent terminals), threading is sufficient.

### Multi-Session Support

Socket.IO provides the primitives natively:
- **`request.sid`** -- unique session ID per connection
- **Rooms** -- `emit(..., room=sid)` isolates output to specific client
- **Namespaces** -- `/terminal` keeps PTY traffic separate from other uses
- **Disconnect handler** -- cleanup PTY on disconnect

Each `connect` spawns a new PTY. Each `disconnect` kills it. State stored in dict keyed by `request.sid`.

### Integration with Existing Watchtower

Drop-in compatible:

```python
from flask_socketio import SocketIO
socketio = SocketIO(app, async_mode='threading')
# All existing routes, Jinja2 templates, htmx behavior continue working
# Add Socket.IO event handlers alongside regular routes
socketio.run(app, host='0.0.0.0', port=3000)  # replaces app.run()
```

Jinja2 templates add `<script src="socket.io.min.js">` and xterm.js. No changes to existing routing, sessions, auth, or template rendering.

**One breaking change:** `app.run()` must become `socketio.run()`. This is the sole integration cost.

### Dependencies Added

```
flask-socketio >= 5.3
simple-websocket >= 1.0   # threading mode WebSocket support
```

Both pure Python, no C extensions. Total: ~3 new packages.

### Performance

- **Input latency:** Client -> SocketIO -> `os.write()` -- near-instant (<1ms)
- **Output latency:** PTY -> `select()` poll (10ms default) -> SocketIO emit -- 0-10ms
- **Throughput:** 20KB read buffer handles typical terminal output. For bulk output (`cat` of large file), WebSocket frame rate is the bottleneck, not PTY read.
- **10ms floor is imperceptible** for terminal use. vim, htop, etc. work fine.

### Pros vs Pure WebSocket

| Flask-SocketIO | Pure WebSocket |
|----------------|----------------|
| Auto-fallback to long-polling | Lower protocol overhead |
| Built-in reconnection | Must implement yourself |
| Rooms/namespaces for multi-terminal | Must implement yourself |
| Integrates with existing Flask auth/sessions | Requires separate auth layer |
| Socket.IO protocol overhead (~10-15%) | Full binary frame control |
| Event-based API (`on("pty-input")`) | Raw message parsing |

### Verdict: RECOMMENDED

Lowest integration cost with existing Flask stack. ~80 lines of custom code for the PTY bridge. Well-maintained transport layer. Full control over PTY lifecycle. Multi-session by design via rooms. Socket.IO overhead is negligible for terminal data volumes.

---

## 4. websockify

| Attribute | Value |
|-----------|-------|
| Version | 0.13.0 (May 2025) |
| Python | 3.6-3.12 |
| License | **LGPL-3.0** |
| Stars | 4.4k |
| Maintainer | noVNC project |
| Status | Actively maintained |

### What It Does

WebSocket-to-TCP proxy built for noVNC (browser VNC client). Accepts WebSocket connections, performs RFC 6455 handshake, bidirectionally forwards raw bytes to a TCP target. Supports binary and base64 subprotocols.

### Can It Bridge PTY?

Only indirectly. websockify bridges TCP sockets, not PTY file descriptors. For terminals you'd need:

```
Browser -> WebSocket -> websockify -> TCP -> telnetd/sshd -> PTY
```

Has a `--wrap-mode` that launches programs via `LD_PRELOAD` (`rebind.so`) to intercept `bind()` calls, but this is for TCP-speaking programs, not interactive shells.

### Why It Doesn't Fit

1. **TCP-oriented** -- bridges WebSocket to TCP sockets, not file descriptors
2. **Extra hop** -- every request traverses browser -> WS -> websockify -> TCP -> daemon -> PTY. Each hop adds latency and failure points.
3. **No terminal semantics** -- no resize (SIGWINCH/TIOCSWINSZ), no signal handling, no terminal lifecycle management
4. **Runs its own HTTP server** -- not embeddable in Flask as middleware
5. **LGPL license** -- more restrictive than MIT/BSD
6. **Overkill** -- using a VNC proxy as a dumb pipe adds complexity without benefit when direct PTY-to-WebSocket is simpler

### Verdict: WRONG TOOL

websockify solves WebSocket-to-TCP proxying for VNC. It has no concept of PTY terminals. Every other option in this report connects PTY fd directly to WebSocket with less complexity.

---

## 5. aiohttp / FastAPI Approaches

### FastAPI PTY Bridge

```python
@app.websocket("/ws/terminal")
async def terminal(ws: WebSocket):
    await ws.accept()
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe('/bin/bash', ['/bin/bash'], os.environ)

    loop = asyncio.get_event_loop()
    queue = asyncio.Queue()

    def on_pty_read():
        data = os.read(fd, 4096)
        queue.put_nowait(data)

    loop.add_reader(fd, on_pty_read)

    async def writer():
        while True:
            data = await queue.get()
            await ws.send_text(data.decode('utf-8', errors='replace'))

    async def reader():
        while True:
            msg = await ws.receive_text()
            os.write(fd, msg.encode())

    await asyncio.gather(writer(), reader())
```

### Key Mechanism: `loop.add_reader(fd, callback)`

Registers PTY master fd with the event loop's selector (epoll on Linux, kqueue on macOS). When child writes to terminal, master fd becomes readable, callback fires, `os.read()` gets data. Non-blocking, zero-copy at OS level. No polling loop, no 10ms latency floor.

### aiohttp Approach

Same pattern using `aiohttp.web.WebSocketResponse()` and `loop.add_reader()`. Slightly lower-level than FastAPI but gives direct event loop access.

### Performance Advantages Over Flask-SocketIO

- Single-threaded, no GIL contention for I/O multiplexing
- `add_reader` uses epoll/kqueue (O(1) per event) vs `select()` (O(n) per fd)
- Event-driven -- zero latency floor (no polling)
- Handles hundreds of concurrent terminals in one process
- Direct PTY fd to WebSocket -- no serialization/deserialization overhead
- No Socket.IO protocol layer (~10-15% overhead eliminated)

### Flask Integration Challenge

WSGI is synchronous and cannot handle WebSocket natively. Options:

1. **FastAPI as outer app, Flask mounted inside** -- Use Starlette's `WSGIMiddleware` to mount Flask routes under FastAPI. WebSocket endpoints live in FastAPI natively. Cleanest migration path.
2. **Separate ports** -- Flask on :3000, FastAPI on :3001. Reverse proxy routes `/ws/` to FastAPI.
3. **Gradual migration** -- Start with Flask-SocketIO (Phase 1), migrate WebSocket layer to FastAPI when scale demands (Phase 2).

### Notable Implementations for Reference

- **ttyd** (C, 8.5k stars) -- libwebsockets + libuv + xterm.js. Production-grade gold standard.
- **gotty** (Go) -- WebSocket + PTY + xterm.js. Mature but archived.
- **webterm** (Python/FastAPI) -- Session management, timeouts, max-sessions config. ~200 lines.

### Verdict: BEST ARCHITECTURE, WORST MIGRATION COST

Async PTY I/O via `add_reader` is objectively superior -- event-driven, no polling, no threading overhead. But it requires ASGI, which means either wrapping Flask inside FastAPI or running a separate service. Worth it at >50 concurrent terminals; overkill for Watchtower's initial deployment.

---

## Comparison Matrix

| Criterion | Terminado | pyxtermjs | Flask-SocketIO | websockify | FastAPI/aiohttp |
|-----------|-----------|-----------|----------------|------------|-----------------|
| **Flask integration** | Hard (Tornado dep) | Native (is Flask) | Drop-in | Separate server | Requires ASGI migration |
| **Multi-session** | Yes (3 managers) | No (single global) | Yes (rooms/SID) | N/A (TCP proxy) | Yes (manual) |
| **PTY lifecycle** | Excellent (all phases) | Minimal (spawn/resize) | Manual (~80 LOC) | N/A | Manual (~60 LOC) |
| **Reconnect** | Yes (1000-msg buffer) | No | Socket.IO auto-reconnect + custom buffer | N/A | Manual |
| **Resize** | Yes (resize_to_smallest) | Yes (TIOCSWINSZ) | Yes (TIOCSWINSZ) | No | Yes (TIOCSWINSZ) |
| **Protocol overhead** | Minimal (JSON arrays) | Socket.IO (~10-15%) | Socket.IO (~10-15%) | Binary frames | Minimal (raw WS) |
| **Output latency floor** | 100ms (poll cycle) | 10ms (poll cycle) | 10ms (poll cycle) | Extra TCP hop | 0ms (event-driven) |
| **Concurrent terminals** | Hundreds (Tornado) | 1 | Tens (threading) | Hundreds | Hundreds (async) |
| **Python 3.9+** | Yes (3.14 issues) | Untested | CI: 3.10+ | Yes | Yes |
| **Maintenance** | Maintenance mode | Abandoned (3+ yrs) | Active (monthly) | Active | Active (frameworks) |
| **License** | BSD-2 | MIT | MIT | LGPL-3 | MIT |

---

## Recommendation for Watchtower

### Phase 1: Flask-SocketIO + Threading (Simplest Path)

**Why:** Zero architectural changes. Drop-in `SocketIO(app)` wrapper. Multi-session via `request.sid` + rooms. ~80 lines of PTY bridge code. Socket.IO client JS is a single `<script>` tag.

**Implementation plan:**
1. `pip install flask-socketio simple-websocket`
2. Wrap app: `socketio = SocketIO(app, async_mode='threading')`
3. Replace `app.run()` with `socketio.run(app)`
4. Add `/terminal` namespace with 5 handlers (connect, disconnect, pty-input, pty-output, resize)
5. Per-session PTY dict: `{sid: {fd, pid, buffer}}`
6. Background read thread per session (10ms poll via `select.select()`)
7. Cleanup: kill PTY + close fd on disconnect

**Borrow from terminado:**
- Graceful kill escalation (SIGHUP -> SIGCONT -> SIGINT -> SIGTERM -> SIGKILL)
- Reconnect buffer (deque maxlen=1000 for output replay)
- Named terminal concept (for persistent sessions like TermLink)

**Security (non-negotiable):**
- Authenticate at Socket.IO `connect` handler before spawning PTY
- Rate-limit session creation
- Set idle timeout (kill PTY after N minutes inactive)
- Never run Watchtower as root

### Phase 2 (If Needed): FastAPI Outer Shell

**Trigger:** >50 concurrent terminals, or threading mode shows strain.

**Migration path:**
1. Mount Flask app inside FastAPI via `WSGIMiddleware`
2. Move WebSocket endpoints to native FastAPI `@websocket` routes
3. Replace `select.select()` polling with `loop.add_reader()` (event-driven, 0ms latency)
4. All existing Flask routes continue working unchanged

### What NOT to Use

| Option | Reason |
|--------|--------|
| Terminado directly | Tornado dependency is a dealbreaker for Flask |
| pyxtermjs as dependency | Abandoned, single-session, no cleanup, stale deps |
| websockify | Wrong abstraction (TCP proxy, not PTY bridge), LGPL |
| Full Flask-to-FastAPI migration | Disproportionate to the feature |
| ttyd sidecar | Good if terminal is view-only, but loses integration depth with Watchtower state (tasks, agents, sessions) |

---

## Key Implementation Risks

1. **Threading + PTY cleanup** -- Must handle `SIGCHLD` to detect dead children, or poll `os.waitpid(pid, WNOHANG)` periodically. Zombie processes accumulate if PTY children die without cleanup.

2. **Socket.IO reconnect vs PTY state** -- Socket.IO auto-reconnects the transport, but gets a new `sid`. Must implement output buffering (terminado's deque pattern) and a session persistence layer if reconnect should resume the same PTY.

3. **macOS PTY differences** -- `pty.fork()` works on macOS but some behaviors differ. `termios.TIOCSWINSZ` is the same. `pty.openpty()` is more portable if `pty.fork()` issues arise. Basic functionality needs no platform-specific code.

4. **Security** -- Every WebSocket connection spawns a shell process. Must authenticate at the Socket.IO `connect` handler using Watchtower's existing Flask session/auth. Consider restricting shell to specific commands.

5. **`os.read()` after child dies** -- Raises `OSError`. Must wrap in try/except and emit `pty-exit` event to client. This is the most common bug in PTY bridge implementations.

6. **Gevent future** -- If Watchtower ever adopts gevent for other reasons, the PTY bridge must be tested carefully -- monkey-patching `select`, `os.read`, and `pty.fork` can cause subtle failures.

---

## Sources

- [jupyter/terminado](https://github.com/jupyter/terminado) -- websocket.py, management.py source
- [terminado PyPI](https://pypi.org/project/terminado/) -- package metadata, downloads
- [cs01/pyxtermjs](https://github.com/cs01/pyxtermjs) -- app.py source code
- [Flask-SocketIO docs](https://flask-socketio.readthedocs.io/) -- API reference
- [Flask-SocketIO PyPI](https://pypi.org/project/Flask-SocketIO/) -- version history
- [Flask-SocketIO async mode discussion #2068](https://github.com/miguelgrinberg/Flask-SocketIO/discussions/2068) -- eventlet deprecation
- [Flask-SocketIO discussion #1915](https://github.com/miguelgrinberg/Flask-SocketIO/discussions/1915) -- async mode comparison
- [novnc/websockify](https://github.com/novnc/websockify) -- WebSocket-to-TCP proxy
- [tsl0922/ttyd](https://github.com/tsl0922/ttyd) -- C web terminal (reference implementation)
- [flask-terminado](https://github.com/nathanielobrown/flask-terminado) -- abandoned Flask wrapper (2017)
- [terminado GitHub issues](https://github.com/jupyter/terminado/issues) -- known problems
- [xterm.js addon-attach](https://github.com/xtermjs/xterm.js/tree/main/addons/addon-attach) -- WebSocket protocol reference
