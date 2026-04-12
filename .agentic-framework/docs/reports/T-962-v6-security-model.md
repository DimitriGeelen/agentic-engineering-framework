# T-962: Web Terminal Security Model

**Task:** T-962 (Inception — web terminal in Watchtower)
**Date:** 2026-04-06
**Purpose:** Threat model and security design for embedding an interactive terminal in Watchtower

---

## Executive Summary

A web terminal is qualitatively different from every other Watchtower feature. Today, Watchtower is read-mostly — it renders dashboards, task lists, and metrics. The worst a rogue request can do is display wrong data. A web terminal grants **arbitrary shell execution as the Watchtower process user**. One unauthenticated WebSocket connection = full shell access.

This report enumerates threats specific to LAN deployment, compares how production-grade tools handle them, and recommends a security posture for v1 (LAN-only, single-user) with an upgrade path for internet/multi-user.

**Bottom line:** For v1 LAN, the minimum viable security is origin-checked WebSockets + CSRF-protected session tokens + a dedicated unprivileged user for PTY processes. No authentication scheme beyond what Watchtower already has (Flask sessions + CSRF) is needed for single-user LAN, but the architecture must not preclude adding auth later.

---

## 1. Threat Model

### 1.1 Deployment Contexts

| Context | Network | TLS | Users | Exposure |
|---------|---------|-----|-------|----------|
| **Dev** | localhost:3000 | No | 1 (developer) | Machine-local only |
| **Prod (current)** | LAN 192.168.10.x, Traefik HTTPS on :443 | Yes (Traefik) | 1 (admin) | LAN only, no internet ingress |
| **Future** | Internet-facing via Traefik + auth | Yes | Multiple | Public internet |

### 1.2 Threat Matrix

| # | Threat | Vector | Impact | Likelihood (LAN) | Likelihood (Internet) | Mitigation |
|---|--------|--------|--------|-------------------|----------------------|------------|
| T1 | **Unauthenticated shell access** | Any LAN device opens WebSocket to `/ws/terminal` | Critical — full shell as process user | Medium (any LAN device, guest WiFi) | Critical | Auth gate on WebSocket endpoint |
| T2 | **Cross-Site WebSocket Hijacking (CSWSH)** | Malicious page on LAN host connects to `ws://192.168.10.170:5050/ws/terminal` | Critical — shell via victim's browser | Medium (requires user to visit malicious LAN page) | High | Origin checking, CSRF token in WebSocket handshake |
| T3 | **Session hijacking / replay** | Sniff WebSocket traffic on LAN (no TLS on dev) | Critical — steal active terminal session | Low (requires ARP spoofing on switched LAN) | N/A (TLS in prod) | TLS everywhere, session expiry |
| T4 | **PTY session cross-access** | User A reads/writes User B's PTY file descriptor | High — lateral access between sessions | N/A (single user v1) | High (multi-user) | Per-session UID, fd isolation |
| T5 | **Privilege escalation via shell** | Terminal user runs `sudo`, edits system files | Critical — root access | High (if PTY runs as root or watchtower user with sudo) | Critical | Unprivileged PTY user, no sudo, restricted PATH |
| T6 | **XSS → terminal injection** | XSS in Watchtower page injects JS that opens WebSocket | Critical — shell access via XSS | Low (no user-generated content in Watchtower) | Medium | CSP, XSS sanitization, separate origin for terminal |
| T7 | **Agent bypasses Tier 0 via web terminal** | AI agent uses web terminal endpoint to execute commands without hook enforcement | Critical — bypasses all framework governance | High (agent has HTTP access) | High | Block agent user-agent, require hook-verified execution path |
| T8 | **WebSocket DoS** | Flood WebSocket connections, each spawns a PTY | High — resource exhaustion (PIDs, memory, FDs) | Low (LAN) | High (internet) | Connection limit, rate limiting, max sessions |
| T9 | **Terminal output exfiltration** | Attacker reads terminal buffer containing secrets (API keys, passwords) | High — credential theft | Low (single user LAN) | High | Session isolation, buffer limits, no persistent scrollback to disk |
| T10 | **Reverse shell from PTY** | Command executed in terminal opens outbound connection | Medium — data exfiltration | Low (attacker already has shell) | Medium | Network egress rules (firewall), not terminal-layer concern |
| T11 | **WebSocket connection persistence** | Orphaned WebSocket keeps PTY alive after browser tab closes | Medium — resource leak, stale sessions | Medium | Medium | Heartbeat/ping, idle timeout, server-side cleanup |
| T12 | **Traefik WebSocket proxy misconfiguration** | Traefik strips headers, breaks upgrade, or doesn't proxy correctly | Low — feature breakage, not security | Medium | Medium | Explicit WebSocket router config |

### 1.3 Attacker Profiles (LAN Context)

| Attacker | Access | Motivation | Relevant Threats |
|----------|--------|------------|-----------------|
| **Rogue LAN device** | Any device on 192.168.10.0/24 | Lateral movement, curiosity | T1, T8 |
| **Malicious web page** | JavaScript in user's browser | CSWSH exploitation | T2, T6 |
| **AI agent (own)** | HTTP access to Watchtower endpoints | Bypass governance hooks | T7 |
| **Guest WiFi device** | If guest VLAN not isolated | Opportunistic access | T1, T2 |

---

## 2. How Production Tools Handle Security

### 2.1 ttyd

[ttyd](https://github.com/tsl0922/ttyd) — single-binary terminal sharing over HTTP.

| Aspect | Implementation |
|--------|---------------|
| **Authentication** | Optional basic auth (`-c user:pass`), optional client certificate (`-t`). No auth by default. |
| **Session isolation** | One PTY per WebSocket connection. No cross-session access. PTY runs as ttyd's user. |
| **Origin checking** | Checks `Origin` header against configured allowed origins (`-O`). Rejects mismatches. |
| **CSRF** | None — relies on origin check. No cookie-based sessions. |
| **TLS** | Built-in TLS support (`-S`, `-C`, `-K`). Recommended for non-localhost. |
| **Shell user** | Runs shell as ttyd process user. Use `sudo -u nobody ttyd bash` for deprivileged. |
| **Connection limits** | `--max-clients N` caps concurrent connections. |
| **Read-only mode** | `-R` flag — view-only terminal (useful for sharing output). |
| **Credential handling** | Supports `credential` URL parameter for programmatic auth. |

**Relevance to Watchtower:** ttyd's origin checking + basic auth + max-clients is a reasonable baseline. Its lack of session-level auth (any authenticated user sees any session) is acceptable for single-user but breaks for multi-user.

### 2.2 Wetty (Web + tty)

[Wetty](https://github.com/butlerx/wetty) — terminal over HTTP, designed for SSH access.

| Aspect | Implementation |
|--------|---------------|
| **Authentication** | Delegates to SSH — every WebSocket connection triggers an SSH login. Strong auth by design. |
| **Session isolation** | Each connection is an independent SSH session. OS-level user isolation. |
| **Origin checking** | None built-in — relies on reverse proxy (nginx/Traefik). |
| **CSRF** | Not applicable — SSH auth on each connection. |
| **TLS** | Reverse proxy only (no built-in TLS). |
| **Shell user** | SSH target user — full OS user model. |
| **Multi-user** | Yes — SSH user separation. |

**Relevance to Watchtower:** Wetty's "delegate to SSH" model is overkill for single-user LAN but is the gold standard for multi-user. If Watchtower ever goes multi-user, SSH-based PTY auth is the correct architecture.

### 2.3 JupyterHub / JupyterLab

| Aspect | Implementation |
|--------|---------------|
| **Authentication** | Pluggable authenticators (PAM, OAuth, LDAP). Required. Token-based API access. |
| **Session isolation** | Spawner system — each user gets a separate process (or container). Full UID isolation. |
| **Origin checking** | Strict origin validation in Tornado WebSocket handler. |
| **CSRF** | `_xsrf` token required for all state-changing requests. WebSocket upgrade requires valid session cookie. |
| **TLS** | Reverse proxy recommended. Built-in TLS available. |
| **Shell user** | Spawner creates processes as the authenticated OS user. |
| **Terminal specifics** | JupyterLab terminal spawns PTY via `terminado` (Python). One PTY per terminal tab. |
| **Connection limits** | Configurable per-user limits. Idle culling built in. |

**Relevance to Watchtower:** JupyterHub's terminado-based terminal is the closest architectural match (Python, WebSocket, PTY). Its CSRF + session cookie + origin check triple is the reference implementation for our stack.

### 2.4 code-server (VS Code in browser)

| Aspect | Implementation |
|--------|---------------|
| **Authentication** | Password auth (default), OAuth proxy support. `--auth none` to disable. |
| **Session isolation** | Single-user design. All terminals share the server process user. |
| **Origin checking** | Validates `Host` and `Origin` headers. |
| **CSRF** | Standard VS Code CSRF token mechanism. |
| **TLS** | Built-in `--cert` / `--cert-key`. Reverse proxy common. |
| **Shell user** | Server process user. |
| **Connection limits** | None built-in (single-user assumption). |

**Relevance to Watchtower:** code-server's security model is the closest to our v1 constraints — single user, password optional, rely on TLS + origin checking. It works well for trusted LANs.

### 2.5 Comparison Summary

| Control | ttyd | Wetty | JupyterHub | code-server | **Watchtower v1 (proposed)** |
|---------|------|-------|------------|-------------|------------------------------|
| Auth required by default | No | Yes (SSH) | Yes | Yes (password) | No (LAN trust) |
| Session-level auth | No | Yes | Yes | No | No |
| Origin checking | Yes | No | Yes | Yes | **Yes** |
| CSRF protection | No | N/A | Yes | Yes | **Yes (existing)** |
| Per-user isolation | No | Yes (SSH) | Yes (spawner) | No | No (single user) |
| TLS built-in | Yes | No | Yes | Yes | No (Traefik) |
| Connection limits | Yes | No | Yes | No | **Yes** |
| Idle timeout | No | SSH timeout | Yes | No | **Yes** |
| Read-only mode | Yes | No | No | No | **Yes (future)** |

---

## 3. Security Controls — Recommended for v1 (LAN)

### 3.1 Authentication: Accept LAN Trust (with opt-in auth)

**Decision:** No additional authentication for v1 LAN deployment.

**Rationale:**
- Watchtower currently has zero authentication — adding auth only for the terminal creates a false sense of security (dashboard data is equally sensitive for an ops tool)
- LAN is trusted (192.168.10.0/24, no guest WiFi on same VLAN)
- Single user — no user separation needed
- Traefik provides TLS — no credential sniffing risk in prod

**Architecture for upgrade:** All terminal endpoints go through a single `before_request` check function that currently passes through. When auth is added later, it's a one-line change:

```python
# web/blueprints/terminal.py

def check_terminal_auth():
    """Gate for terminal access. LAN trust for v1, auth for v2."""
    pass  # v1: LAN trust
    # v2: check session token, API key, or basic auth header
```

**Upgrade path:**
1. **Traefik basic auth middleware** — Zero code change, add `basicAuth` middleware to traefik-routes.yml. Protects all endpoints including terminal.
2. **Flask session auth** — Login page, session cookie. Terminal WebSocket validates session.
3. **API key per terminal session** — WebSocket URL includes `?token=X`, server validates before PTY spawn.

### 3.2 WebSocket Security

#### Origin Checking (blocks T2 — CSWSH)

The most important control. Without it, any web page the user visits can connect to the terminal WebSocket.

```python
ALLOWED_ORIGINS = {
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "https://watchtower.docker.ring20.geelenandcompany.com",
    "https://watchtower-dev.docker.ring20.geelenandcompany.com",
}

def validate_ws_origin(request):
    """Reject WebSocket upgrades from unauthorized origins."""
    origin = request.headers.get("Origin", "")
    if origin not in ALLOWED_ORIGINS:
        abort(403, f"Origin {origin} not allowed")
```

**Why this works:** A malicious page on `http://evil.lan:8080` will send `Origin: http://evil.lan:8080` — which gets rejected. Browsers enforce that JavaScript cannot forge the `Origin` header.

**Limitation:** Non-browser clients (curl, Python scripts) can forge `Origin`. This is acceptable for LAN (attacker with curl access already has LAN shell access).

#### CSRF Token in WebSocket Handshake (blocks T2 defense-in-depth)

Watchtower already generates CSRF tokens (Flask sessions). Require the token as a query parameter on WebSocket upgrade:

```javascript
// Client
const csrf = document.querySelector('meta[name="csrf-token"]').content;
const ws = new WebSocket(`ws://${location.host}/ws/terminal?csrf_token=${csrf}`);
```

```python
# Server
def ws_terminal(ws):
    token = request.args.get("csrf_token")
    if token != session.get("_csrf_token"):
        ws.close(4403, "Invalid CSRF token")
        return
```

**Why both origin AND CSRF?** Defense in depth. Origin check blocks cross-origin attacks. CSRF token blocks same-origin attacks where an attacker can inject scripts into a Watchtower page (XSS → T6).

#### Connection Limits (blocks T8 — DoS)

```python
MAX_TERMINAL_SESSIONS = 5  # Single user doesn't need more
active_sessions = {}  # session_id → PTYProcess

def ws_terminal(ws):
    if len(active_sessions) >= MAX_TERMINAL_SESSIONS:
        ws.close(4429, "Too many terminal sessions")
        return
```

#### Heartbeat / Idle Timeout (blocks T11 — orphaned sessions)

```python
TERMINAL_IDLE_TIMEOUT = 600  # 10 minutes
TERMINAL_HEARTBEAT_INTERVAL = 30  # seconds

# Server sends ping every 30s, closes if no pong within 10s
# Client-side: xterm.js onData resets idle timer
# Server-side: no input for 600s → send warning → close after 30s grace
```

### 3.3 PTY Process Isolation (blocks T5 — privilege escalation)

#### Dedicated Terminal User

The PTY process should NOT run as the Watchtower process user (which has write access to the framework repo, context files, etc.).

```bash
# Create a dedicated terminal user (one-time setup)
useradd -r -s /bin/bash -d /home/fw-terminal -m fw-terminal
# Grant read access to framework repo
usermod -aG watchtower fw-terminal
```

```python
import pty, os

def spawn_terminal():
    """Spawn PTY as unprivileged user."""
    pid, fd = pty.fork()
    if pid == 0:  # child
        os.setgid(FW_TERMINAL_GID)
        os.setuid(FW_TERMINAL_UID)
        os.execvp("/bin/bash", ["bash", "--restricted"])  # or rbash
    return pid, fd
```

**v1 pragmatic alternative:** If running as non-root already (e.g., `watchtower` user), the PTY inherits that user. This is acceptable for single-user LAN — the terminal user IS the Watchtower admin. Document the risk and defer user separation to v2.

#### Restricted PATH (defense-in-depth for v1)

Even without a separate user, limit what the terminal can easily access:

```python
TERMINAL_ENV = {
    "PATH": "/usr/local/bin:/usr/bin:/bin",  # No /sbin, no framework bin/
    "HOME": "/home/fw-terminal",
    "TERM": "xterm-256color",
    "SHELL": "/bin/bash",
    # Explicitly DO NOT pass: ANTHROPIC_API_KEY, FW_*, etc.
}
```

### 3.4 Agent Access Control (blocks T7 — Tier 0 bypass)

This is a framework-specific threat that no existing tool addresses. The AI agent has HTTP access to Watchtower. If the terminal endpoint is unauthenticated, the agent could:

1. Open a WebSocket to `/ws/terminal`
2. Send `rm -rf /` or `git push --force` without Tier 0 hook enforcement
3. Framework hooks only apply to Claude Code tool calls, not arbitrary WebSocket I/O

**Controls:**

| Control | Implementation | Strength |
|---------|---------------|----------|
| **Session-only access** | Terminal requires Flask session cookie (set by browser login page). Agent HTTP requests don't have browser cookies. | Strong — agent can't get a session without visiting the page |
| **CSRF token** | WebSocket requires CSRF token from rendered page. Agent can't get it via API. | Strong — blocks programmatic access |
| **User-Agent blocklist** | Reject WebSocket upgrades from known agent UAs (Claude, curl, Python-requests) | Weak — trivially forgeable |
| **Audit trail** | Log all terminal commands server-side with timestamp and source IP | Detective — doesn't prevent, but enables forensics |
| **Architectural separation** | Terminal commands go through `fw` CLI which has its own hooks. Agent should use `fw` directly, not terminal. | Structural — correct by design |

**Recommendation for v1:** The existing CSRF + session cookie combination is sufficient. The agent operates via Claude Code tool calls (Bash, Write, Edit) — all of which go through framework hooks. There is no motivation for the agent to use the web terminal, and the CSRF gate prevents accidental access.

**If agent access is ever desired** (e.g., for remote execution), it should go through a dedicated API endpoint with explicit Tier 0 integration, not through the terminal WebSocket.

### 3.5 Traefik WebSocket Proxying (blocks T12)

Current `traefik-routes.yml` does not configure WebSocket-specific routing. Traefik v2+ supports WebSocket transparently for HTTP routers, but explicit configuration is recommended:

```yaml
http:
  routers:
    watchtower:
      rule: "Host(`watchtower.docker.ring20.geelenandcompany.com`)"
      service: watchtower
      middlewares:
        - watchtower-retry
        - watchtower-headers  # Add security headers
      entryPoints:
        - websecure
      tls: {}

  middlewares:
    watchtower-headers:
      headers:
        customResponseHeaders:
          X-Frame-Options: "DENY"  # Prevent iframe embedding
          X-Content-Type-Options: "nosniff"
          Content-Security-Policy: "default-src 'self'; connect-src 'self' wss://watchtower.docker.ring20.geelenandcompany.com"

    watchtower-retry:
      retry:
        attempts: 3
        initialInterval: 200ms
```

**Key points:**
- Traefik automatically detects `Connection: Upgrade` and proxies WebSocket — no special router config needed
- The `retry` middleware should NOT retry WebSocket connections (Traefik handles this correctly — retry only applies to initial HTTP)
- `X-Frame-Options: DENY` prevents clickjacking (attacker embedding Watchtower in an iframe)
- CSP `connect-src` restricts WebSocket connections to same origin

**WebSocket-specific concern:** Traefik has configurable read/write deadlines. Long-idle terminals may get disconnected. Set transport timeouts:

```yaml
  services:
    watchtower:
      loadBalancer:
        servers:
          - url: "http://192.168.10.170:5050"
        responseForwarding:
          flushInterval: "100ms"  # Low latency for terminal output
      # Note: serversTransport.forwardingTimeouts controls WebSocket idle
```

### 3.6 XSS Mitigation (blocks T6)

Watchtower uses Jinja2 with autoescaping (Flask default). Terminal output is rendered by xterm.js (which parses escape sequences in a sandboxed canvas/WebGL context, not innerHTML). The XSS risk is low but not zero:

| Vector | Risk | Mitigation |
|--------|------|------------|
| Terminal output rendered as HTML | None — xterm.js renders to canvas, not DOM | Architectural (xterm.js design) |
| Terminal title (OSC sequences) | Low — could set window.title to misleading text | Strip or sanitize OSC title sequences |
| Jinja2 template injection | None — no user input in terminal page templates | Architectural |
| WebSocket message injection | None — binary PTY stream, not parsed as HTML | Architectural |
| URL parameters reflected in page | Low — standard Jinja2 escaping | Jinja2 autoescaping |

**Recommendation:** No additional XSS controls needed beyond Jinja2 autoescaping and CSP headers. xterm.js's canvas-based rendering is inherently safe against DOM-based XSS.

---

## 4. Session Isolation Model

### 4.1 v1 Architecture (Single User)

```
Browser Tab 1 ──WebSocket──→ Flask ──→ PTY Process 1 (bash, uid=watchtower)
Browser Tab 2 ──WebSocket──→ Flask ──→ PTY Process 2 (bash, uid=watchtower)
Browser Tab 3 ──WebSocket──→ Flask ──→ PTY Process 3 (bash, uid=watchtower)
```

- Each WebSocket connection gets its own PTY process (fork + exec)
- PTY processes share the same UID (Watchtower process user)
- Cross-session access is possible (same UID can read /proc/*/fd) — acceptable for single user
- Server maintains a `session_id → (pid, fd, websocket)` mapping
- On WebSocket close → SIGHUP to PTY → process terminates → fd closed

### 4.2 v2 Architecture (Multi-User, future)

```
User A (session) ──WebSocket──→ Flask ──auth──→ Spawner ──→ PTY (uid=user_a)
User B (session) ──WebSocket──→ Flask ──auth──→ Spawner ──→ PTY (uid=user_b)
```

- Each authenticated user gets PTY processes under their own UID
- OS-level fd isolation prevents cross-user access
- Session tokens tied to authenticated identity
- Inspired by JupyterHub's spawner model

### 4.3 Session Lifecycle

```
WebSocket Connect
    │
    ├── Validate Origin header
    ├── Validate CSRF token
    ├── Check connection limit
    │
    ▼
Spawn PTY
    │
    ├── Fork process
    ├── Set UID/GID (if separate user)
    ├── Configure environment (stripped, no secrets)
    ├── Register in active_sessions map
    │
    ▼
Active Session
    │
    ├── Bidirectional I/O (WebSocket ↔ PTY fd)
    ├── Heartbeat ping/pong (30s interval)
    ├── Idle timeout monitoring (600s)
    ├── Window resize events (SIGWINCH)
    │
    ▼
Termination (any of:)
    │
    ├── Client closes tab → WebSocket onclose → SIGHUP PTY
    ├── Idle timeout → server closes WebSocket → SIGHUP PTY
    ├── PTY process exits → server closes WebSocket
    ├── Server shutdown → SIGHUP all PTYs
    │
    ▼
Cleanup
    │
    ├── Close PTY fd
    ├── Waitpid (reap zombie)
    ├── Remove from active_sessions
    ├── Log session duration + command count (audit)
```

---

## 5. Recommended Security Posture by Phase

### v1 — LAN-Only, Single-User (Current Target)

| Control | Status | Priority |
|---------|--------|----------|
| Origin checking on WebSocket | **Required** | P0 |
| CSRF token in WebSocket handshake | **Required** | P0 |
| Max concurrent sessions (5) | **Required** | P0 |
| Idle timeout (600s) | **Required** | P1 |
| Heartbeat ping/pong | **Required** | P1 |
| Stripped environment (no secrets) | **Required** | P1 |
| Audit logging (commands, connect/disconnect) | **Required** | P1 |
| CSP headers | **Recommended** | P2 |
| X-Frame-Options: DENY | **Recommended** | P2 |
| Separate terminal user (fw-terminal) | **Deferred** | P3 |
| No authentication | **Accepted risk** | — |
| Same-UID session cross-access | **Accepted risk** | — |

**Accepted risks and rationale:**
- **No auth:** Entire Watchtower is unauthenticated. Terminal doesn't make this worse in a meaningful way on trusted LAN. First auth effort should protect all of Watchtower, not just terminal.
- **Same UID:** Single user owns all sessions. Cross-access is a feature (e.g., debugging), not a bug.

### v2 — Internet-Facing / Multi-User (Upgrade Path)

| Control | Implementation |
|---------|---------------|
| **Authentication** | Traefik forward-auth middleware → OAuth2/OIDC (e.g., Authentik, Authelia) or Flask-Login with bcrypt passwords |
| **Per-user PTY isolation** | Spawner forks PTY as authenticated OS user (requires root or CAP_SETUID) |
| **Session tokens** | JWT or opaque token per terminal session, validated on every WebSocket message |
| **Rate limiting** | Traefik rate-limit middleware on WebSocket upgrade endpoint |
| **Audit trail** | Full command logging with user attribution, shipped to central log |
| **Read-only mode** | Observer role can view but not input (like ttyd -R) |
| **Session sharing** | Explicit invite model (not implicit cross-access) |

### v3 — Multi-Tenant (Far Future)

| Control | Implementation |
|---------|---------------|
| **Container isolation** | Each user's PTY runs in a dedicated container (like JupyterHub + DockerSpawner) |
| **Resource limits** | cgroups per session (CPU, memory, PID limits) |
| **Network isolation** | Per-session network namespace |
| **Filesystem isolation** | Read-only root + user-specific writable overlay |

---

## 6. Implementation Checklist for v1

```
Server-side (Flask):
  [ ] Origin validation function (allowlist-based)
  [ ] CSRF token extraction from WebSocket query params
  [ ] Active session registry with max-limit enforcement
  [ ] PTY spawn with stripped environment
  [ ] Idle timeout + heartbeat goroutine/thread
  [ ] SIGHUP cleanup on disconnect
  [ ] Zombie reaping (waitpid on PTY child)
  [ ] Session audit logging (connect, disconnect, duration)

Client-side (xterm.js):
  [ ] Pass CSRF token in WebSocket URL
  [ ] Handle WebSocket close codes (4403=auth, 4429=limit)
  [ ] Reconnect logic with backoff (not infinite retry)
  [ ] Idle warning display before timeout disconnect

Traefik:
  [ ] Add security headers middleware
  [ ] Verify WebSocket proxy works (Connection: Upgrade passthrough)
  [ ] Test idle connection survival (no premature timeout)

Framework:
  [ ] Document that web terminal bypasses Tier 0 hooks
  [ ] Add terminal session count to /health endpoint
  [ ] Add terminal section to fw doctor (port check, process count)
```

---

## 7. Threat-to-Control Traceability

| Threat | Controls Applied |
|--------|-----------------|
| T1 (Unauth shell) | Origin check, CSRF token, future: auth gate |
| T2 (CSWSH) | Origin check + CSRF token (dual layer) |
| T3 (Session hijack) | TLS via Traefik (prod), accepted risk (dev/localhost) |
| T4 (Cross-session) | Accepted risk v1 (same user), per-UID isolation v2 |
| T5 (Privilege escalation) | Stripped env v1, separate user v2, restricted shell v2 |
| T6 (XSS → terminal) | CSP headers, xterm.js canvas rendering, Jinja2 autoescaping |
| T7 (Agent bypass) | CSRF + session cookie blocks programmatic access |
| T8 (WebSocket DoS) | Max 5 concurrent sessions, idle timeout, rate limit v2 |
| T9 (Output exfil) | Session isolation, no disk scrollback, TLS in transit |
| T10 (Reverse shell) | Out of scope (network-layer control, not terminal-layer) |
| T11 (Orphaned sessions) | Heartbeat, idle timeout, disconnect cleanup |
| T12 (Traefik misconfig) | Explicit header middleware, tested WebSocket proxy |

---

## Sources & References

- [ttyd security options](https://github.com/tsl0922/ttyd#security) — origin check, basic auth, TLS, max-clients
- [Wetty architecture](https://github.com/butlerx/wetty) — SSH delegation model
- [JupyterHub security](https://jupyterhub.readthedocs.io/en/stable/explanation/websecurity.html) — CSRF, auth, spawner isolation
- [code-server security](https://coder.com/docs/code-server/latest/guide#security) — password auth, origin validation
- [WebSocket security (OWASP)](https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html#websockets) — CSWSH, origin checking
- [xterm.js security model](https://github.com/xtermjs/xterm.js/blob/master/SECURITY.md) — canvas rendering, no innerHTML
- Watchtower existing controls: `web/app.py` CSRF implementation (lines 62-80)
- Traefik current config: `deploy/traefik-routes.yml`
