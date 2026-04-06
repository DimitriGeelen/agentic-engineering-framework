# T-962: OSS Web Terminal Libraries — Survey & Comparison

**Task:** T-962 (Inception — web terminal in Watchtower)
**Date:** 2026-04-06
**Purpose:** Evaluate libraries for embedding a browser-based terminal in Watchtower (Flask/Jinja + htmx + PicoCSS)

---

## Executive Summary

**xterm.js is the clear winner.** No other library provides real terminal emulation with PTY/WebSocket support, an active addon ecosystem, and framework-agnostic design. The alternatives are either command interpreters (jquery.terminal), hard to embed (hterm), or unmaintained toys. The decision is not close.

---

## 1. xterm.js

| Attribute | Value |
|-----------|-------|
| Latest version | **6.0.0** (2024-12-22) |
| GitHub stars | 20.2k |
| Forks | 1.9k |
| Open issues | 117 |
| Total commits | 10,873 |
| License | MIT |
| Bundle size | ~265 KB minified (reduced 30% from 379 KB in v5) |
| Dependencies | Zero runtime dependencies |
| Framework requirement | **None** — pure TypeScript/JS, no React/Vue/Angular needed |

### Notable Users
- **VS Code** (integrated terminal)
- **GitHub Codespaces**
- **Azure Cloud Shell**
- **JupyterLab**
- **Eclipse Che**
- **Replit**
- **SourceLair**

### Official Addons (13)

| Addon | Purpose | Relevance to Watchtower |
|-------|---------|------------------------|
| `@xterm/addon-attach` | WebSocket attachment to server process | **Critical** — PTY bridge |
| `@xterm/addon-fit` | Auto-resize terminal to container | **Critical** — responsive layout |
| `@xterm/addon-webgl` | WebGL2 GPU-accelerated rendering | **High** — performance for heavy output |
| `@xterm/addon-search` | Search terminal buffer | **High** — log inspection |
| `@xterm/addon-web-links` | Clickable URLs in output | **High** — UX |
| `@xterm/addon-web-fonts` | Custom font loading | Medium — consistent typography |
| `@xterm/addon-image` | Inline image rendering (iTerm2 protocol) | Medium — future enhancement |
| `@xterm/addon-ligatures` | Font ligature rendering | Low |
| `@xterm/addon-unicode11` | Unicode 11 character widths | Medium — internationalization |
| `@xterm/addon-unicode-graphemes` | Grapheme cluster support (experimental) | Low |
| `@xterm/addon-serialize` | Serialize buffer to VT sequences/HTML | Medium — session export |
| `@xterm/addon-clipboard` | Browser clipboard access | Medium |
| `@xterm/addon-progress` | OSC 9;4 progress bar support | Low |

Also provides `@xterm/headless` for Node.js server-side terminal emulation (useful for testing).

### v6.0.0 Breaking Changes (relevant)
- Canvas renderer addon **removed** — WebGL is now the primary GPU renderer
- `windowsMode` option removed
- Alt key handling changes
- Migration from yarn to npm

### Integration with Flask/Jinja + htmx

xterm.js works perfectly without a JS framework:

```html
<!-- Minimal integration -->
<link rel="stylesheet" href="/static/xterm.css">
<script src="/static/xterm.js"></script>
<script src="/static/xterm-addon-attach.js"></script>
<script src="/static/xterm-addon-fit.js"></script>

<div id="terminal"></div>
<script>
  const term = new Terminal({ cursorBlink: true });
  const fitAddon = new FitAddon.FitAddon();
  term.loadAddon(fitAddon);
  term.open(document.getElementById('terminal'));
  fitAddon.fit();

  // WebSocket to Flask backend (via flask-sock or similar)
  const ws = new WebSocket(`ws://${location.host}/ws/terminal`);
  const attachAddon = new AttachAddon.AttachAddon(ws);
  term.loadAddon(attachAddon);
</script>
```

**Multi-session support:** Create multiple `Terminal` instances, each with its own WebSocket connection. Tab UI is application-level (Watchtower already has tab patterns).

### Verdict: RECOMMENDED

- Industry standard, battle-tested at massive scale (VS Code alone = millions of users)
- Zero framework dependencies — works with vanilla JS + Flask/Jinja
- Rich addon ecosystem covers all requirements
- Active maintenance with monthly releases
- MIT license — no concerns
- WebSocket PTY attachment is a first-class, officially supported addon

---

## 2. hterm (Google/Chromium)

| Attribute | Value |
|-----------|-------|
| Source | `chromium.googlesource.com/apps/libapps` |
| GitHub mirrors | Archived ("MOVED: Please use the new libapps repo") |
| npm package | Unofficial community packages only |
| License | BSD-3-Clause |
| Bundle | Single `hterm_all.js` file (built via `mkdist`) |
| Framework requirement | None (vanilla JS) |

### Embedding Process
1. Clone entire `libapps` repository
2. Run `./hterm/bin/mkdist` to generate `hterm_all.js`
3. Configure storage backend (localStorage, in-memory, or Chrome storage)
4. Call `lib.init()` before creating terminal
5. Instantiate `hterm.Terminal` with profile ID

### Strengths
- Real terminal emulator (xterm-compatible)
- Used in Chrome OS Secure Shell (proven at scale)
- Maintained by Google (ongoing commits in libapps)
- Good VT100/ANSI compatibility

### Weaknesses
- **No npm package** — must build from source (libapps monorepo)
- **No addon ecosystem** — everything is monolithic
- **Google-internal build system** — not designed for third-party embedding
- **No community** — GitHub mirrors are archived, discussion on chromium-hterm mailing list only
- **No WebSocket addon** — must implement your own bridge
- **No resize/fit helper** — must implement manually
- **Documentation assumes Chrome extension context** — embedding docs are sparse

### Verdict: NOT RECOMMENDED

hterm is a capable terminal emulator trapped inside Google's internal tooling ecosystem. The embedding overhead, lack of npm distribution, missing addon ecosystem, and no community support make it impractical for Watchtower. Every problem hterm solves, xterm.js solves better with less friction.

---

## 3. jquery.terminal

| Attribute | Value |
|-----------|-------|
| Latest version | 2.45.2 |
| GitHub stars | 3.2k |
| License | MIT |
| npm package | `jquery.terminal` |
| Framework requirement | **jQuery** (hard dependency) |

### What It Actually Is

The author's own README states:

> "Because with this library you need to code all the commands yourself, you can call it fake terminal emulator."

It then recommends xterm.js for "real online SSH."

jquery.terminal is a **command-line interpreter UI**, not a terminal emulator. It renders a prompt, accepts text input, and dispatches to JavaScript handler functions or JSON-RPC endpoints. It does NOT:

- Parse VT100/ANSI escape sequences
- Support PTY streams
- Handle WebSocket terminal I/O
- Render 256 colors from a real shell
- Process cursor movement / terminal modes

### Strengths
- Simple API for building custom CLI-like interfaces
- Good for interactive docs, chatbots, or game consoles
- Active maintenance

### Weaknesses
- **Not a terminal emulator** — cannot connect to a real shell
- **No PTY/WebSocket support** — fundamentally incompatible with our use case
- **jQuery dependency** — Watchtower uses htmx, not jQuery
- **No escape sequence parsing** — cannot render real terminal output

### Verdict: WRONG TOOL

jquery.terminal solves a completely different problem. It's for building custom command prompts, not for connecting to real terminals. Disqualified.

---

## 4. Other Alternatives Surveyed

### terminal.js (npm: `terminal.js` v1.0.11)
- Self-described as "terminal emulation library"
- Works in browser and Node.js
- **No PTY support, no WebSocket, no addon ecosystem**
- Tiny community (~no stars)
- Verdict: **Toy project, not viable**

### web-termjs (npm: `web-termjs`)
- "Terminal emulator for browsers"
- Minimal GitHub activity
- No documentation on PTY/WebSocket integration
- Verdict: **Abandoned, not viable**

### Butterfly (Python)
- xterm-compatible, WebSocket + Tornado backend
- Interesting but **tightly coupled to its own Python backend** — not embeddable as a JS library
- Would conflict with Flask (wants its own server)
- Verdict: **Wrong architecture** — we need a client library, not a full application

### javascript-terminal
- In-memory terminal emulator for browser/Node
- No real PTY support — simulates a filesystem in JS
- Designed for portfolio sites and demos
- Verdict: **Demo tool, not viable**

### jQuery-based alternatives (Shell.js, jq-console, KonsoleJS, jsShell.js, Jaxit)
- All are command interpreters / themed prompt UIs
- None support real PTY connections
- All require jQuery
- Verdict: **Same disqualification as jquery.terminal**

### xterm.es (ES fork of xterm.js)
- Community fork with ES module support
- Very low activity, trails main xterm.js significantly
- Verdict: **Use the original**

---

## Comparison Matrix

| Criterion | xterm.js | hterm | jquery.terminal | terminal.js |
|-----------|----------|-------|-----------------|-------------|
| Real terminal emulation | Yes | Yes | **No** | Partial |
| PTY/WebSocket support | Yes (addon) | DIY | **No** | **No** |
| npm package | Yes | **No** | Yes | Yes |
| Framework-agnostic | Yes | Yes | jQuery req'd | Yes |
| Addon ecosystem | 13 official | **None** | Plugins | **None** |
| Resize/fit helper | Yes (addon) | **DIY** | N/A | **No** |
| GPU rendering | WebGL2 | **No** | N/A | **No** |
| 256 color support | Yes | Yes | **No** | **No** |
| Unicode/grapheme | Yes | Yes | Limited | **No** |
| Search in buffer | Yes (addon) | **No** | N/A | **No** |
| GitHub stars | 20.2k | N/A | 3.2k | ~0 |
| License | MIT | BSD-3 | MIT | MIT |
| Active maintenance | Yes (monthly) | Yes (Google) | Yes | **No** |
| Used in production | VS Code, GitHub | Chrome OS | Websites | — |
| Multi-session capable | Yes | Yes | N/A | **No** |

---

## Recommendation

**Use xterm.js v6.x** with these addons:

1. `@xterm/addon-attach` — WebSocket PTY bridge
2. `@xterm/addon-fit` — responsive resize
3. `@xterm/addon-webgl` — GPU-accelerated rendering
4. `@xterm/addon-search` — buffer search
5. `@xterm/addon-web-links` — clickable URLs

### Backend Architecture (Flask side)
- Use `flask-sock` or `simple-websocket` for WebSocket support
- Bridge WebSocket to PTY via `pty.fork()` or `pexpect`
- One PTY per WebSocket connection = one terminal session
- Multi-tab = multiple WebSocket connections to separate PTY processes

### Estimated Bundle Cost
- `@xterm/xterm`: ~265 KB minified (~80 KB gzipped est.)
- `@xterm/addon-attach`: ~5 KB
- `@xterm/addon-fit`: ~5 KB
- `@xterm/addon-webgl`: ~50 KB (optional, canvas fallback exists)
- `@xterm/addon-search`: ~10 KB
- `@xterm/addon-web-links`: ~5 KB
- **Total (without WebGL):** ~290 KB minified, ~95 KB gzipped est.
- **Total (with WebGL):** ~340 KB minified, ~110 KB gzipped est.

This is acceptable for Watchtower — a single-purpose ops dashboard, not a public-facing site where every KB matters.

---

## Sources

- [xterm.js GitHub](https://github.com/xtermjs/xterm.js/)
- [xterm.js official site](https://xtermjs.org/)
- [xterm.js releases](https://github.com/xtermjs/xterm.js/releases)
- [hterm source (chromium)](https://chromium.googlesource.com/apps/libapps/+/master/hterm)
- [hterm embedding docs](https://chromium.googlesource.com/apps/libapps/+/master/hterm/doc/embed.md)
- [jquery.terminal GitHub](https://github.com/jcubic/jquery.terminal)
- [jquery.terminal site](https://terminal.jcubic.pl/)
- [JS terminal emulator roundup (2026)](https://www.jqueryscript.net/blog/best-terminal-emulator.html)
