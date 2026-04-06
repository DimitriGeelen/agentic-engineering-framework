---
id: T-962
name: "Web terminal in Watchtower — browser-based interactive terminal with TermLink integration, multi-session architecture for future orchestrator"
description: >
  Deep inception: embed interactive terminal in Watchtower web UI. Research OSS web terminal
  libraries (xterm.js, terminado, ttyd), Flask/WebSocket PTY integration, TermLink session
  convergence, multi-session UI patterns, security model, and orchestrator-aware design for
  future multi-agent/multi-provider routing. 7 parallel research vectors via TermLink dispatch.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-06T17:50:09Z
last_update: 2026-04-06T17:50:09Z
date_finished: null
---

# T-962: Web terminal in Watchtower — browser-based interactive terminal with TermLink integration, multi-session architecture for future orchestrator

## Problem Statement

The human works in terminals constantly. Watchtower is the governance dashboard (tasks, audits, approvals, inception decisions). These are separate worlds: look at Watchtower, switch to a terminal to act. The web terminal collapses that gap — approve a Tier 0 action, check the audit, and interact with a Claude session in one browser tab.

**For whom:** The framework operator (human) who currently switches between 3-5 terminal windows and a browser.
**Why now:** Watchtower is mature (20+ pages), TermLink provides session management primitives, T-608 (Tier 0 approval surface) and T-644 (landing page refactor) created the approval/action patterns. The pieces exist — this connects them.

**Future design consideration:** If the web terminal can host one agent session, it can host N. And if N Claude sessions, then sessions from different providers. The architecture must be multi-session from day one (session list, tabs, labels) so a future orchestrator (multi-agent/multi-provider routing) is an expansion, not a rewrite.

## Assumptions

- A-001: Mature OSS web terminal libraries exist that can embed in Flask/Jinja pages (xterm.js, terminado)
- A-002: Flask can serve WebSocket connections alongside HTTP (Flask-SocketIO or similar)
- A-003: A PTY bridge (Python process ↔ WebSocket ↔ browser terminal) is technically feasible with acceptable latency
- A-004: TermLink sessions can be attached/streamed through a WebSocket proxy (TermLink PTY output → browser)
- A-005: Multi-session tab UI can be built with standard web components (no heavy frontend framework needed)
- A-006: Security model for LAN-only web terminal is manageable (no internet exposure, Traefik auth optional)
- A-007: The architecture can support future multi-provider agent routing without rewrite

## Exploration Plan

7 parallel research vectors, dispatched via TermLink:

1. **OSS Web Terminal Libraries** (30min) — Survey xterm.js, Terminal.js, hterm, jquery.terminal. Compare: maturity, maintenance, features (color, resize, unicode), embedding ease, bundle size, license.
2. **Server-Side PTY Bridges for Python** (30min) — Research pyxtermjs, terminado, Flask-SocketIO, websockify. How does Flask serve a terminal? WebSocket ↔ PTY. Latency, reliability, reconnection.
3. **Existing Full Solutions** (30min) — Evaluate ttyd (C), Wetty (Node), GoTTY (Go), shellinabox, code-server terminal. Could we embed/proxy rather than build from scratch? Integration with Flask.
4. **TermLink Integration Architecture** (30min) — How TermLink sessions map to browser terminal tabs. Can `termlink pty output/inject` be bridged through WebSocket? Attach, stream, signal from browser.
5. **Multi-Session UI Patterns** (30min) — How VS Code, JupyterHub, Portainer, Cockpit handle multiple terminals. Tab/pane/split UX. Session labeling, lifecycle indicators.
6. **Security Model** (30min) — Authentication for web shell (Traefik basic auth, session tokens), session isolation, what if Watchtower is LAN-exposed. Attack surface analysis.
7. **Orchestrator-Aware Design** (30min) — Multi-provider session routing patterns. How CrewAI/AutoGen/LangGraph handle multi-agent dispatch. What the terminal data model needs to support N agents across M providers. Provider-neutral session abstraction.

## Technical Constraints

- Watchtower is Flask/Jinja with htmx and PicoCSS — no React/Vue/heavy frontend framework
- Watchtower runs on LAN (`:3000` dev, `:5050`/`:5051` prod via Traefik)
- TermLink is Rust binary with PTY session management — 26 commands, WebSocket not native
- Python 3.9+ required (framework baseline)
- Browser support: modern Chrome/Firefox/Safari — no IE
- Must work without internet (LAN-only deployment)
- No Node.js build step for frontend (keep htmx simplicity) unless justified
- WebSocket support needed for real-time terminal I/O

## Scope Fence

**IN scope (this inception):**
- Research all 7 vectors above
- Evaluate build-vs-embed trade-off
- Design multi-session data model (future-proof for orchestrator)
- Architecture recommendation with TermLink integration
- Security posture assessment
- Go/no-go with evidence

**OUT of scope:**
- Building the terminal (that's build tasks after GO)
- Implementing the orchestrator (future work, design consideration only)
- Multi-provider agent routing implementation
- Mobile terminal UX (research only)
- Changes to TermLink itself (if needed, separate tasks)

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] 7 research vectors completed (TermLink dispatch)
- [ ] Research artifact created at `docs/reports/T-962-web-terminal-research.md`
- [ ] Assumptions tested with evidence
- [ ] Architecture recommendation with multi-session data model
- [ ] Recommendation written with go/no-go rationale

### Human
- [ ] [REVIEW] Review research findings, architecture recommendation, and orchestrator design considerations
  **Steps:**
  1. Read `docs/reports/T-962-web-terminal-research.md`
  2. Evaluate: does the recommended approach fit the Watchtower stack (Flask/htmx)?
  3. Evaluate: is the multi-session data model sufficient for future orchestrator expansion?
  4. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-962 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded with specific feedback on architecture choice
  **If not:** Ask agent for clarification on specific vectors

## Go/No-Go Criteria

**GO if:**
- A mature, maintained OSS web terminal library exists that embeds in Flask/Jinja without heavy frontend framework
- PTY bridge latency is acceptable (<100ms round-trip for keystrokes)
- TermLink session attachment through WebSocket proxy is technically feasible
- Multi-session architecture is achievable without rewriting Watchtower's frontend stack
- Security model for LAN deployment is manageable (no showstopper attack surface)

**NO-GO if:**
- All viable web terminal solutions require React/Vue/heavy frontend framework (breaks Watchtower stack)
- PTY bridge introduces unacceptable latency or reliability issues
- TermLink integration requires WebSocket support in TermLink itself (scope explosion)
- Security surface of web shell is too large for LAN deployment without full auth system
- Multi-session data model requires infrastructure not justified by current needs

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
