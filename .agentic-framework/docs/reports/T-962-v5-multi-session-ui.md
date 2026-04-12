# T-962 v5: Multi-Session Terminal UI Patterns — Survey & Recommendation

**Task:** T-962 (Inception — web terminal in Watchtower)
**Date:** 2026-04-06
**Purpose:** Survey multi-session terminal UI patterns across industry tools, recommend a UI architecture for Watchtower (Flask/Jinja + htmx + PicoCSS), and define a session data model that supports future multi-provider agent sessions.

---

## Executive Summary

Six tools were studied across four categories: IDE terminals (VS Code, JupyterLab), container/infrastructure consoles (Portainer, Cockpit), desktop terminal emulators (Tabby), and browser-terminal bridges (GoTTY, ttyd, Muxplex). The recommended Watchtower pattern is a **sidebar session list + tabbed main area** with lifecycle badges, profile-based creation, and a session data model that carries provider metadata from day one. The design uses htmx for session switching (no SPA framework) and xterm.js for terminal rendering.

---

## 1. Survey: Session List UI

How each tool presents its list of terminal sessions to the user.

### VS Code — Right sidebar tab list
- Terminal sessions appear as a **vertical list on the right side** of the terminal panel
- Each entry: icon + name + optional status decoration (spinner, checkmark, X)
- Split terminals are **grouped** — a group appears as one entry with sub-entries, keeping the list compact even with many splits
- Terminals can also live in the editor area as regular tabs (top tab bar)
- The session list is toggleable: always visible, hidden when single, or never shown

### JupyterLab — Running sidebar panel + tabs
- "Running Terminals and Kernels" is a **left sidebar panel** listing all active sessions
- Terminals listed flat: `terminals/1`, `terminals/2`, etc.
- Each terminal also opens as a **tab in the main dock area** alongside notebook tabs
- Clicking a session in the sidebar re-focuses its tab
- Launcher page provides tile-based creation (Terminal tile under "Other")

### Portainer — No session list
- **One session per view** — the Console tab within a container's detail page
- No multi-session management within the UI
- Multiple sessions require multiple browser tabs
- Container list serves as the implicit "session list" (pick a container → open its console)

### Cockpit — Host switcher dropdown
- Terminal is a **full-page module** in a sidebar-navigated dashboard
- **Host switcher** dropdown in sidebar header lists connected machines
- Switching hosts changes the entire dashboard context, including Terminal
- One terminal session per host — no tab bar, no multiplexing
- User-assigned **color dots** next to hostname for visual identification

### Tabby — Horizontal top tab bar
- Tabs across the top of the window: icon + title + close button
- **Color-coded tabs** per profile (red = production, green = dev, blue = staging)
- Tabs are draggable for reordering
- Profiles organized into hierarchical groups in a settings sidebar
- Split panes within a tab (broadcast mode sends to all panes simultaneously)

### GoTTY / ttyd — No session list
- One command per server instance — no built-in multiplexing
- Each browser connection spawns an independent session
- No listing, labeling, or re-attachment API
- For multi-session: run multiple instances on different ports, or wrap tmux

### Muxplex — Grid dashboard
- Discovers tmux sessions, renders a **live thumbnail grid**
- Clicking a session opens a full interactive terminal (ttyd + xterm.js)
- Session operations: list, create, attach, kill, rename
- Designed for parallel agent monitoring dashboards

### Pattern comparison

| Pattern | Tools | Strengths | Weaknesses |
|---------|-------|-----------|------------|
| **Sidebar list** | VS Code, JupyterLab | Compact, scalable to many sessions, always visible | Requires horizontal space |
| **Top tab bar** | Tabby, JupyterLab (main area) | Familiar, drag-to-reorder | Doesn't scale past ~10 tabs |
| **Dropdown** | Cockpit | Minimal chrome, works on mobile | Hard to scan many sessions |
| **Grid/dashboard** | Muxplex | Visual overview, thumbnails | Space-hungry, not for primary interaction |
| **No list** | Portainer, GoTTY/ttyd | Simplest | Doesn't support multi-session at all |

---

## 2. Survey: Lifecycle Indicators

How each tool communicates session state (running, idle, exited, disconnected).

### VS Code
- **Status decorations** appear as icons to the right of the terminal name in the tab list
- Running task: animated spinner icon
- Task success (exit 0): green checkmark
- Task failure (non-zero): red X icon (elevated to warning severity for visibility)
- Bell triggered: yellow bell (brief flash, configurable duration)
- Disconnected: dedicated icon
- **Shell integration command decorations:** colored circles in the gutter — blue for success, red for failure — per-command, not per-session
- Statuses are **transient overlays** with optional auto-timeout, not permanent state columns

### JupyterLab
- Minimal: terminals are either **running** (listed in sidebar) or **shut down** (removed)
- Status bar shows terminal count: `"if-any"`, `"always"`, or `"never"`
- Close tab ≠ kill session (configurable via `shutdownOnClose`)
- No visual distinction between active/idle sessions

### Portainer
- Container status shown in container list (running/stopped badges with color)
- Console has binary state: connected or disconnected
- **60-second idle timeout** auto-disconnects (known pain point)
- No reconnection — disconnecting destroys the session entirely

### Cockpit
- No per-session lifecycle indicator (one terminal per host)
- Host status implicit in the host switcher dropdown
- Color dots are user-assigned identity markers, not state indicators

### Tabby
- Disconnected SSH sessions: tab remains open showing disconnection state
- No automatic reconnection — must manually reconnect
- No idle/active distinction in tab appearance
- Layout persists through app restart (tab restore)

### Pattern comparison

| Indicator style | Tools | Description |
|----------------|-------|-------------|
| **Icon overlay on name** | VS Code | Small icon to right of session name — most space-efficient |
| **Color-coded badge** | Portainer (containers) | Colored pill with text (RUNNING, STOPPED) |
| **Presence/absence** | JupyterLab | In list = running, not in list = dead |
| **Status bar count** | JupyterLab | Global count, not per-session |
| **None** | Cockpit, Tabby | No explicit lifecycle visualization |

---

## 3. Survey: Session Creation

### VS Code
- **"+" button** with dropdown arrow for profile selection
- Profile dropdown lists auto-detected + manually configured profiles
- Split button (hover over tab entry) creates split terminal within same group
- Keyboard: `Ctrl+Shift+`` (new), `Ctrl+Shift+5` (split)
- Auto-detection of available shells (`$SHELL`, PowerShell, Git Bash, WSL)

### JupyterLab
- **Five methods:** Launcher tile, Menu bar (File > New > Terminal), keyboard shortcut (`Ctrl+Shift+T`), command palette, URL-based (`/terminals/<name>`)
- All methods create the same thing — a new PTY session + tab
- No profile/preset system — all terminals use the system default shell

### Portainer
- **Explicit configuration bar** above terminal: shell selector (bash/sh/ash/custom), user field, Connect button
- Must choose shell type before connecting
- Disconnect button replaces Connect during active session

### Cockpit
- **Implicit** — clicking Terminal module immediately opens a shell as the logged-in user
- No shell selector, no configuration step
- Add host dialog for new machine connections

### Tabby
- **Profile-based** — click a profile to open a new tab with that configuration
- SSH profiles: hostname, port, key, jump host, color
- Local profiles: shell path, working directory, env vars
- "Quick Connect" for ad-hoc SSH connections

### Pattern comparison

| Creation pattern | Suitability for Watchtower |
|-----------------|---------------------------|
| **Button + profile dropdown** (VS Code) | Best for multi-provider: "+" with Claude/GPT/local presets |
| **Launcher tiles** (JupyterLab) | Good for discoverability, wasteful if user knows what they want |
| **Config bar + Connect** (Portainer) | Good for one-off exec sessions |
| **Implicit** (Cockpit) | Only works for single-type sessions |
| **Profile sidebar** (Tabby) | Good for many saved connections |

---

## 4. Survey: Labels and Naming

### VS Code
- **Dynamic titles** via variable templates: `${process}`, `${cwd}`, `${task}`, `${shellType}`
- Title updates in real-time as child processes run (bash → python → bash)
- Right-click to rename (sets a static override)
- Per-profile icons from Codicon set (terminal-bash, terminal-powershell, etc.)
- Per-profile color from theme palette (ansiGreen, ansiRed, etc.)
- Implicit 1-9 indexing for keyboard navigation

### JupyterLab
- Sequential numbering: "Terminal 1", "Terminal 2", etc.
- **No rename UI** — feature requested since 2018, still not implemented (issue #4393)
- Shell-set titles via escape sequences propagate to tab header but not to the Running sidebar
- Architectural gap: sidebar reads server-side data, not widget state

### Tabby
- Profile name as default tab title
- Custom tab names supported
- Color-coded tabs per profile (user-chosen accent color)
- Profile groups for organization

### Cockpit
- Hostname + user-assigned color dot
- No per-session naming (only one session per host)

### Pattern comparison

| Feature | VS Code | JupyterLab | Tabby | Cockpit |
|---------|---------|------------|-------|---------|
| Auto-name | Process name (dynamic) | Sequential number | Profile name | Hostname |
| Rename | Yes (right-click) | No | Yes | No |
| Icon per type | Yes (Codicon) | No | Yes (profile icon) | No |
| Color coding | Yes (per-profile) | No | Yes (per-profile) | Yes (per-host) |
| Task/context label | Yes (`${task}` var) | No | No | No |

---

## 5. Survey: Layout Patterns

### VS Code
- **Split panes** within terminal panel (horizontal splits)
- Groups = splits under one tab entry (compact list)
- Terminal panel position: bottom (default), right, or left
- Drag-and-drop between groups
- **Detach/Attach** — terminals survive window changes (analogous to TermLink sessions)

### JupyterLab
- **Dock panel** with arbitrary nesting: drag tab to edge for split
- Tabbed stacking (multiple docs in one panel)
- "Down area" below main dock for consoles/terminals (like VS Code bottom panel)
- Workspace persistence saves layout state server-side

### Tabby
- Horizontal + vertical splits within tabs
- Broadcast mode (input to all panes)
- Save layout as profile (reconstruct exact split config)
- Drag-to-resize with percentage-based sizing

### Mobile viability

| Tool | Mobile support |
|------|---------------|
| VS Code | VS Code Server/Codespaces: usable but cramped, no split panes |
| JupyterLab | Responsive but terminal is narrow, no split panes |
| Portainer | Console works on mobile (full-width single session) |
| Cockpit | Bottom nav bar on mobile (<768px), full-page terminal works |
| Tabby | Desktop-only (Electron) |
| ttyd | Works on mobile (single terminal, full viewport) |

**Key insight:** Split panes are a desktop luxury. Mobile terminal UX demands **single session, full width** with a session switcher (dropdown or sidebar drawer).

---

## 6. Survey: tmux-in-Browser Architecture

Two architectural variants exist for bridging server-side sessions to the browser:

### Variant A: tmux as persistence layer
```
Browser (xterm.js) → WebSocket → Bridge → tmux attach -t session
```
- Session survives browser disconnect (tmux persists)
- Multiple viewers can attach simultaneously
- Extra dependency (tmux must be installed)
- Resize conflicts (smallest client wins)

### Variant B: Direct PTY
```
Browser (xterm.js) → WebSocket → Bridge → pty.fork()
```
- Simpler, fewer moving parts
- No persistence — browser close = session lost
- One client per PTY, no sharing
- Lower latency

**For Watchtower:** Variant A aligns with TermLink integration. TermLink already manages tmux/PTY sessions. The bridge attaches to existing TermLink sessions rather than spawning new ones. For ad-hoc terminals (quick shell for the operator), Variant B with direct PTY is sufficient.

### Notable projects

| Project | Stack | Pattern | Multi-session |
|---------|-------|---------|---------------|
| GoTTY | Go | One command per server | No (multiple ports needed) |
| ttyd | C (libwebsockets) | One command per server + base-path | No (same limitation) |
| Muxplex | Python/FastAPI | tmux session discovery + ttyd per session | Yes (grid + attach) |
| Webmux | Bun/Vue | tmux adapter + WebSocket bridge | Yes (PWA, mobile-friendly) |

---

## 7. Recommended UI Pattern for Watchtower

### Architecture: Sidebar + Tabs

Based on the survey, the recommended pattern combines:
- **JupyterLab's sidebar** (always-visible session list, independent of main area)
- **VS Code's lifecycle decorations** (icon overlays, not full state columns)
- **VS Code's profile-based creation** (button + dropdown for provider presets)
- **Tabby's color coding** (provider-keyed colors for instant visual identification)
- **Cockpit's responsive approach** (sidebar collapses to drawer on mobile)

### Page placement

**Option A — Dedicated `/terminal` page** (recommended for Phase 1):
- Full page in Watchtower nav, like Cockpit's Terminal module
- Sidebar left: session list (collapsible on mobile)
- Main area: active terminal (xterm.js)
- No splits in Phase 1 — single active session, switch via sidebar click

**Option B — Embedded in task detail** (future Phase 2):
- Terminal pane below task detail content
- Pre-filtered to show sessions tagged with that task ID
- "Open in full page" button to expand to `/terminal`

### Wireframe description

```
┌─────────────────────────────────────────────────────────────────┐
│  Watchtower  │  Tasks ▾  │  Governance ▾  │  System ▾  │  D/L │
├──────────────┴───────────┴────────────────┴────────────┴───────┤
│ ┌──────────────┐ ┌────────────────────────────────────────────┐ │
│ │ SESSIONS     │ │  ┌──────┐ ┌──────┐ ┌──────┐               │ │
│ │ [+ New ▾]    │ │  │ T1 ● │ │ T2   │ │ T3   │               │ │
│ │              │ │  └──────┘ └──────┘ └──────┘               │ │
│ │ ● claude-01  │ │ ┌────────────────────────────────────────┐ │ │
│ │   T-962 idle │ │ │                                        │ │ │
│ │ ● shell      │ │ │  $ fw audit                            │ │ │
│ │   running    │ │ │  PASS — 0 warnings, 0 failures         │ │ │
│ │ ○ gpt-dev    │ │ │  $                                     │ │ │
│ │   exited(0)  │ │ │                                        │ │ │
│ │              │ │ │                                        │ │ │
│ │              │ │ │                                        │ │ │
│ │              │ │ │                                        │ │ │
│ │              │ │ │                                        │ │ │
│ │              │ │ └────────────────────────────────────────┘ │ │
│ └──────────────┘ └────────────────────────────────────────────┘ │
│ Session: claude-01 │ Provider: Claude │ Task: T-962 │ PID: 4821│
└─────────────────────────────────────────────────────────────────┘
```

**Sidebar (left, ~200px):**
- Header: "SESSIONS" + "New ▾" button (dropdown with provider presets)
- Each entry: status dot (colored by lifecycle) + name + subtitle line (task ID + state text)
- Active session highlighted with accent border-left (matches Watchtower's `wt-card` pattern)
- On mobile (<768px): collapses to a hamburger-triggered drawer overlay

**Tab bar (top of main area):**
- Horizontal tabs for open sessions (only sessions the user has "opened" in this browser session)
- Active tab highlighted; inactive tabs show provider badge
- Close button per tab (closes the view, not the session — JupyterLab pattern)
- Max ~6 visible tabs before overflow scroll

**Terminal area (main):**
- xterm.js instance, full width of remaining space
- Fit addon for responsive resize
- WebGL addon for performance

**Status bar (bottom):**
- Session name, provider, task association, PID
- Styled as Watchtower's existing `session-strip` component

### Mobile layout

```
┌──────────────────────┐
│ Watchtower    ☰  ▾   │
├──────────────────────┤
│ claude-01 ▾          │
├──────────────────────┤
│                      │
│  $ fw audit          │
│  PASS                │
│  $                   │
│                      │
│                      │
│                      │
├──────────────────────┤
│ Claude | T-962 | idle│
└──────────────────────┘
```

- Session switcher: **dropdown** at top (replaces sidebar + tabs)
- Terminal: full width, full remaining height
- Status bar: compact single line
- No split panes on mobile

### htmx integration pattern

```html
<!-- Session list: htmx partial updates via SSE -->
<aside id="session-list"
       hx-ext="sse"
       sse-connect="/api/terminal/sessions/stream"
       sse-swap="sessions">
  <!-- Replaced by server-sent session list HTML -->
</aside>

<!-- Session creation: htmx form -->
<button hx-get="/api/terminal/new?provider=claude&task=T-962"
        hx-target="#terminal-area"
        hx-swap="innerHTML">
  New Claude Terminal
</button>

<!-- Terminal area: xterm.js (managed by JS, not htmx) -->
<div id="terminal-area"></div>
<script>
  // xterm.js lifecycle managed by vanilla JS
  // WebSocket connection per session, independent of htmx
  // Session switching: destroy old Terminal, create new one, connect new WS
</script>
```

**Key principle:** htmx manages the session list, creation forms, and status bar. xterm.js manages the terminal rendering via its own WebSocket. These are independent — htmx does not touch the terminal area, xterm.js does not touch the session list.

### PicoCSS compatibility

The design uses existing Watchtower patterns:
- **Session cards** in sidebar: `wt-card` with `border-left` color (matches cockpit.html pattern)
- **Status badges**: `wt-badge` (pass/warn/fail) repurposed for lifecycle states
- **Session strip**: existing `_session_strip.html` component extended with terminal metadata
- **Dropdown**: PicoCSS `<details>` dropdown for profile/provider selection
- **Responsive grid**: `@media (max-width:768px)` breakpoint (matches existing `wt-columns`)

No new CSS framework or component library needed.

---

## 8. Session Data Model

### JSON Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "TerminalSession",
  "description": "A terminal session in Watchtower, supporting multi-provider agent sessions",
  "type": "object",
  "required": ["id", "name", "provider", "state", "created_at"],
  "properties": {
    "id": {
      "type": "string",
      "description": "Unique session identifier (UUID or provider-assigned)",
      "examples": ["sess-a1b2c3d4", "termlink-claude-master-4821"]
    },
    "name": {
      "type": "string",
      "description": "Human-readable session name (auto-generated or user-set)",
      "examples": ["claude-01", "shell", "gpt-analysis"]
    },
    "provider": {
      "type": "object",
      "description": "Provider identity for multi-provider routing",
      "required": ["type"],
      "properties": {
        "type": {
          "type": "string",
          "enum": ["shell", "claude", "gpt", "gemini", "local-llm", "custom"],
          "description": "Provider type — determines badge, color, and routing"
        },
        "model": {
          "type": ["string", "null"],
          "description": "Specific model identifier (null for shell sessions)",
          "examples": ["claude-opus-4-6", "gpt-4o", "gemini-2.5-pro", "llama-3.3-70b"]
        },
        "label": {
          "type": "string",
          "description": "Display label (defaults to type if not set)",
          "examples": ["Claude", "GPT-4o", "Gemini", "Llama 3.3"]
        },
        "color": {
          "type": "string",
          "description": "CSS color for badge/accent (hex or named)",
          "examples": ["#D97706", "#10A37F", "#4285F4", "#6B7280"]
        },
        "icon": {
          "type": ["string", "null"],
          "description": "Icon identifier or emoji for provider badge",
          "examples": ["anthropic", "openai", "google", "terminal"]
        }
      }
    },
    "state": {
      "type": "string",
      "enum": ["starting", "running", "idle", "exited", "disconnected", "error"],
      "description": "Current lifecycle state"
    },
    "exit_code": {
      "type": ["integer", "null"],
      "description": "Process exit code (null while running)"
    },
    "task_id": {
      "type": ["string", "null"],
      "description": "Associated framework task ID",
      "examples": ["T-962", "T-503"]
    },
    "tags": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Arbitrary tags for filtering and discovery",
      "examples": [["inception", "research"], ["build", "frontend"]]
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 creation timestamp"
    },
    "last_activity": {
      "type": ["string", "null"],
      "format": "date-time",
      "description": "ISO 8601 timestamp of last I/O activity (for idle detection)"
    },
    "pid": {
      "type": ["integer", "null"],
      "description": "Server-side process ID (null for remote/proxy sessions)"
    },
    "termlink_session": {
      "type": ["string", "null"],
      "description": "TermLink session name if attached via TermLink",
      "examples": ["claude-master-4821", "dispatch-T962-explore"]
    },
    "connection": {
      "type": "object",
      "description": "Connection details for the WebSocket bridge",
      "properties": {
        "ws_path": {
          "type": "string",
          "description": "WebSocket endpoint path",
          "examples": ["/ws/terminal/sess-a1b2c3d4"]
        },
        "pty_mode": {
          "type": "string",
          "enum": ["direct", "tmux-attach", "termlink-proxy"],
          "description": "How the backend bridges to the terminal process"
        },
        "read_only": {
          "type": "boolean",
          "default": false,
          "description": "If true, client can observe but not send input"
        }
      }
    },
    "profile": {
      "type": ["string", "null"],
      "description": "Profile name used to create this session",
      "examples": ["default-shell", "claude-agent", "ssh-prod"]
    },
    "layout": {
      "type": "object",
      "description": "UI layout state (persisted per browser session)",
      "properties": {
        "tab_index": {
          "type": ["integer", "null"],
          "description": "Position in the tab bar (null = not open as tab)"
        },
        "is_pinned": {
          "type": "boolean",
          "default": false,
          "description": "Pinned tabs cannot be closed accidentally"
        }
      }
    }
  }
}
```

### Provider color map (defaults)

| Provider | Color | Badge text | Rationale |
|----------|-------|------------|-----------|
| `shell` | `#6B7280` (gray) | SH | Neutral — not an agent |
| `claude` | `#D97706` (amber) | CL | Anthropic brand association |
| `gpt` | `#10A37F` (green) | GP | OpenAI brand association |
| `gemini` | `#4285F4` (blue) | GE | Google brand association |
| `local-llm` | `#8B5CF6` (purple) | LM | Distinct from cloud providers |
| `custom` | `#EC4899` (pink) | ?? | User-defined |

### Lifecycle state machine

```
           ┌──────────────────────────────────────────────┐
           │                                              │
           v                                              │
  ┌───────────────┐     ┌──────────┐     ┌───────────┐   │
  │   starting    │────>│ running  │────>│   idle    │───┘
  └───────────────┘     └──────────┘     └───────────┘
           │                 │                │
           │                 │                │
           v                 v                v
  ┌───────────────┐     ┌──────────┐     ┌───────────┐
  │    error      │     │  exited  │     │disconnected│
  └───────────────┘     └──────────┘     └───────────┘
                             │                │
                             │                │
                             v                v
                        [removable]     [reconnectable]
```

- **starting -> running**: Process spawned successfully, PTY attached
- **running -> idle**: No I/O for configurable duration (default: 30s)
- **idle -> running**: Any I/O activity resumes running state
- **running/idle -> exited**: Process terminated (captures exit_code)
- **running/idle -> disconnected**: WebSocket dropped but process may still live (TermLink sessions)
- **starting -> error**: Failed to spawn (bad profile, permission denied, etc.)
- **disconnected -> running**: Reconnection successful (TermLink re-attach)

### Lifecycle indicator rendering

| State | Dot color | Icon | Text |
|-------|-----------|------|------|
| starting | yellow pulse | (hollow, animated) | starting... |
| running | green solid | (filled) | running |
| idle | green dim | (50% opacity) | idle (30s) |
| exited(0) | gray | (hollow) | exited(0) |
| exited(N) | red | X | exited(1) |
| disconnected | orange | (half-filled) | disconnected |
| error | red | X | error |

---

## 9. Design Questions — Answered

### Session list UI: sidebar vs tabs vs dropdown?

**Answer: Sidebar + tabs (desktop), dropdown (mobile).**
- Sidebar provides persistent visibility without consuming tab bar space
- Tabs provide fast switching between "open" sessions (subset of all sessions)
- Mobile collapses both to a single dropdown selector
- Evidence: VS Code and JupyterLab both use sidebar lists; both scale to 10+ sessions. Cockpit's dropdown works for <5 hosts but doesn't scale. Portainer's no-list approach is explicitly rejected.

### Lifecycle indicators: how prominent?

**Answer: Status dot + state text in sidebar; dot-only in tab bar.**
- VS Code's icon-overlay approach is the most space-efficient
- Full-text state labels in sidebar (space is available)
- Dot-only in tab bar (space is constrained)
- Color alone is insufficient (accessibility) — always pair with icon shape or text

### Session creation: button, presets, or both?

**Answer: "+" button with provider dropdown.**
- Primary action: "+" creates a default shell session (one click)
- Dropdown arrow: reveals provider presets (Claude, GPT, Local LLM, Shell)
- Each preset can be bound to a profile with pre-configured env vars, model, task association
- VS Code's pattern works well and is familiar to the target user base

### Labels: auto vs named, task ID, provider?

**Answer: Auto-generated with rename, task ID association, provider badge.**
- Auto-name: `{provider}-{sequence}` (e.g., `claude-01`, `shell-03`)
- Rename: right-click or double-click name in sidebar (VS Code pattern)
- Task ID: optional association, shown as subtitle in sidebar, filterable
- Provider badge: colored 2-letter code (CL, GP, GE, SH) — always visible
- Learn from JupyterLab's mistake: ship rename from day one

### Layout: tabs or splits?

**Answer: Tabs in Phase 1, splits in Phase 2.**
- Tabs are essential (fast switching between sessions)
- Splits add complexity (resize logic, broadcast mode) — defer to Phase 2
- Phase 1 goal: working multi-session terminal, not a full terminal emulator
- Phase 2: horizontal splits within a tab (VS Code group pattern)

### Mobile viability?

**Answer: Yes, with degraded UX — single session, no tabs, dropdown switcher.**
- Full-width terminal works on mobile (ttyd, Portainer prove this)
- No split panes, no sidebar — dropdown session switcher at top
- Touch keyboard may obscure terminal — accept this limitation
- Mobile is "check on a session" UX, not "do serious work" UX

### Watchtower integration: alongside tasks or separate page?

**Answer: Both — dedicated page Phase 1, task-embedded Phase 2.**
- Phase 1: `/terminal` page in Watchtower nav (under System dropdown)
- Phase 2: terminal pane in task detail page, pre-filtered to task's sessions
- Phase 2: Tier 0 approval page gets "Open terminal" action (approve, then interact)
- The session data model supports task association from day one (`task_id` field)

---

## 10. Future: Multi-Provider Sessions

The data model and UI are designed to support multi-provider routing without rewrites:

### What changes with multi-provider

| Concern | Single-provider (Phase 1) | Multi-provider (future) |
|---------|--------------------------|------------------------|
| Session creation | "New Shell" / "New Claude" | Provider picker with model selector |
| Provider badge | Static per session | Dynamic (provider + model) |
| Routing | Direct PTY or TermLink attach | Provider-specific adapter (API key, endpoint) |
| Cost tracking | N/A | Per-provider token/cost counters |
| Context | Single agent context | Cross-provider context sharing (future) |

### Provider adapter interface

Each provider type needs an adapter that implements:
1. **spawn(profile) -> session_id** — Create a new session
2. **attach(session_id) -> websocket** — Connect browser to session
3. **status(session_id) -> state** — Query lifecycle state
4. **terminate(session_id)** — Kill session

For Phase 1, only two adapters are needed:
- `ShellAdapter` — direct PTY via `pty.fork()`
- `TermLinkAdapter` — attach to existing TermLink session via `termlink attach`

Future adapters:
- `ClaudeAdapter` — spawn `claude -p` process, bridge PTY
- `GPTAdapter` — spawn `openai-cli` or custom bridge
- `LocalLLMAdapter` — spawn local model process (Ollama, llama.cpp)

### Provider badges in the UI

```html
<!-- Provider badge: 2-letter code with provider color -->
<span class="wt-provider-badge" style="background: #D97706;">CL</span>

<!-- In session list entry -->
<div class="wt-session-entry active">
  <span class="wt-state-dot running"></span>
  <span class="wt-provider-badge" style="background: #D97706;">CL</span>
  <div class="wt-session-info">
    <span class="wt-session-name">claude-01</span>
    <span class="wt-session-meta">T-962 · running</span>
  </div>
</div>
```

---

## 11. Implementation Phases

| Phase | Scope | Dependencies |
|-------|-------|-------------|
| **1a** | Session data model + REST API (`/api/terminal/sessions`) | Flask, YAML/JSON store |
| **1b** | Single terminal page with xterm.js + WebSocket PTY bridge | xterm.js, flask-sock |
| **1c** | Sidebar session list + tab bar + lifecycle indicators | htmx SSE, PicoCSS |
| **1d** | Session profiles + "New" dropdown | PicoCSS `<details>` |
| **2a** | TermLink session discovery + attach | TermLink binary |
| **2b** | Task association + task detail embed | Existing task system |
| **2c** | Split panes within tabs | xterm.js fit addon |
| **3** | Multi-provider adapters + provider routing | Per-provider work |

---

## Sources

- VS Code terminal documentation and source (xtermjs/xterm.js integration)
- JupyterLab terminal plugin (jupyterlab/jupyterlab, `@jupyterlab/terminal`)
- Portainer console (portainer/portainer, container exec WebSocket)
- Cockpit terminal (cockpit-project/cockpit, PatternFly + host switcher)
- Tabby terminal (Eugeny/tabby, Electron + xterm.js)
- GoTTY (sorenisanerd/gotty, maintained fork)
- ttyd (tsl0922/ttyd, C + libwebsockets)
- Muxplex (bkrabach/muxplex, Python/FastAPI + tmux discovery)
- Webmux (nooesc/webmux, Bun/Vue + tmux adapter)
- T-962 v1 OSS terminal survey (this project)
