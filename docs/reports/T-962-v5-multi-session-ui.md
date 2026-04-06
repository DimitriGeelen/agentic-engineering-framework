# T-962 Vector 5: Multi-Session Terminal UI Patterns

Research report for T-962 (Web Terminal in Watchtower).
Covers how existing tools handle multiple concurrent terminal sessions in a browser,
and recommends a UI pattern for Watchtower.

---

## 1. Survey of Existing Tools

### 1.1 VS Code Integrated Terminal

**Architecture:** Tab list on the right side of the terminal panel. Each tab shows name, icon, color decoration, and group indicator. The core component (`TerminalTabbedView`) uses a `SplitView` to create a resizable layout between the tab list and the terminal display area.

**Session management:**
- **Creation:** `+` button in panel toolbar; keyboard shortcut; command palette; terminal profiles dropdown
- **Tabs:** Vertical tab list on right side (configurable). Each entry shows: icon (customizable per profile), name (auto or user-set), color coding, group decoration
- **Split panes:** Drag a tab into the terminal area to create side-by-side splits within a group. Groups are visually joined
- **Profiles:** Named presets (shell type, env vars, icon, color) — user creates "Python", "Node", "SSH prod" profiles
- **Lifecycle:** Running terminals show animated icon; exited terminals show exit code badge; dead terminals can be restarted
- **At scale (5+ terminals):** Tab list scrolls vertically. Terminal editor mode lets terminals live as regular editor tabs in the main area. Groups collapse
- **Persistence:** Layouts serialize and restore across window reloads (`enablePersistentSessions`)

**Key takeaway:** The tab-list-on-side + split-pane-in-main pattern scales well. Profile system prevents "Terminal 1, Terminal 2, Terminal 3" label fatigue. Color coding is surprisingly useful for quick visual scanning.

### 1.2 JupyterLab

**Architecture:** Dock panel layout with tabs along the top of the main work area. Terminals are peers of notebooks — same tab bar, same layout system.

**Session management:**
- **Creation:** `+` launcher button opens a launcher page; click "Terminal" tile. Also available from File menu
- **Tabs:** Horizontal tab bar at top of each panel. Terminals and notebooks share the tab bar — distinguished by icon (terminal icon vs notebook icon)
- **Split panes:** Drag any tab to an edge of the main area to create a new panel. Panels tile freely (horizontal or vertical)
- **Running panel:** Left sidebar "Running" panel lists all active kernel sessions AND terminal sessions. Terminals can be re-opened from here if tab was closed (session survives tab close)
- **Labels:** Auto-named "Terminal 1", "Terminal 2", etc. No rename capability built-in. Distinguished by number only
- **Lifecycle:** Closing a tab does NOT kill the session — it continues on the server. The "Running" sidebar shows all live sessions for reconnection
- **Areas:** Four docking areas: left sidebar, right sidebar, main dock panel, bottom area. Terminals can be placed in any area

**Key takeaway:** The "session survives tab close" pattern is important for Watchtower — TermLink sessions persist independently of the browser. The "Running" sidebar as a session registry is a strong pattern. Weak labeling (just numbers) is a known pain point.

### 1.3 Portainer Container Console

**Architecture:** Per-container console access. Each container has a "Console" action that opens an exec session in the container detail view.

**Session management:**
- **Creation:** Click console icon in container row, or "Console" button on container detail page. Choose shell (`/bin/bash`, `/bin/sh`, custom command) and user (root, default, custom)
- **Tabs:** No multi-tab terminal. One console session per container view. Opening another container console navigates away
- **Shell selection:** Dropdown for shell type; toggle for custom command; user field for privilege control
- **Lifecycle:** Sessions timeout after ~60s of inactivity (known pain point). Reconnection loses previous state. No session persistence
- **Multi-container:** To watch multiple containers, users open multiple browser tabs (external multiplexing)

**Key takeaway:** Portainer's model is anti-pattern for Watchtower. Single-session-per-view forces browser-tab multiplexing. The shell-selection and user-selection UX during session creation is relevant though — we need something similar for choosing session type (bash, Claude, TermLink attach).

### 1.4 Cockpit

**Architecture:** Host-switching model. Each connected machine has its own set of pages, including a terminal. The "host switcher" dropdown at top-left navigates between machines.

**Session management:**
- **Multi-host:** SSH to secondary hosts from primary. Each host gets a full Cockpit session with its own terminal
- **Switching:** Dropdown at top-left corner. Selecting a host switches all pages (not just terminal) to that host's context
- **Terminal:** One terminal per host. Full-screen terminal page within each host's context
- **Security:** All remote code runs in the same browser context (no isolation). Only connect to trusted hosts
- **Current status:** Host switcher is deprecated in favor of Cockpit Client (Flatpak app)

**Key takeaway:** The per-host switching model is relevant for multi-machine orchestration (future). But one-terminal-per-host is too limited. The security concern (same browser context for all hosts) applies to Watchtower too — all sessions share the same Watchtower auth context.

### 1.5 Tabby (formerly Terminus)

**Architecture:** Electron-based terminal with deep tab and split-pane support. Connection profiles as first-class concept.

**Session management:**
- **Tabs:** Top tab bar. Each tab shows profile icon, name, and activity indicator
- **Split panes:** Split any tab horizontally or vertically. Nested splits supported. Save split layout as a reusable profile
- **Profiles:** Named connection profiles (SSH, serial, local shell) with icon, color, and configuration. Profiles are the primary organizing concept
- **Broadcast:** `Ctrl-Shift-I` types into ALL panes simultaneously (useful for cluster ops)
- **Labels:** Profile name + optional custom name. Rich metadata: host, connection type, status
- **Full-screen pane:** `Ctrl-Alt-Enter` temporarily maximizes a single pane

**Key takeaway:** Profiles-as-first-class-concept is the right model for Watchtower. A "Claude Code session", "bash terminal", "TermLink attach" are profiles. The broadcast-to-all-panes feature is interesting for future orchestrator (send same command to all agent sessions). Save-layout-as-profile is powerful but complex.

### 1.6 Tmux/Screen in Browser (GoTTY, ttyd)

**Architecture:** Thin web wrapper around a server-side terminal multiplexer. The browser is a viewport into a tmux/screen session.

**Session management:**
- **GoTTY:** Starts a web server on port 8080 serving a single command/session. One URL = one terminal view. Multi-session requires running multiple GoTTY instances on different ports, or using tmux inside the single session
- **ttyd:** Similar to GoTTY but C-based (faster). Shares terminal output over web. For interaction, run tmux/screen inside ttyd
- **tmux integration:** The typical pattern is: GoTTY/ttyd wraps tmux. Tmux handles panes/windows. Browser just renders the tmux output. Multiple browser clients can attach to the same tmux session (shared view)
- **Multi-session:** Not built into the web layer. Users rely on tmux's own window/pane management (keyboard-driven, not clickable tabs)

**Key takeaway:** The "wrap tmux in a web shell" pattern is proven but crude for a modern UI. It pushes all session management to the terminal multiplexer, losing the ability to have browser-native tabs, lifecycle indicators, and metadata. However, the "multiple clients attach to one session" pattern is directly relevant — TermLink sessions can have multiple viewers.

---

## 2. Pattern Comparison Matrix

| Feature | VS Code | JupyterLab | Portainer | Cockpit | Tabby | GoTTY+tmux |
|---------|---------|------------|-----------|---------|-------|------------|
| Multi-session | Tab list | Tab bar | No (1 per view) | 1 per host | Tab bar | tmux internal |
| Split panes | Yes (groups) | Yes (dock panels) | No | No | Yes (nested) | tmux panes |
| Session persistence | Across reloads | Survives tab close | No (60s timeout) | Per-host | App-level | tmux persistent |
| Profiles/presets | Yes (rich) | No | Shell selection | No | Yes (rich) | No |
| Session lifecycle UI | Icon + exit code | Running sidebar | Error only | N/A | Activity indicator | N/A |
| Rename/color | Yes/Yes | No/No | No/No | No/No | Yes/Yes | No/No |
| Session metadata | Profile, icon, color, group | Type icon, number | Container, shell, user | Host | Profile, connection | None |
| Mobile-friendly | No | Partial | Yes | Partial | No | Yes (responsive) |
| Scales to 10+ sessions | Yes (scrollable list) | Yes (Running panel) | N/A | N/A | Yes | tmux windows |

---

## 3. Recommended UI Pattern for Watchtower

### 3.1 Design Principles

1. **Session list, not tab bar** — A sidebar/panel session list (VS Code model) scales better than horizontal tabs (JupyterLab) for 5+ sessions. Horizontal tabs break at ~6 items on typical screens
2. **Profiles as first-class concept** — Borrow from Tabby/VS Code. "New Terminal" is not enough; users need "New Bash", "New Claude Session", "Attach TermLink T-042"
3. **Sessions outlive the browser** — Follow JupyterLab: closing a tab doesn't kill the session. TermLink sessions already persist server-side
4. **Lifecycle is visible** — Running, idle, exited, error states with distinct visual treatment (VS Code model)
5. **htmx-compatible** — No React state management. Server renders the session list. xterm.js is the only JS-heavy component (loaded per-terminal, not framework-level)

### 3.2 Layout: Two-Column with Collapsible Session Panel

```
+-------------------------------------------------------------------+
| Watchtower nav bar (existing)                                     |
+-------------------------------------------------------------------+
| Ambient strip (existing)                                          |
+-------------------+-----------------------------------------------+
| SESSION PANEL     | TERMINAL VIEWPORT                             |
| (collapsible)     |                                               |
|                   | +-------------------------------------------+ |
| [+ New ▾]         | |                                           | |
|                   | |  xterm.js instance                        | |
| ● bash-1          | |  (active session)                         | |
|   T-962 | local   | |                                           | |
|                   | |  $ fw audit                                | |
| ● claude-prod     | |  PASS: 12 checks                          | |
|   T-962 | claude  | |  WARN: 1 check                            | |
|                   | |  $ _                                      | |
| ◐ termlink-T042   | |                                           | |
|   T-042 | termlink| |                                           | |
|                   | +-------------------------------------------+ |
| ◌ bash-2 (exited) | [ bash-1 ][ claude-prod ][ termlink-T042 ]   |
|   — | local       | (secondary tab bar for quick switching)       |
+-------------------+-----------------------------------------------+
```

**Session panel (left, ~200px, collapsible):**
- Header: "Sessions" title + "+ New" dropdown button
- Each session card: status icon, name, task badge, provider badge
- Click to switch active terminal
- Right-click/long-press: rename, change color, kill, detach
- Collapsible on mobile (hamburger toggle)
- Rendered server-side via htmx (`hx-get="/api/terminal/sessions"`)

**Terminal viewport (right, fills remaining space):**
- Single xterm.js instance showing the active session
- Secondary tab bar below terminal for quick switching (optional, can be hidden)
- Resize handle between session panel and viewport

**Secondary tab bar (bottom of viewport, optional):**
- Compact horizontal tabs for the 3-5 most recent sessions
- Overflow: `...` dropdown
- Duplicates session panel functionality but enables faster switching without the panel open

### 3.3 Session Lifecycle Indicators

| State | Icon | Color | Meaning |
|-------|------|-------|---------|
| `running` | ● (filled circle) | Green `#2e7d32` | Process active, accepting input |
| `idle` | ◐ (half circle) | Blue `#1565c0` | Connected but no recent I/O (>60s) |
| `exited` | ◌ (empty circle) | Gray (muted) | Process exited (show exit code) |
| `error` | ✕ (cross) | Red `#c62828` | Connection failed or process crashed |
| `connecting` | ◎ (target) | Amber `#f9a825` | WebSocket connecting / PTY spawning |

These map directly to PicoCSS/Watchtower's existing color palette (`.audit-pass`, `.audit-warn`, `.audit-fail`).

### 3.4 Session Creation Flow

The "+ New" button opens a dropdown (PicoCSS `<details class="dropdown">`):

```
+---------------------------+
| + New Terminal             |
+---------------------------+
| ▸ Bash Shell              |
| ▸ Claude Code Session     |
| ▸ Attach TermLink...      |  → sub-menu: list active TermLink sessions
| ▸ SSH to Host...          |  → future: host selection
+---------------------------+
| ▸ From Profile...         |  → future: saved profiles
+---------------------------+
```

Each option hits an htmx endpoint:
- `POST /api/terminal/sessions` with `{"type": "bash"}` → spawns PTY
- `POST /api/terminal/sessions` with `{"type": "claude", "task": "T-042"}` → spawns `claude -p`
- `POST /api/terminal/sessions` with `{"type": "termlink", "session": "worker-1"}` → attaches to existing TermLink session

### 3.5 Session Labels and Naming

**Auto-generated format:** `{type}-{counter}` (e.g., `bash-1`, `claude-2`, `termlink-T042`)

**Metadata shown per session:**
- Line 1: **Name** (editable, click-to-rename like VS Code)
- Line 2: Task ID badge (if associated) + Provider badge

**Provider badges** (inline, colored):
| Provider | Badge | Color |
|----------|-------|-------|
| Local shell | `local` | Gray |
| Claude | `claude` | Orange/amber |
| TermLink | `termlink` | Blue |
| GPT (future) | `gpt` | Green |
| Gemini (future) | `gemini` | Blue |
| Ollama (future) | `ollama` | Purple |

### 3.6 htmx Integration Pattern

The terminal page is a hybrid: server-rendered chrome (session list, controls) + client-side xterm.js (terminal I/O).

```
Page load:
  GET /terminal → server renders full page with session list + empty viewport
  
Session list updates:
  hx-get="/api/terminal/sessions" hx-trigger="every 5s" hx-swap="innerHTML"
  → Server renders session list HTML fragment
  
Session switching:
  hx-get="/api/terminal/sessions/{id}/activate" hx-target="#terminal-viewport"
  → JS callback attaches xterm.js to the session's WebSocket
  
Session creation:
  hx-post="/api/terminal/sessions" hx-vals='{"type":"bash"}'
  → Server spawns PTY, returns session ID
  → JS creates new xterm.js instance, connects WebSocket

Terminal I/O:
  Pure WebSocket (not htmx) — xterm.js ↔ ws://host/api/terminal/ws/{session_id}
```

**Key architectural split:**
- htmx handles: session list, session creation, session metadata, lifecycle indicators
- WebSocket handles: terminal I/O (keystrokes, output)
- xterm.js handles: rendering, cursor, colors, scrollback

This preserves Watchtower's htmx-first architecture while using WebSocket only where htmx can't work (real-time bidirectional terminal I/O).

### 3.7 Integration with Existing Watchtower Pages

**Option A: Dedicated `/terminal` page (recommended for v1)**
- New nav item under "Operations" group
- Full-page terminal experience
- Session panel + viewport layout as described above

**Option B: Embedded terminal on task detail page (v2)**
- Collapsible terminal drawer at bottom of task detail page
- Pre-filtered to show sessions associated with that task
- "Open in full page" link to `/terminal?task=T-042`

**Option C: Both (recommended long-term)**
- `/terminal` as the power-user multi-session view
- Task detail page embeds a mini terminal (single session, task-scoped)
- Inception detail page: terminal for running spikes
- Approvals page: terminal for Tier 0 command execution

### 3.8 Mobile Considerations

**Recommendation: Desktop-primary, mobile-aware.**

Full terminal interaction on mobile is poor UX (small screen, soft keyboard, no modifier keys). But *viewing* terminal output and *session management* are valuable on mobile.

Mobile layout:
- Session panel becomes full-width (stacked above viewport, not beside it)
- Terminal viewport is read-only by default on mobile (prevents accidental input)
- "Enable input" toggle for when mobile input is genuinely needed
- Session lifecycle indicators and metadata are fully functional
- QR code on desktop `/terminal` page links to mobile view

```
Mobile (< 768px):
+---------------------------+
| Watchtower nav (hamburger)|
+---------------------------+
| Sessions (horizontal scroll) |
| [●bash-1] [●claude] [◐tl]|
+---------------------------+
|                           |
|  Terminal output          |
|  (read-only by default)   |
|                           |
|  [Enable Input]           |
+---------------------------+
```

---

## 4. Session Data Model

### 4.1 JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "TerminalSession",
  "description": "Watchtower terminal session — supports local, Claude, TermLink, and future multi-provider sessions",
  "type": "object",
  "required": ["id", "type", "state", "created_at"],
  "properties": {
    "id": {
      "type": "string",
      "description": "Unique session identifier",
      "pattern": "^ts-[a-z0-9]{8}$",
      "examples": ["ts-a1b2c3d4"]
    },
    "name": {
      "type": "string",
      "description": "Human-readable session name (auto-generated or user-set)",
      "examples": ["bash-1", "claude-prod", "termlink-T042"]
    },
    "type": {
      "type": "string",
      "enum": ["shell", "claude", "termlink", "agent"],
      "description": "Session type. 'shell' = local PTY, 'claude' = Claude Code session, 'termlink' = attached TermLink session, 'agent' = generic AI agent (future)"
    },
    "state": {
      "type": "string",
      "enum": ["connecting", "running", "idle", "exited", "error"],
      "description": "Current lifecycle state"
    },
    "exit_code": {
      "type": ["integer", "null"],
      "description": "Process exit code (null if still running)"
    },

    "provider": {
      "type": "object",
      "description": "AI provider metadata (null for shell sessions)",
      "properties": {
        "name": {
          "type": "string",
          "enum": ["local", "anthropic", "openai", "google", "ollama", "custom"],
          "description": "Provider identifier"
        },
        "model": {
          "type": ["string", "null"],
          "description": "Model identifier if applicable",
          "examples": ["claude-opus-4-6", "gpt-4o", "gemini-2.5-pro"]
        },
        "display_name": {
          "type": "string",
          "description": "Human-readable provider name for UI badges",
          "examples": ["Claude", "GPT", "Gemini", "Ollama", "Local"]
        },
        "icon": {
          "type": ["string", "null"],
          "description": "Provider icon identifier or URL"
        },
        "color": {
          "type": ["string", "null"],
          "description": "Badge color hex code",
          "examples": ["#d97706", "#10b981", "#3b82f6"]
        }
      },
      "required": ["name", "display_name"]
    },

    "task_id": {
      "type": ["string", "null"],
      "description": "Associated framework task ID",
      "pattern": "^T-\\d{3,4}$",
      "examples": ["T-042", "T-962"]
    },

    "connection": {
      "type": "object",
      "description": "Connection details (varies by type)",
      "properties": {
        "pid": {
          "type": ["integer", "null"],
          "description": "Server-side process ID (shell/claude sessions)"
        },
        "termlink_session": {
          "type": ["string", "null"],
          "description": "TermLink session name (termlink type only)"
        },
        "ws_path": {
          "type": "string",
          "description": "WebSocket endpoint path for this session",
          "examples": ["/api/terminal/ws/ts-a1b2c3d4"]
        },
        "shell": {
          "type": ["string", "null"],
          "description": "Shell command (shell type)",
          "examples": ["/bin/bash", "/bin/zsh"]
        },
        "command": {
          "type": ["string", "null"],
          "description": "Launch command (claude/agent type)",
          "examples": ["claude -p 'task prompt'", "aider"]
        },
        "host": {
          "type": ["string", "null"],
          "description": "Remote host (future: SSH sessions, remote agents)",
          "examples": ["192.168.10.107"]
        }
      },
      "required": ["ws_path"]
    },

    "metadata": {
      "type": "object",
      "description": "User-customizable metadata",
      "properties": {
        "color": {
          "type": ["string", "null"],
          "description": "User-assigned color for visual distinction"
        },
        "pinned": {
          "type": "boolean",
          "default": false,
          "description": "Pinned sessions appear first in the list"
        },
        "tags": {
          "type": "array",
          "items": { "type": "string" },
          "description": "User-assigned tags for filtering"
        }
      }
    },

    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "connected_at": {
      "type": ["string", "null"],
      "format": "date-time",
      "description": "When WebSocket last connected"
    },
    "last_activity": {
      "type": ["string", "null"],
      "format": "date-time",
      "description": "Last I/O timestamp (for idle detection)"
    },
    "exited_at": {
      "type": ["string", "null"],
      "format": "date-time"
    }
  }
}
```

### 4.2 Data Model Design Decisions

**Why `type` + `provider` instead of just `type`:**
The `type` field controls *how* the session works (PTY, TermLink attach, agent process). The `provider` field controls *who* is behind the session. A Claude session and a GPT session are both `type: "agent"` but different providers. This separation allows the UI to use `type` for connection logic and `provider` for badges/icons/routing.

**Why `connection.ws_path` is required:**
Every session, regardless of type, is accessed through a WebSocket from the browser's perspective. The server-side implementation differs (PTY bridge, TermLink proxy, agent process), but the browser always connects to a WebSocket endpoint. This uniformity simplifies the xterm.js client code.

**Why `task_id` is top-level:**
Framework governance requires task traceability. Every terminal session SHOULD be associated with a task. Making it top-level (not buried in metadata) makes it a first-class filter for the session list and enables the "show sessions for this task" feature on task detail pages.

**Future orchestrator fields (not in v1, designed for):**
- `provider.routing_priority` — Which agent gets routed which prompts
- `provider.capabilities` — What this agent can do (code, research, review)
- `metadata.group_id` — Group sessions into an "agent team" for aggregate views
- `connection.relay_to` — Forward output to another session (agent chaining)

### 4.3 Session State Machine

```
                    spawn/attach
          ┌─────────────────────────┐
          │                         ▼
     [connecting] ──────────► [running]
          │                    │     │
          │ fail               │     │ no I/O > 60s
          │                    │     │
          ▼                    │     ▼
       [error]                 │  [idle]
          │                    │     │
          │ retry              │     │ I/O resumes
          │                    │     │
          └───► [connecting]   │     └──► [running]
                               │
                               │ process exits
                               ▼
                           [exited]
                               │
                               │ respawn
                               ▼
                          [connecting]
```

---

## 5. Text-Based Wireframe: Full Terminal Page

### 5.1 Desktop Layout (>= 768px)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 🔷 Watchtower    [Operations ▾] [Insights ▾] [Knowledge ▾]  🔍 ◐  │
├─────────────────────────────────────────────────────────────────────┤
│ Focus: T-962 | Session: 2h14m | Audit: PASS | 0 items attention    │
├────────────────┬────────────────────────────────────────────────────┤
│ SESSIONS       │ TERMINAL                                          │
│                │                                                    │
│ [+ New ▾]      │ ┌──────────────────────────────────────────────┐  │
│                │ │ $ fw audit                                    │  │
│ ● bash-1    ← │ │ Running compliance audit...                   │  │
│   T-962|local  │ │                                               │  │
│                │ │ P-001 Task traceability .......... PASS       │  │
│ ● claude-1     │ │ P-002 Git references ............. PASS       │  │
│   T-962|claude │ │ P-009 Context budget ............. WARN       │  │
│                │ │ P-010 Acceptance criteria ........ PASS       │  │
│ ◐ tl-worker-1  │ │                                               │  │
│   T-042|termlink│ │ Result: PASS (12 pass, 1 warn, 0 fail)      │  │
│                │ │ $ _                                           │  │
│ ◌ bash-2       │ │                                               │  │
│   —|local [0]  │ └──────────────────────────────────────────────┘  │
│                │                                                    │
│ ─────────────  │  ┌────────┐┌──────────┐┌─────────────┐           │
│ Disconnected   │  │●bash-1 ││●claude-1 ││◐tl-worker-1 │  [⚙]     │
│                │  └────────┘└──────────┘└─────────────┘           │
│ ✕ ssh-prod     │                                                    │
│   —|ssh [err]  │                                                    │
├────────────────┴────────────────────────────────────────────────────┤
│ Watchtower v0.9.2 — Agentic Engineering Framework                  │
└─────────────────────────────────────────────────────────────────────┘

Legend:
  ← = currently active session (highlighted)
  ● = running    ◐ = idle    ◌ = exited    ✕ = error
  [0] = exit code    [err] = connection error
  [⚙] = terminal settings (font size, scrollback, theme)
```

### 5.2 Session Panel Detail (Hover/Expanded)

```
┌──────────────────┐
│ ● bash-1         │  ← name (click to rename)
│   T-962 | local  │  ← task badge | provider badge
│   2m ago | PID 42│  ← last activity | connection info
│                  │
│   [Kill] [Detach]│  ← actions (on hover or right-click)
└──────────────────┘
```

### 5.3 "+ New" Dropdown

```
┌──────────────────────┐
│  Bash Shell           │  → POST /api/terminal/sessions {"type":"shell"}
│  Claude Code Session  │  → POST /api/terminal/sessions {"type":"claude"}
│  ───────────────────  │
│  Attach TermLink  ▸   │  → submenu: list of active TermLink sessions
│    ● worker-1 (T-042) │
│    ● master-main       │
│  ───────────────────  │
│  Custom Command...     │  → modal: enter command
└──────────────────────┘
```

### 5.4 Mobile Layout (< 768px)

```
┌───────────────────────────┐
│ ☰ Watchtower         🔍 ◐│
├───────────────────────────┤
│ T-962 | 2h14m | PASS     │
├───────────────────────────┤
│ Sessions [+ New ▾]       │
│ [●bash-1][●claude][◐tl]→ │  ← horizontal scroll
├───────────────────────────┤
│                           │
│ $ fw audit                │
│ Running compliance audit..│
│ P-001 Task traceability.. │
│ ................ PASS     │
│                           │
│ [📱 Enable Input]        │
│                           │
└───────────────────────────┘
```

### 5.5 Task Detail Integration (v2)

```
┌─────────────────────────────────────────────────────────────────┐
│ T-962: Web terminal in Watchtower                               │
│ Status: started-work | Owner: human | Horizon: now              │
├─────────────────────────────────────────────────────────────────┤
│ [Description] [Acceptance Criteria] [Terminal ▾] [Updates]      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Sessions for T-962:                                             │
│ ● bash-1    ● claude-1                                          │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐    │
│ │ $ fw audit                                               │    │
│ │ PASS: 12 checks                                          │    │
│ │ $ _                                                      │    │
│ └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│ [Open full terminal ↗]                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Implementation Considerations for htmx + PicoCSS

### 6.1 What PicoCSS Gives Us

- `<article>` for session cards in the panel
- `<details class="dropdown">` for the "+ New" menu
- Color variables (`--pico-muted-color`, card background, border colors) for consistent theming
- Dark mode via `data-theme="dark"` (already implemented in Watchtower)
- Responsive breakpoints (768px, 576px) already defined in `base.html`

### 6.2 What Requires Custom CSS

- Two-column layout (session panel + viewport) — CSS Grid or Flexbox
- Session lifecycle indicator icons (small colored circles — pure CSS)
- Provider badges (small inline `<span>` with background color)
- Resize handle between panel and viewport
- xterm.js container sizing (must fill available space)

### 6.3 What Requires JavaScript Beyond htmx

- **xterm.js** — Terminal rendering (no alternative)
- **WebSocket management** — Connect/disconnect/reconnect per session
- **Session switching** — Swap which WebSocket feeds xterm.js (show/hide or create/destroy instances)
- **Resize observer** — Notify xterm.js and server when terminal viewport changes size
- **Fit addon** — xterm.js addon to auto-fit terminal to container

### 6.4 xterm.js Multi-Instance Strategy

Two approaches for managing multiple terminal instances:

**Option A: Single xterm.js instance, swap WebSocket (recommended for v1)**
- One xterm.js `Terminal` in the DOM at all times
- Switching sessions: disconnect old WS, clear buffer, connect new WS, replay scrollback from server
- Pro: Minimal memory/DOM overhead
- Con: No instant switching (small delay for scrollback replay)

**Option B: Multiple hidden xterm.js instances**
- One `Terminal` per session, only one visible at a time
- Switching: `display:none`/`display:block`
- Pro: Instant switching, buffer preserved client-side
- Con: Memory grows with session count; WebGL context limit (~8-16 per page)

**Recommendation:** Option A for v1. The WebGL context limit makes Option B fragile above ~8 sessions. Option A is simpler and aligns with the htmx philosophy of server-as-source-of-truth (scrollback replayed from server, not cached in browser).

### 6.5 Estimated JS Budget

| Component | Size (minified) | Purpose |
|-----------|----------------|---------|
| xterm.js | ~230KB | Terminal emulation |
| xterm-addon-fit | ~3KB | Auto-resize |
| xterm-addon-web-links | ~5KB | Clickable URLs |
| Custom session manager | ~5KB | WS management, session switching |
| **Total** | **~243KB** | |

This is comparable to the existing htmx.min.js (~14KB) + marked.min.js + highlight.js already loaded. The terminal page would load xterm.js only on `/terminal` (not globally).

---

## 7. Key Design Decisions Summary

| Decision | Choice | Rationale | Alternative Rejected |
|----------|--------|-----------|---------------------|
| Session list style | Sidebar panel | Scales to 10+ sessions; shows metadata | Horizontal tab bar (breaks at 6+) |
| Session switching | Single xterm, swap WS | Memory-safe, no WebGL limit | Multi-instance (WebGL limit at ~8) |
| Session lifecycle | 5-state machine | Covers all real states | 3-state (too coarse for debugging) |
| Provider model | Separate from type | Future multi-provider routing | Flat enum (can't distinguish GPT agent from Claude agent) |
| Mobile approach | Read-only default | Soft keyboard UX is terrible | Full interaction (frustrating) |
| Watchtower integration | Dedicated page + task embed | Power users need full page; casual needs task context | Only embedded (too cramped) |
| htmx/WS split | htmx for chrome, WS for I/O | Preserves Watchtower architecture | Full WS (breaks htmx pattern) |

---

## 8. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| xterm.js bundle size (230KB) | Slower page load | Lazy-load only on `/terminal` page |
| WebGL context limit | Crashes with many instances | Single-instance architecture (Option A) |
| WebSocket reconnection | Lost output during network blips | Server-side scrollback buffer; reconnect with replay |
| Session cleanup | Orphaned PTY processes | Server-side reaper with TTL; leverage TermLink cleanup |
| Browser tab close ≠ session close | Resource leak | Session TTL; "Running sessions" count in ambient strip |
| Mobile keyboard covers terminal | Unusable on phone | Read-only default; viewport-aware resize |

---

## References

- [VS Code Terminal Basics](https://code.visualstudio.com/docs/terminal/basics)
- [VS Code Terminal UI and Layout (DeepWiki)](https://deepwiki.com/microsoft/vscode/9.6-terminal-ui-and-layout)
- [JupyterLab Terminal Documentation](https://jupyterlab.readthedocs.io/en/stable/user/terminal.html)
- [JupyterLab Interface](https://jupyterlab.readthedocs.io/en/stable/user/interface.html)
- [Portainer Container Console](https://docs.portainer.io/user/docker/containers/console)
- [Cockpit Multi-Host Management](https://cockpit-project.org/guide/latest/multi-host)
- [Tabby Features](https://tabby.sh/about/features)
- [xterm.js](https://xtermjs.org/)
- [xterm.js Multi-Instance Discussion (#4379)](https://github.com/xtermjs/xterm.js/issues/4379)
- [GoTTY](https://github.com/yudai/gotty)
