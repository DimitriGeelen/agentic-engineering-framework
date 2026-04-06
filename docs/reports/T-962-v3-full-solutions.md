# T-962 Vector 3: Full-Solution Web Terminal Tools — Evaluation Report

**Task:** T-962 (Web Terminal in Watchtower)
**Vector:** 3 — Existing Full Solutions
**Date:** 2026-04-06
**Status:** COMPLETE

## Executive Summary

Six existing web terminal solutions were evaluated for potential embedding in or proxying through Watchtower (Flask). **ttyd is the clear winner** for an embed/proxy strategy — it is the most lightweight (~5MB binary, <50MB RAM), actively maintained (11.4k stars, MIT license), fully customizable via xterm.js options, and proxy-friendly with `--base-path` and WebSocket support that works natively with Traefik. The iframe CORS issue was fixed in 2021.

However, **the embed approach has a hard ceiling**: ttyd gives you isolated terminal windows, not an integrated terminal component within the Watchtower DOM. For deep integration (shared theming, programmatic session control, terminal output capture, TermLink coordination), building with xterm.js + a Python PTY bridge remains superior. The recommended path is: **build the core with xterm.js + Flask-SocketIO for deep integration, but keep ttyd as a fallback/quick-win for simple use cases** (e.g., a "pop-out terminal" link).

---

## 1. ttyd (C)

**Repository:** https://github.com/tsl0922/ttyd
**Stars:** 11.4k | **License:** MIT | **Language:** C (56%), TypeScript (26%)
**Latest Release:** v1.7.7 (March 2024) | **Status:** Actively maintained

### Architecture

ttyd is a lightweight WebSocket-based terminal server built on three pillars:
- **libwebsockets** — High-performance C WebSocket server library
- **libuv** — Cross-platform async I/O (same event loop as Node.js)
- **xterm.js** — Browser-side terminal emulation with WebGL2 rendering

Each client connection spawns a new PTY process running the specified command. The WebSocket protocol relays raw terminal I/O bidirectionally. The entire binary is ~5MB statically compiled.

### Embedding via iframe / Reverse Proxy

**iframe embedding:** Works since v1.6.0+. A CORS issue with `window.top` access was reported (issue #803) and **fixed in November 2021** with try/catch fallback logic. Same-origin iframes work out of the box; cross-origin requires proper `X-Frame-Options` / CSP `frame-ancestors` headers.

**Reverse proxy:** First-class support via `--base-path` flag. Example for serving under `/terminal`:
```
ttyd --base-path /terminal -p 7681 bash
```
Nginx config well-documented in wiki. Requires WebSocket upgrade headers (`Upgrade`, `Connection`).

**Traefik compatibility:** Traefik auto-detects WebSocket connections — no special middleware needed. ttyd + Traefik is a zero-config combination for the WebSocket layer.

**Flask proxy:** Flask cannot natively proxy WebSocket connections. Two options:
1. **Traefik routes `/terminal` directly to ttyd** (bypassing Flask) — simple, recommended
2. **Flask serves an iframe** pointing to `ttyd_host:port` — works but cross-origin considerations apply

### Multi-Session Support

By default, each browser connection gets its own PTY process — true multi-session. The `--max-clients` flag controls concurrency (default: unlimited). For shared sessions, ttyd can wrap tmux (`ttyd tmux new -A -s shared`).

### Customization

Full xterm.js `ITerminalOptions` exposed via `-t` flags or URL query parameters:
- `fontSize`, `fontFamily`, `lineHeight` — typography
- `theme={"background":"#1a1a2e","foreground":"#e0e0e0"}` — full color theming
- `cursorStyle` (block/bar/underline), `cursorBlink`
- `enableSixel` — image rendering in terminal
- Custom `index.html` via `--index` flag for complete UI override

Theming to match PicoCSS dark theme is straightforward via the `theme` JSON option.

### Resource Footprint

- Binary size: ~5MB (static)
- Memory: <50MB baseline, ~2-5MB per additional session
- CPU: Negligible (C + libuv event loop)
- Docker image: ~15MB (Alpine-based)

### Security

- Basic auth via `--credential user:pass`
- Auth proxy support via `--auth-header` (delegate to Traefik/nginx)
- SSL/TLS via `--ssl`, `--ssl-cert`, `--ssl-key`
- Origin checking via `--check-origin`
- Read-only mode via `--readonly` (default; `--writable` to enable input)
- Max client limiting via `--max-clients`

### Distribution

Available via: Homebrew, apt (Debian/Ubuntu), Snap, Docker, WinGet, Scoop, static binaries on GitHub Releases. Extremely easy to deploy.

### Verdict

**Best embed candidate.** Lightweight, well-maintained, MIT-licensed, excellent proxy support. The main limitation is that embedding via iframe means the terminal is a black box — no programmatic control from the Watchtower JavaScript layer.

---

## 2. Wetty (Node.js)

**Repository:** https://github.com/butlerx/wetty
**Stars:** 5.2k | **License:** MIT | **Language:** TypeScript (65%), JavaScript (28%)
**Latest Release:** v2.7.0 (September 2023) | **Status:** Slower-paced maintenance

### Architecture

Wetty is a Node.js application using:
- **xterm.js** — Browser terminal emulation
- **WebSockets** — Real-time I/O (replaced older AJAX approach)
- **node-pty or SSH** — Backend terminal process

### SSH Requirement

**No, SSH is not strictly required.** When run as root with the host set to localhost, Wetty uses `/bin/login` directly (local PTY mode). The `--force-ssh` flag forces SSH even as root. The `--command` flag can override the default shell entirely.

However, Wetty's primary design intent is SSH-over-HTTP. Local PTY mode is a secondary path.

### Embedding

Supports iframe embedding via `--allow-iframe` flag (defaults to same-origin). Well-suited for embedding in other web applications.

### Multi-Session

WebSocket architecture supports concurrent connections. Each connection gets its own session (SSH or login). No explicit `--max-clients` equivalent found in documentation.

### Customization

Limited compared to ttyd. The xterm.js instance is not exposed for direct configuration via CLI flags in the same comprehensive way. Custom CSS/themes require modifying the application or using the Docker image with volume mounts.

### Reverse Proxy Compatibility

Documentation includes Traefik and nginx-proxy examples for Docker Compose deployments. Base path configuration supported.

### Resource Footprint

- Requires Node.js 18+ runtime
- `node_modules` adds significant disk footprint (~100MB+)
- Memory: ~50-100MB baseline for Node.js process
- Higher per-session overhead than ttyd due to Node.js runtime

### Security

- SSH-based authentication (when using SSH mode)
- `/bin/login` PAM authentication (when running as root locally)
- HTTPS via reverse proxy or `--ssl-*` flags
- Same-origin iframe policy

### Verdict

Solid tool but **heavier than ttyd** for the same outcome. The Node.js dependency adds complexity. Best suited for teams already running Node.js infrastructure or needing SSH gateway functionality specifically.

---

## 3. GoTTY (Go)

**Repository:** https://github.com/sorenisanerd/gotty (maintained fork)
**Original:** https://github.com/yudai/gotty (archived)
**Stars:** 2.5k (fork) / 18.6k (original) | **License:** MIT | **Language:** Go
**Status:** Community-maintained fork; original abandoned

### Architecture

Go binary providing a WebSocket server that relays TTY I/O. Uses xterm.js on the frontend. Each client connection spawns a new process with the specified command.

### Maintenance Concern

The original yudai/gotty has not been maintained since ~2017. The sorenisanerd fork continues development but has 20 open issues and 14 open PRs, suggesting moderate but not vigorous maintenance. No release date visible for the fork.

### Read-Only vs Read-Write

**Read-only by default** — clients can only view terminal output. The `-w` flag enables write access. This is useful for sharing dashboards but requires explicit opt-in for interactive terminals.

### Multi-Session

Each client connection gets a new process by default. For shared sessions, GoTTY recommends wrapping tmux or screen. No built-in session management.

### Embedding

Supports custom `--index` HTML file. No explicit iframe embedding flag. The `--path` option sets a base URL path for reverse proxy integration.

### Customization

Limited to custom `index.html`. No CLI-level xterm.js option passthrough like ttyd's `-t` flags.

### Resource Footprint

- Single Go binary (~10-15MB)
- Low memory usage (~20-50MB)
- Efficient goroutine-per-connection model

### Verdict

**Not recommended.** Uncertain maintenance, fewer features than ttyd, no advantage over ttyd in any dimension. The original project's GitHub star count is misleading — it reflects historical popularity, not current viability.

---

## 4. shellinabox

**Repository:** https://github.com/shellinabox/shellinabox (community fork)
**Stars:** 3.1k | **License:** GPL-2.0 | **Language:** C
**Latest Release:** v2.21 (September 2025) | **Status:** Legacy maintenance

### Architecture

**AJAX-based** — not WebSocket. shellinabox uses long-polling HTTP requests to relay terminal I/O. It implements its own VT100 terminal emulator in JavaScript (not xterm.js). This is a fundamentally older architecture.

A feature request for WebSocket support (issue #111) was never implemented. The maintainers argued AJAX works better in restrictive network environments where WebSockets are blocked.

### Security Record

202 open issues suggest accumulated technical debt. No CVEs found in the provided security section, but the AJAX architecture has a larger attack surface than WebSocket (more HTTP requests, more parsing). The GPL-2.0 license is also more restrictive than MIT.

### Customization

Custom VT100 emulator means no xterm.js ecosystem compatibility. Theming is limited to CSS of the emulator container. No programmatic terminal control APIs.

### Verdict

**Not recommended.** Legacy AJAX architecture, custom (non-xterm.js) terminal emulation, GPL-2.0 license, and 202 open issues. Every modern tool in this evaluation is superior. shellinabox should be considered end-of-life for new projects.

---

## 5. code-server Terminal (VS Code in Browser)

**Repository:** https://github.com/coder/code-server
**Stars:** 70k+ | **License:** MIT | **Language:** TypeScript

### Architecture

code-server runs the full VS Code editor in a browser. The integrated terminal is built on xterm.js with node-pty for the PTY backend — the same stack we would build from scratch.

### Can We Extract Just the Terminal?

**No, not practically.** The terminal component is deeply coupled to VS Code's:
- Extension host and IPC protocol
- Workspace/session management
- Settings/configuration system
- Layout/panel framework

The **CodeTerminal** project (https://github.com/xcodebuild/CodeTerminal) attempted extraction but:
- Archived in September 2022 (read-only)
- Built as an Electron desktop app, not a web component
- 657 stars but no active maintenance
- Cannot be used in a web application

Microsoft has an open issue (#34442) requesting standalone terminal extraction since 2017 — never implemented.

### Resource Footprint

code-server requires 1-2GB RAM minimum for the full VS Code process. Completely disproportionate for "just a terminal."

### Verdict

**Not viable.** The terminal cannot be extracted from code-server without rebuilding most of VS Code's infrastructure. The resource footprint is 20-40x what a dedicated terminal solution requires. However, code-server proves that xterm.js + node-pty is a battle-tested stack at scale.

---

## 6. Cockpit Terminal (Red Hat)

**Repository:** https://github.com/cockpit-project/cockpit
**Stars:** 11.5k | **License:** LGPL-2.1 | **Language:** C, JavaScript, Python

### Architecture

Cockpit is a full server management UI. Its terminal component:
- Runs as part of `cockpit-ws` (WebSocket server written in C)
- Uses a custom terminal widget (not standard xterm.js)
- Communicates via Cockpit's own message protocol over WebSocket
- Requires `cockpit-bridge` on the target machine for shell access

### Embeddability

Cockpit explicitly supports embedding individual components via iframe:
```
/cockpit/@localhost/system/terminal.html
```

**Critical caveat:** "This only works if Cockpit and the web application have the same origin" — requires a shared reverse proxy. Cross-origin embedding requires deep integration (custom auth, message relay) which is "in heavy flux and not yet documented."

### Standalone Capability

**Cannot run standalone.** The terminal component requires:
1. `cockpit-ws` running on port 9090
2. `cockpit-bridge` installed on the target
3. PAM/Kerberos authentication configured
4. systemd integration (Linux-specific)

This is a full system management stack, not an embeddable component.

### Resource Footprint

- `cockpit-ws`: ~30-50MB RAM
- `cockpit-bridge`: ~20-30MB RAM
- Plus all system management packages
- Total: 200MB+ for the full Cockpit stack

### Verdict

**Not practical for Watchtower.** Cockpit's terminal requires the full Cockpit stack (cockpit-ws, cockpit-bridge, PAM auth, systemd). The iframe embedding only works same-origin. Deep integration is undocumented and "in heavy flux." The LGPL-2.1 license adds compliance overhead. Massive overkill for our use case.

---

## Comparison Matrix

| Criterion | ttyd | Wetty | GoTTY | shellinabox | code-server | Cockpit |
|-----------|------|-------|-------|-------------|-------------|---------|
| **Language** | C | Node.js | Go | C | TypeScript | C/JS/Python |
| **Terminal Frontend** | xterm.js | xterm.js | xterm.js | Custom VT100 | xterm.js | Custom |
| **Protocol** | WebSocket | WebSocket | WebSocket | AJAX | WebSocket | WebSocket |
| **License** | MIT | MIT | MIT | GPL-2.0 | MIT | LGPL-2.1 |
| **Stars** | 11.4k | 5.2k | 2.5k | 3.1k | 70k+ | 11.5k |
| **Latest Release** | Mar 2024 | Sep 2023 | Unknown | Sep 2025 | Active | Active |
| **Binary Size** | ~5MB | ~100MB+ (node_modules) | ~10MB | ~2MB | ~500MB+ | ~200MB+ |
| **RAM (baseline)** | <50MB | ~50-100MB | ~20-50MB | ~20MB | 1-2GB | 200MB+ |
| **RAM (per session)** | ~2-5MB | ~10-20MB | ~5-10MB | ~5MB | N/A | ~20MB |
| **Multi-Session** | Yes (default) | Yes | Yes (default) | Yes | N/A | Yes |
| **iframe Embed** | Yes (fixed 2021) | Yes (--allow-iframe) | No flag | No | N/A | Same-origin only |
| **Reverse Proxy** | Excellent (--base-path) | Good | Good (--path) | Limited | N/A | Same-origin required |
| **Traefik Compat** | Native (auto WebSocket) | Good | Good | Poor (AJAX) | N/A | Complex |
| **xterm.js Theming** | Full (via -t flags) | Limited | Limited | None | N/A | None |
| **Auth Options** | Basic, proxy header, SSL | SSH, PAM, proxy | Basic, SSL | PAM, SSL | Full VS Code | PAM, Kerberos |
| **Custom index.html** | Yes (--index) | No | Yes (--index) | No | No | No |
| **Read-Only Mode** | Yes (default) | No | Yes (default) | No | No | No |
| **File Transfer** | Zmodem, trzsz | No | No | No | Yes | No |
| **Maintenance** | Active | Slower | Uncertain | Legacy | Active | Active |

**Scoring (1-5, 5=best for Watchtower use case):**

| Criterion | ttyd | Wetty | GoTTY | shellinabox | code-server | Cockpit |
|-----------|------|-------|-------|-------------|-------------|---------|
| Embed simplicity | 5 | 4 | 3 | 2 | 1 | 2 |
| Customization | 5 | 3 | 2 | 1 | 1 | 1 |
| Resource footprint | 5 | 3 | 4 | 4 | 1 | 2 |
| Proxy compatibility | 5 | 4 | 4 | 2 | 1 | 2 |
| Maintenance/community | 5 | 3 | 2 | 2 | 5 | 4 |
| Security posture | 5 | 4 | 3 | 2 | 4 | 4 |
| License freedom | 5 | 5 | 5 | 2 | 5 | 3 |
| **Total** | **35** | **26** | **23** | **15** | **18** | **18** |

---

## Build vs Embed Analysis

### What "Embed ttyd" Looks Like

```
[Browser] --> [Traefik :443] --> [Watchtower Flask :5050] (HTML pages)
                             \-> [ttyd :7681] (WebSocket terminal, under /terminal path)
```

Watchtower serves a page with `<iframe src="/terminal">`. Traefik routes `/terminal/*` to ttyd and everything else to Flask. ttyd runs as a systemd service alongside Watchtower.

**Effort:** ~2 hours (install ttyd, add Traefik route, add iframe page to Watchtower).

### What "Build with xterm.js" Looks Like

```
[Browser] --> [Traefik :443] --> [Watchtower Flask :5050]
                                    |
                                    +-- Flask-SocketIO (WebSocket)
                                    +-- Python PTY bridge (pty module)
                                    +-- xterm.js (integrated in page DOM)
```

Watchtower serves a page with xterm.js rendered directly in the DOM. Flask-SocketIO handles the WebSocket connection. A Python PTY bridge spawns and manages shell processes.

**Effort:** ~2-4 days (PTY bridge, SocketIO integration, session management, error handling, testing).

### What We Gain by Building

| Capability | Embed (ttyd) | Build (xterm.js) |
|------------|-------------|-------------------|
| Terminal in page | iframe (isolated DOM) | Native DOM (shared CSS, events) |
| PicoCSS theme integration | Partial (ttyd theme JSON, but iframe border) | Full (same stylesheet, seamless) |
| Programmatic session control | None from Flask | Full (create, kill, resize, capture output) |
| Output capture/logging | None (ttyd is opaque) | Yes (tap WebSocket stream) |
| TermLink integration | External (ttyd session != TermLink session) | Direct (Python PTY bridge can wrap TermLink) |
| Multi-terminal tabs | Multiple iframes (heavy) | Single xterm.js with tab switching (light) |
| Session metadata | None (ttyd has no concept of task-tagged sessions) | Full (associate sessions with T-XXX tasks) |
| Resize behavior | iframe resize = complex | Native DOM resize = simple |
| Authentication | Separate (ttyd auth vs Flask auth) | Unified (Flask session = terminal auth) |
| Error handling | ttyd errors stay in ttyd | Unified error handling with Watchtower |

### What We Lose by Building

| Concern | Impact |
|---------|--------|
| Development time | 2-4 days vs 2 hours |
| Battle-tested WebSocket handling | ttyd's libwebsockets is rock-solid; Flask-SocketIO is good but less proven for high-throughput terminal I/O |
| Binary efficiency | ttyd's C is faster than Python PTY bridge (though difference is negligible for terminal I/O speeds) |
| Maintenance burden | We own the PTY bridge code; ttyd is externally maintained |

### The Honest Assessment

The embed approach (ttyd via iframe) is **faster to ship** but creates an **integration ceiling**:
- The terminal lives in its own DOM, so it cannot share Watchtower's CSS, event system, or JavaScript context
- Session management requires coordinating two separate processes (Flask + ttyd)
- TermLink integration becomes a cross-process coordination problem instead of a library call
- Multi-session UX (tabs, split views) means managing multiple iframes, each with its own WebSocket connection

The build approach (xterm.js + Flask-SocketIO) takes **longer initially** but gives **full control**:
- Terminal is a first-class Watchtower component, not a foreign embed
- Session lifecycle is managed by Python, where all our other tooling lives
- TermLink integration is a Python function call, not a cross-process protocol
- The same xterm.js that powers ttyd, Wetty, GoTTY, VS Code, and every modern web terminal

**Critical insight:** ttyd itself is xterm.js + a PTY bridge + a WebSocket server. Building with xterm.js + Flask-SocketIO + Python pty is building the same architecture ttyd uses, but in our language and framework. The "build" path is not building from scratch — it is building the same architecture ttyd uses, integrated rather than standalone.

---

## Recommendation

### Primary Path: Build with xterm.js + Flask-SocketIO

For Watchtower's web terminal feature, build the terminal component using:
- **xterm.js** (frontend) — same battle-tested library used by all the tools evaluated
- **Flask-SocketIO** (WebSocket transport) — already compatible with our Flask stack
- **Python `pty` module** (PTY bridge) — standard library, no dependencies

This gives full integration with Watchtower's DOM, theming, session management, and TermLink.

### Secondary Path: ttyd as Quick-Win / Fallback

Keep ttyd in the toolbox for:
- **"Pop-out terminal" feature** — a link that opens ttyd in a new tab (no iframe needed)
- **Rapid prototyping** — spin up ttyd to test terminal UX before building the integrated version
- **Fallback** — if the Python PTY bridge proves unreliable, ttyd is a proven alternative

### Not Recommended

- **Wetty** — heavier than ttyd, Node.js dependency, no advantage for our use case
- **GoTTY** — uncertain maintenance, fewer features than ttyd
- **shellinabox** — legacy AJAX architecture, GPL license, custom terminal emulation
- **code-server** — cannot extract terminal, massive resource overhead
- **Cockpit** — requires full stack, same-origin only, LGPL license, overkill

---

## Sources

- [ttyd GitHub Repository](https://github.com/tsl0922/ttyd)
- [ttyd Official Documentation](https://tsl0922.github.io/ttyd/)
- [ttyd Client Options Wiki](https://github.com/tsl0922/ttyd/wiki/Client-Options)
- [ttyd Nginx Reverse Proxy Wiki](https://github.com/tsl0922/ttyd/wiki/Nginx-reverse-proxy)
- [ttyd iframe CORS Fix (Issue #803)](https://github.com/tsl0922/ttyd/issues/803)
- [Wetty GitHub Repository](https://github.com/butlerx/wetty)
- [Wetty Flags Documentation](https://butlerx.github.io/wetty/flags.html)
- [GoTTY Maintained Fork](https://github.com/sorenisanerd/gotty)
- [GoTTY Original Repository](https://github.com/yudai/gotty)
- [shellinabox GitHub Repository](https://github.com/shellinabox/shellinabox)
- [shellinabox WebSocket Feature Request (Issue #111)](https://github.com/shellinabox/shellinabox/issues/111)
- [code-server GitHub Repository](https://github.com/coder/code-server)
- [VS Code Terminal Extraction Request (Issue #34442)](https://github.com/microsoft/vscode/issues/34442)
- [CodeTerminal (Archived)](https://github.com/xcodebuild/CodeTerminal)
- [Cockpit Embedding Documentation](https://cockpit-project.org/guide/latest/embedding)
- [Cockpit Terminal Integration Example](https://github.com/cockpit-project/cockpit/blob/main/examples/integrate-terminal/integrate-terminal.html)
- [Traefik WebSocket Documentation](https://doc.traefik.io/traefik/user-guides/websocket/)
- [xterm.js ITerminalOptions](https://xtermjs.org/docs/api/terminal/interfaces/iterminaloptions/)
