# T-962: Full-Solution Web Terminals — Survey & Comparison

**Task:** T-962 (Inception — web terminal in Watchtower)
**Date:** 2026-04-06
**Research Vector:** 3 — Existing Full Solutions
**Purpose:** Evaluate standalone web terminal applications as alternatives to building with xterm.js + Flask-SocketIO

---

## Executive Summary

**Embed-ttyd-via-iframe is the strongest alternative to building with xterm.js.** It eliminates all backend PTY code (Flask-SocketIO, pty.fork(), WebSocket bridging) at the cost of reduced UI integration and no programmatic session control from Python. For Watchtower's TermLink integration requirements (session tagging, orchestrator-aware terminals, programmatic attach/detach), the build approach retains critical advantages. But for a "just show me a terminal" MVP, ttyd-via-Traefik-plus-iframe is simpler, faster to ship, and battle-tested.

The other five solutions are either legacy (shellinabox), wrong architecture (Wetty's SSH dependency, GoTTY's single-command model), or massively over-engineered (code-server, Cockpit).

---

## 1. ttyd (C)

| Attribute | Value |
|-----------|-------|
| Language | C (libwebsockets + libuv) |
| Frontend | xterm.js (WebGL2) |
| GitHub stars | 11,352 |
| Latest release | v1.7.7 (2024-03-30) |
| Last commit | 2026-03-20 |
| License | MIT |
| Binary size | 1.36 MB (static, zero runtime deps) |
| Memory | ~2-5 MB base + ~1-2 MB/session |

### How It Works

ttyd is a standalone C binary that forks a PTY per WebSocket connection, relaying stdin/stdout between the browser (xterm.js) and the shell process. HTTP serves the initial page; WebSocket handles terminal I/O. Read-only by default since v1.7.4.

### Embedding in Watchtower

**Approach A — iframe (simplest):**
```html
<iframe src="/terminal/" style="width:100%;height:80vh;border:none;"></iframe>
```
ttyd runs as a sidecar process. Traefik routes `/terminal/*` to ttyd. Flask serves the page with the iframe. Zero coupling. iframe CORS issue was fixed in Nov 2021 (issue #803) with try/catch fallback — same-origin iframes work out of the box.

**Approach B — Traefik subpath (recommended for production):**
- ttyd: `ttyd -W -b /terminal -p 7681 bash`
- Traefik: `PathPrefix(/terminal)` -> ttyd:7681 + `StripPrefix` middleware
- Same origin as Watchtower -> no CORS, no mixed-content issues
- Flask page embeds via iframe or links directly to `/terminal`

Traefik natively supports WebSocket proxying (auto-detects `Upgrade` headers) — zero special middleware needed for WebSocket. ttyd's `--base-path` (max 128 chars) enables clean subpath mounting.

### Multi-Session

Each browser tab spawns an independent PTY. No built-in session registry or management UI. Shared sessions achievable via `ttyd tmux new -A -s shared`. `--max-clients N` caps connections (default 0 = unlimited). `--once` for single-use sessions.

### Customization & Theming

All xterm.js `ITerminalOptions` exposed via `-t key=value` or URL query params (query params take priority):

| Option | Example |
|--------|---------|
| Font size | `-t fontSize=16` |
| Theme | `-t theme={"background":"#1a1a2e","foreground":"#e0e0e0"}` |
| Font family | `-t fontFamily="Fira Code"` |
| Cursor | `-t cursorStyle=bar` |
| Line height | `-t lineHeight=1.2` |
| Renderer | `-t rendererType=canvas` (fallback from WebGL2) |
| Fixed title | `-t titleFixed="Watchtower Terminal"` |
| Disable resize overlay | `-t disableResizeOverlay=true` |
| Custom HTML | `--index /path/to/custom.html` (full UI override) |

Dark theme is the default. PicoCSS color matching via `theme` JSON — straightforward.

### Security

| Feature | Detail |
|---------|--------|
| Read-only default | Since v1.7.4. `-W` enables write. |
| Basic auth | `-c user:password` |
| Auth header proxy | `-H X-Auth-User` (delegate to Traefik ForwardAuth) |
| TLS | `-S --ssl-cert --ssl-key` (OpenSSL or Mbed TLS) |
| Mutual TLS | `-A ca.pem` (client certificates) |
| CSRF | `-O` / `--check-origin` |
| Privilege drop | `-u` / `-g` for UID/GID |
| Bind restriction | `-i lo` for localhost-only |

### Key CLI Flags

```
-p, --port 7681          Listen port (0 for random)
-W, --writable           Enable client input
-b, --base-path /path    Subpath for reverse proxy (max 128 chars)
-c, --credential u:p     Basic auth
-H, --auth-header        Proxy auth header
-m, --max-clients N      Connection limit (0=unlimited)
-o, --once               Single client, then exit
-q, --exit-no-conn       Exit when all clients disconnect
-t, --client-option k=v  xterm.js options (repeatable)
-I, --index file         Custom index.html
-O, --check-origin       CSRF protection
-w, --cwd dir            Working directory for child
-a, --url-arg            Allow URL-based command args
-P, --ping-interval 5    WebSocket keepalive (seconds)
-T, --terminal-type      TERM value (default: xterm-256color)
```

### Distribution

Homebrew, apt (Debian/Ubuntu), Snap, Docker (`tsl0922/ttyd` Alpine-based), WinGet, Scoop, static binaries on GitHub Releases. Ecosystem: cloudtty (K8s operator), Home Assistant add-on.

### Verdict: STRONG ALTERNATIVE

ttyd is the single strongest competitor to the build-with-xterm.js approach. Tiny footprint (1.36 MB binary), battle-tested (11.4k stars), MIT licensed, rich configuration, native Traefik compatibility. The iframe-embed path eliminates all backend PTY code from Watchtower. Main limitation: terminal is a black box — no programmatic control from Python.

---

## 2. Wetty (Node.js)

| Attribute | Value |
|-----------|-------|
| Language | TypeScript (Node.js + Express + Socket.IO) |
| Frontend | xterm.js v5.2 |
| GitHub stars | 5,227 |
| Latest release | v2.7.0 (2023-09-16) |
| Last commit | 2026-02-16 |
| License | MIT |
| Dependencies | 28 production npm packages |
| Memory | ~50-80 MB idle (Node.js baseline) |

### How It Works

Wetty bridges a browser WebSocket (Socket.IO) to an SSH connection or local PTY. When run as root, it spawns `/bin/login` directly. As non-root, it SSHes to localhost. The `--command` flag overrides the spawned process.

### The SSH Problem

Wetty's architecture routes terminal I/O through SSH even for localhost access (unless running as root). This adds:
- An SSH daemon dependency on the target host
- Authentication complexity (SSH keys/passwords managed separately)
- A latency hop for local sessions
- SSH configuration surface area

For Watchtower (terminal on the same host), SSH is unnecessary overhead.

### Embedding

- `--allow-iframe` enables iframe embedding (defaults to same-origin)
- `--base /wetty/` sets the subpath (default)
- Official `docker-compose.traefik.yml` in repo — Traefik is a first-class deployment target
- Official Docker image: `wettyoss/wetty`

### Multi-Session

Each WebSocket spawns an independent SSH/PTY session. No session registry, persistence, or management UI. WebSocket disconnect kills the session (no reconnect).

### Customization

- Theme: Dark / Light / Auto
- Terminal colors and fonts via xterm.js options
- Custom title via `--title`
- SCSS-based deeper customization (2.7% of codebase)
- On-screen keyboard controls (added May 2025)

### Security

Delegates to SSH authentication (password, public key, 2FA via PAM). TLS via `--ssl-key` / `--ssl-cert`. Helmet.js for HTTP security headers. No built-in OAuth/OIDC — must layer via reverse proxy.

### Resource Footprint

- Node.js 18+ runtime required
- 28 production npm dependencies (Express, Socket.IO, node-pty, Winston, Helmet)
- node-pty requires native compilation (build-essential, python, make)
- ~50-80 MB RSS idle, +10-20 MB per session
- Significantly heavier than ttyd for identical functionality

### Maintenance

Low-frequency but alive. Last tagged release is 2.5 years old (v2.7.0, Sep 2023), but commits continue into 2026 (Unix socket support added Feb 2026). Community PRs being merged. Mature/maintenance mode, not actively developed.

### Verdict: NOT RECOMMENDED

Wetty solves the wrong problem for Watchtower. The SSH layer adds complexity, latency, and dependencies unnecessary for local terminal access. ttyd does everything Wetty does with 1/20th the resource footprint and no SSH requirement. The only scenario where Wetty wins is remote SSH access to a different host — not our use case.

---

## 3. GoTTY (Go)

| Attribute | Value |
|-----------|-------|
| Language | Go |
| Frontend | xterm.js (sorenisanerd fork) / hterm (original) |
| Stars (original) | ~19,500 (yudai/gotty — abandoned since 2017) |
| Stars (fork) | ~2,500 (sorenisanerd/gotty — active) |
| Latest release | v1.6.0 (Aug 2025, fork) |
| License | MIT |
| Binary size | ~7 MB (static, embedded assets) |
| Memory | ~10-15 MB baseline (Go runtime) |

### How It Works

GoTTY wraps a single CLI command into a web application. Each browser connection spawns a new instance of that command with a PTY. Go HTTP server + WebSocket relay + embedded xterm.js (with WebGL support in the fork).

### The Single-Command Limitation

GoTTY runs **one command** specified at launch. `gotty -w bash` gives everyone a bash shell. You cannot dynamically change the command per-connection or per-user without running multiple GoTTY instances on different ports. `--permit-arguments` allows URL query params to append args, but this is limited.

### Maintenance Reality

| Repo | Stars | Last Release | Status |
|------|-------|-------------|--------|
| yudai/gotty | ~19,500 | v1.0.0 (May 2017) | **Effectively abandoned** since ~2017 |
| sorenisanerd/gotty | ~2,500 | v1.6.0 (Aug 2025) | **Actively maintained** — regular releases v1.1-v1.6 |

The original's 19.5k stars are misleading — that project is dead. The fork added ZModem file transfer (v1.4), Docker builds (v1.6), and WebGL rendering.

### Comparison to ttyd

| Factor | GoTTY (fork) | ttyd |
|--------|-------------|------|
| Binary size | ~7 MB | ~1.4 MB |
| Memory baseline | ~10-15 MB | ~2-5 MB |
| Packaging | GitHub releases, Go install | Homebrew, apt, snap, Docker, many distros |
| Base path | `--path` | `--base-path` |
| Client options | `--index` only | `-t key=value` per-option + `--index` |
| File transfer | ZModem (v1.4+) | ZModem + trzsz + Sixel |
| Community | ~2.5k stars | ~11.4k stars |
| CJK/IME | Yes | Yes (explicit feature) |

ttyd is GoTTY's spiritual successor — smaller, richer, better packaged.

### Security

- Read-only by default. `--permit-write` / `-w` enables input.
- Basic auth: `--credential user:pass`
- TLS: `--tls` with cert/key/CA. Client cert auth via `--tls-ca-crt`.
- `--random-url` for obscurity (appends random string)
- `--once` for single-use
- `--ws-origin` regex for WebSocket origin validation

### Verdict: VIABLE BUT INFERIOR TO TTYD

GoTTY works and the sorenisanerd fork is actively maintained. But ttyd does everything GoTTY does with a smaller binary, less memory, better packaging, more features, and a 4x larger community. No reason to choose GoTTY over ttyd for new deployments.

---

## 4. shellinabox (C)

| Attribute | Value |
|-----------|-------|
| Language | C |
| Frontend | CSS-based rendering (AJAX long-polling, NOT xterm.js) |
| GitHub stars | 3,100 |
| Latest release | v2.21 (Sep 2025) |
| License | **GPL-2.0** |
| Open issues | 202 |

### Why It's Legacy

shellinabox predates WebSocket and xterm.js. It renders terminal output as styled `<span>` elements via AJAX long-polling:

- No WebGL/canvas rendering — visibly inferior for heavy output
- No proper 256-color support or modern terminal features
- No smooth resize behavior
- A feature request for WebSocket support (issue #111) was never implemented
- The maintainers argued AJAX works better in restrictive networks — a niche argument

### Security Liability

Its own C HTTP stack has produced real CVEs:
- **CVE-2015-8400**: DNS rebinding via `/plain` fallback
- **CVE-2018-16789**: DoS via infinite loop on malformed multipart data

Running a custom C HTTP server for terminal access is a significant attack surface compared to battle-tested libraries (libwebsockets in ttyd).

### Multi-Session

One daemon serves multiple users (each gets a separate PTY). No session management UI.

### Verdict: DO NOT USE

GPL-2.0 licensing concern. Security liability (custom C HTTP stack with CVE history). Visually inferior CSS rendering. 202 open issues. shellinabox was innovative in 2010; in 2026 it is obsolete.

---

## 5. code-server Terminal (Node.js)

| Attribute | Value |
|-----------|-------|
| Language | TypeScript (Node.js) |
| Frontend | Full VS Code (xterm.js internally) |
| GitHub stars | 77,000 |
| Latest release | v4.114.0 (Apr 2026) |
| License | MIT |
| Min resources | 1 GB RAM, 2 vCPUs |

### The Extraction Problem

code-server's terminal is xterm.js connected through VS Code's terminal service layer, extension host IPC, and process management. **It cannot be extracted as a standalone component.** You must run the entire VS Code server stack to get its terminal.

The CodeTerminal project attempted extraction but was archived in 2022. Microsoft has an open issue (#34442) requesting standalone terminal extraction since 2017 — never implemented.

### Resource Reality

- Documented minimum: 1 GB RAM + 2 vCPUs
- Real-world: 500 MB-1 GB+ idle, CPU spikes from extension host (`bootstrap-fork.js`)
- Memory leak reports for v4.99+
- Full IDE infrastructure (file watcher, language services, extensions) running for a terminal

### Verdict: ABSURD FOR THIS USE CASE

Running a full VS Code server (1 GB+ RAM) to get an xterm.js terminal that you could embed directly for ~290 KB of JS + a 50-line Flask WebSocket handler. code-server's terminal IS xterm.js — we'd use code-server's dependency to avoid using that same dependency directly. Overhead ratio: ~100:1.

---

## 6. Cockpit Terminal (JS/Python/C)

| Attribute | Value |
|-----------|-------|
| Language | JS (35%), Python (33%), C (18%) |
| Frontend | xterm.js via cockpit.channel |
| GitHub stars | 13,900 |
| Latest release | v359 (Mar 2026) |
| License | **LGPL-2.1** |
| Maintainer | Red Hat |

### Embedding Path

Cockpit provides an iframe embedding example:
```
https://server:9090/cockpit/@localhost/system/terminal.html
```

Requires: full Cockpit installation (cockpit-ws + cockpit-bridge + cockpit-system), Cockpit on port 9090, PAM authentication, same-origin reverse proxy. Cross-origin embedding is "in heavy flux and not yet documented."

### The Platform Tax

Installing Cockpit for terminal access means:
- systemd socket units (cockpit.socket)
- PAM configuration
- Dual authentication (Cockpit's PAM + Watchtower's)
- LGPL-2.1 licensing considerations
- No programmatic terminal control from Python
- 200 MB+ for the full stack

Resource when idle: minimal (systemd socket activation — zero processes until accessed). But the installation/configuration footprint is heavy for what we get.

### Verdict: NOT PRACTICAL

Well-maintained (Red Hat backing, monthly releases) but wrong architecture. We'd install a full server management platform to iframe an xterm.js terminal. No programmatic session control. Dual authentication. LGPL licensing. Cockpit is excellent for what it is — it's just not a terminal embedding solution.

---

## Comparison Matrix

| Criterion | ttyd | Wetty | GoTTY | shellinabox | code-server | Cockpit |
|-----------|------|-------|-------|-------------|-------------|---------|
| **Language** | C | Node.js | Go | C | Node.js | JS/Python/C |
| **Frontend** | xterm.js | xterm.js | xterm.js | CSS/AJAX | xterm.js | xterm.js |
| **Stars** | 11.4k | 5.2k | 2.5k* | 3.1k | 77k | 13.9k |
| **Binary/footprint** | 1.4 MB | ~50-80 MB | ~7 MB | Low | 1 GB+ | 200 MB+ |
| **Memory/session** | ~1-2 MB | ~10-20 MB | ~5-10 MB | ~5 MB | N/A | ~20 MB |
| **Multi-session** | Yes (per-conn) | Yes (per-conn) | Yes (per-conn) | Yes | N/A | Yes |
| **Session management** | None built-in | None | None | None | VS Code | None |
| **Reverse proxy** | Native (--base-path) | Native (--base) | Fork only (--path) | Manual | Built-in | Same-origin req'd |
| **Traefik compat** | Excellent | Good (official compose) | Good | Poor (AJAX) | Good | Complex |
| **Auth options** | Basic, header, mTLS | SSH/PAM | Basic, TLS, mTLS | PAM, SSL | VS Code auth | PAM, Kerberos |
| **Read-only mode** | Default | No | Default | No | No | No |
| **Custom theme** | Full (-t flags + query params) | Limited | Via custom HTML | CSS overrides | VS Code themes | Limited |
| **License** | MIT | MIT | MIT | **GPL-2.0** | MIT | **LGPL-2.1** |
| **Maintenance** | Active (2026-03) | Maintenance | Active (fork, 2025-08) | Maintenance | Active | Active (Red Hat) |
| **Extractable** | N/A (standalone) | N/A (standalone) | N/A (standalone) | No | **No** | Iframe only |
| **SSH required** | No | **Yes** (non-root) | No | Optional | No | No |

*GoTTY stars: 19.5k for abandoned original; 2.5k for maintained fork.

### Scoring (1-5, 5=best for Watchtower)

| Criterion | ttyd | Wetty | GoTTY | shellinabox | code-server | Cockpit |
|-----------|------|-------|-------|-------------|-------------|---------|
| Embed simplicity | 5 | 4 | 3 | 2 | 1 | 2 |
| Customization | 5 | 3 | 2 | 1 | 1 | 1 |
| Resource footprint | 5 | 3 | 4 | 4 | 1 | 2 |
| Proxy compatibility | 5 | 4 | 4 | 2 | 1 | 2 |
| Maintenance/community | 5 | 3 | 3 | 2 | 5 | 4 |
| Security posture | 5 | 4 | 3 | 2 | 4 | 4 |
| License freedom | 5 | 5 | 5 | 2 | 5 | 3 |
| **Total** | **35** | **26** | **24** | **15** | **18** | **18** |

---

## The Key Question: Embed ttyd vs Build with xterm.js

### What embed-ttyd-via-iframe gives us

| Advantage | Detail |
|-----------|--------|
| **Zero backend PTY code** | No Flask-SocketIO, no pty.fork(), no WebSocket bridge. Eliminates ~200-400 lines of Python. |
| **Battle-tested terminal** | ttyd handles resize, encoding, signal propagation, PTY lifecycle — all solved problems. |
| **Instant deployment** | `ttyd -W -b /terminal bash` + one Traefik route. Ship in an hour. |
| **Security by default** | Read-only default, auth header proxy, origin checking — built-in, not hand-rolled. |
| **Independent scaling** | ttyd process is isolated from Flask. Terminal crash doesn't kill Watchtower. |
| **Proven at scale** | 11.4k stars, used in cloud platforms, K8s operators, Home Assistant. |

### What embed-ttyd-via-iframe costs us

| Loss | Impact | Severity |
|------|--------|----------|
| **No programmatic session control** | Cannot create/destroy/tag sessions from Python. Each iframe is independent. | **High** for TermLink |
| **No session registry** | Watchtower cannot list active terminals, show session metadata, or correlate with tasks. | **High** for orchestrator |
| **No custom protocol** | Cannot inject commands, read output, or bridge to TermLink events from Flask. | **High** for T-962 vision |
| **Iframe styling limits** | Terminal in iframe — cannot style with Watchtower's PicoCSS. `--index` helps but separate. | **Medium** |
| **Dual-process ops** | ttyd must be managed alongside Flask (systemd unit, health check, restart). | **Low** |
| **Auth boundary** | ttyd auth is separate from Watchtower auth. Traefik ForwardAuth bridges this. | **Medium** |
| **No tab-level control** | Multi-tab = multiple iframes. No server-side session list or tab sync. | **Medium** |

### Architecture Comparison

```
EMBED APPROACH (ttyd via iframe):
  Browser -> Traefik -> Flask (Watchtower pages)
                     -> ttyd (terminal WebSocket)  <- independent process
  
  Watchtower has NO visibility into terminal sessions.
  Terminal is a black box embedded in the UI.

BUILD APPROACH (xterm.js + Flask-SocketIO):
  Browser -> Traefik -> Flask (pages + terminal WebSocket)
                          |
                          +-> PTY manager (Python)
                          +-> Session registry
                          +-> TermLink bridge
  
  Watchtower OWNS the terminal sessions.
  Full programmatic control, session tagging, orchestrator integration.
```

### What We Gain by Building

| Capability | Embed (ttyd) | Build (xterm.js) |
|------------|-------------|-------------------|
| Terminal in page | iframe (isolated DOM) | Native DOM (shared CSS, events) |
| PicoCSS integration | Partial (theme JSON, iframe border) | Full (same stylesheet, seamless) |
| Programmatic control | None from Flask | Full (create, kill, resize, capture) |
| Output capture | None (opaque) | Yes (tap WebSocket stream) |
| TermLink integration | External (cross-process) | Direct (Python function call) |
| Multi-terminal tabs | Multiple iframes (heavy) | Single xterm.js with tab switching |
| Session metadata | None (no task tagging) | Full (T-XXX association) |
| Authentication | Separate (ttyd vs Flask) | Unified (Flask session = terminal auth) |

### What We Lose by Building

| Concern | Impact |
|---------|--------|
| Development time | 2-4 days vs 2 hours |
| Battle-tested WS handling | ttyd's libwebsockets vs Flask-SocketIO (good but less proven for terminal I/O) |
| Binary efficiency | C vs Python PTY bridge (negligible at terminal I/O speeds) |
| Maintenance burden | We own the code; ttyd is externally maintained |

### Decision Framework

| If your priority is... | Choose... | Because... |
|------------------------|-----------|------------|
| Ship fast, minimal code | **Embed ttyd** | Zero Python PTY code. One binary + one Traefik route. |
| TermLink integration | **Build with xterm.js** | Need programmatic session create/destroy/tag from Python. |
| Orchestrator-aware terminals | **Build with xterm.js** | Need session registry, task correlation, command injection. |
| Just a "run commands" UI | **Embed ttyd** | ttyd does this perfectly out of the box. |
| Multi-session management | **Build with xterm.js** | Need server-side session list, tab sync, metadata. |
| Minimal maintenance | **Embed ttyd** | C binary, zero deps, runs for months unattended. |
| PicoCSS visual integration | **Build with xterm.js** | Direct DOM access, no iframe boundary. |

### Hybrid Phased Approach

1. **Phase 1 (MVP):** Embed ttyd via iframe. Ship terminal access in one session. Validates UX, proves value.
2. **Phase 2 (Integration):** Replace iframe with xterm.js + Flask-SocketIO when TermLink/orchestrator features needed. UI patterns carry over; only the terminal widget changes.

This defers PTY bridge complexity (~200-400 lines of Python + WebSocket + process management) until proven necessary.

### Critical Insight

ttyd itself IS xterm.js + a PTY bridge + a WebSocket server. Building with xterm.js + Flask-SocketIO + Python pty is building the same architecture ttyd uses, but in our language and framework. The "build" path is not from-scratch — it replicates ttyd's proven architecture, integrated rather than standalone.

---

## Recommendation

**For T-962's stated scope (TermLink-integrated, orchestrator-aware terminals):** Build with xterm.js + Flask-SocketIO. The programmatic session control is essential for the vision.

**For a fast MVP to validate terminal-in-Watchtower UX:** Embed ttyd via Traefik. Ship in one session, evaluate whether orchestrator integration is actually needed.

**Do not use:** Wetty (SSH overhead), GoTTY (inferior to ttyd), shellinabox (legacy + GPL), code-server (absurd overhead), Cockpit (wrong architecture + LGPL).

**The honest answer to "is embed-ttyd simpler?":** Yes, dramatically. ttyd eliminates all backend terminal code. The question is whether Watchtower needs to *own* the terminal sessions or merely *display* them. For display: ttyd. For ownership: xterm.js.

---

## Sources

- [tsl0922/ttyd](https://github.com/tsl0922/ttyd) — GitHub, wiki, man page, releases
- [ttyd Client Options Wiki](https://github.com/tsl0922/ttyd/wiki/Client-Options)
- [ttyd Nginx Reverse Proxy Wiki](https://github.com/tsl0922/ttyd/wiki/Nginx-reverse-proxy)
- [ttyd iframe CORS Fix (Issue #803)](https://github.com/tsl0922/ttyd/issues/803)
- [web-ttyd-hub](https://github.com/kenkikuzuru/web-ttyd-hub) — multi-session ttyd wrapper
- [butlerx/wetty](https://github.com/butlerx/wetty) — GitHub, docs, Docker compose
- [Wetty Traefik compose](https://github.com/butlerx/wetty/blob/main/containers/docker-compose.traefik.yml)
- [wettyoss/wetty Docker Hub](https://hub.docker.com/r/wettyoss/wetty)
- [sorenisanerd/gotty](https://github.com/sorenisanerd/gotty) — maintained fork, releases
- [yudai/gotty](https://github.com/yudai/gotty) — original (abandoned)
- [yudai/gotty #258](https://github.com/yudai/gotty/issues/258) — "Is this project abandoned?"
- [shellinabox/shellinabox](https://github.com/shellinabox/shellinabox) — GitHub
- [shellinabox WebSocket request (#111)](https://github.com/shellinabox/shellinabox/issues/111)
- [shellinabox CVE history](https://www.cvedetails.com/product/33062/Shellinabox-Project-Shellinabox.html)
- [coder/code-server](https://github.com/coder/code-server) — GitHub, requirements
- [VS Code Terminal Extraction (#34442)](https://github.com/microsoft/vscode/issues/34442)
- [CodeTerminal (Archived)](https://github.com/xcodebuild/CodeTerminal)
- [cockpit-project/cockpit](https://github.com/cockpit-project/cockpit) — GitHub
- [Cockpit Embedding Guide](https://cockpit-project.org/guide/latest/embedding)
- [Cockpit Terminal Example](https://github.com/cockpit-project/cockpit/blob/main/examples/integrate-terminal/integrate-terminal.html)
- [Traefik WebSocket Documentation](https://doc.traefik.io/traefik/user-guides/websocket/)
- [GoTTY vs ttyd (SaaSHub)](https://www.saashub.com/compare-gotty-vs-ttyd)
- [HN: GoTTY/ttyd comparison](https://news.ycombinator.com/item?id=27326536)
