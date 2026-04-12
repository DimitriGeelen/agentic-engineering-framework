# T-962: Web Terminal in Watchtower — Research Report

## Overview

Research into embedding interactive terminal sessions in the Watchtower web UI,
with TermLink integration and multi-session architecture for future orchestrator expansion.

7 parallel research vectors dispatched via TermLink. All completed successfully.

## Research Vectors

| # | Report | Size | Key Finding |
|---|--------|------|-------------|
| 1 | [OSS Terminal Libraries](T-962-v1-oss-terminals.md) | 11KB | **xterm.js is the clear winner** — 20.2k stars, MIT, zero deps, framework-agnostic, used by VS Code |
| 2 | [PTY Bridges for Python](T-962-v2-pty-bridges.md) | 20KB | **Flask-SocketIO + custom PTY manager** recommended; ttyd sidecar as alternative |
| 3 | [Full Solutions](T-962-v3-full-solutions.md) | 22KB | **Build > Embed** — ttyd is good but capped at isolated iframes; xterm.js gives deep integration |
| 4 | [TermLink Integration](T-962-v4-termlink-integration.md) | 26KB | **Hybrid architecture** — Flask-owned PTYs for interactive, TermLink polling for observation |
| 5 | [Multi-Session UI](T-962-v5-multi-session-ui.md) | 38KB | **Tab bar + viewport pattern** (VS Code style); session data model with provider/type fields |
| 6 | [Security Model](T-962-v6-security-model.md) | 27KB | **Origin-checked WebSocket + CSRF tokens** sufficient for LAN v1; no full auth needed |
| 7 | [Orchestrator Design](T-962-v7-orchestrator-design.md) | 23KB | **Provider registry pattern** — design for N, build for 1; TermLink as discovery layer, not session authority |

## Synthesis

### Architecture Decision: Build with xterm.js + Flask-SocketIO

All 7 vectors converge on the same architecture:

1. **Frontend:** xterm.js (v6, zero deps, works with plain JS — no React/Vue needed)
2. **Transport:** Flask-SocketIO (WebSocket, fits existing Flask stack)
3. **Backend:** Custom PTY manager (fork/extend pyxtermjs pattern for multi-session)
4. **TermLink:** Hybrid integration — Flask spawns PTYs directly, registers with TermLink for discoverability. TermLink polling (~50-200ms) is adequate for monitoring but not for interactive use. Interactive sessions use direct PTY file descriptors through Flask.
5. **UI:** Tab bar + viewport pattern (modeled on VS Code terminal). Session metadata includes type, provider, task ID, status, color. Tabs are horizontally scrollable.
6. **Security:** Origin-checked WebSocket, CSRF-protected session tokens, dedicated unprivileged user for PTY processes. LAN-only v1 doesn't need full auth.

### Why Not Embed ttyd?

ttyd (11.4k stars, C, excellent tool) was seriously considered. The embed approach is simpler initially but hits a hard ceiling:
- **Isolation:** ttyd runs as a separate process — no shared state with Watchtower
- **Theming:** Can't inherit PicoCSS dark theme natively (would need CSS injection)
- **Session control:** No programmatic session management from Watchtower
- **TermLink:** No TermLink integration without custom bridge code
- **Orchestrator:** Can't extend to multi-provider routing

**Verdict:** ttyd as "pop-out terminal" fallback is fine, but the core must be xterm.js for deep integration.

### Multi-Session Data Model (v1, orchestrator-ready)

```json
{
  "id": "ts-a1b2c3d4",
  "name": "claude-T962",
  "type": "shell | claude | termlink | agent",
  "state": "connecting | running | idle | exited | error",
  "provider": {
    "name": "shell | claude-code | openai | ollama",
    "model": "opus-4",
    "display_name": "Claude Code"
  },
  "task_id": "T-962",
  "tags": ["inception", "research"],
  "connection": { "ws_path": "/ws/terminal/ts-a1b2c3d4" },
  "capabilities": ["interactive", "streaming", "tools"],
  "created_at": "2026-04-06T18:00:00Z",
  "tokens": { "in": 0, "out": 0 }
}
```

### v1 Must-Do to Not Block v2 (Orchestrator)

1. Session schema includes `provider` and `type` fields from day one
2. Session registry is separate from TermLink (sessions.yaml or in-memory dict)
3. WebSocket protocol carries `session_id` and `type` in every message
4. "New Session" UI uses a provider registry (even if hardcoded to 2 entries)
5. Token metrics tracked per-session from the start

### v1 Can Safely Ignore

- Multi-provider API routing (Claude API, OpenAI API)
- Agent-to-agent communication
- Load balancing / cost optimization across providers
- Session handoff between providers
- Mobile terminal input (mobile is read-only in v1)

### Assumption Validation

| # | Assumption | Result |
|---|-----------|--------|
| A-001 | Mature OSS terminal libraries exist for Flask/Jinja | **VALIDATED** — xterm.js, zero deps, pure JS |
| A-002 | Flask can serve WebSocket | **VALIDATED** — Flask-SocketIO, well-maintained |
| A-003 | PTY bridge is feasible with acceptable latency | **VALIDATED** — <10ms for direct PTY fd, pyxtermjs pattern proven |
| A-004 | TermLink sessions can be observed through WebSocket | **VALIDATED** — polling at 50-200ms, adequate for monitoring |
| A-005 | Multi-session tab UI works without heavy frontend | **VALIDATED** — tab bar + xterm.js instances, htmx for session management |
| A-006 | Security for LAN is manageable | **VALIDATED** — origin check + CSRF sufficient for v1 |
| A-007 | Architecture supports future multi-provider | **VALIDATED** — provider registry pattern, type/provider separation |

### Constitutional Alignment

- **D1 Antifragility:** Single browser tab reduces context-switching failure modes. TermLink observation from browser adds resilience.
- **D2 Reliability:** WebSocket reconnection handling needed (Flask-SocketIO handles this). Session state persistence across page reloads.
- **D3 Usability:** Massive UX win — governance dashboard + terminal in one interface. Tab bar pattern is familiar.
- **D4 Portability:** xterm.js is pure JS (no build step for consumer). Flask-SocketIO adds one pip dependency. No provider lock-in.

### Implementation Estimate

| Phase | Scope | Effort |
|-------|-------|--------|
| 1 | Single terminal (xterm.js + Flask-SocketIO + PTY) | 1 session |
| 2 | Multi-session tabs + session management | 1 session |
| 3 | TermLink integration (observe existing sessions) | 1 session |
| 4 | Session profiles + provider registry | 1 session |

## Recommendation

**Recommendation:** GO

**Rationale:** All 7 assumptions validated. The technology stack (xterm.js + Flask-SocketIO) fits Watchtower's existing architecture (Flask/Jinja/htmx) with minimal new dependencies. The multi-session data model is orchestrator-ready without over-engineering v1. Security posture for LAN v1 is clean. Strong constitutional alignment across all 4 directives.

**Evidence:**
- xterm.js: 20.2k stars, MIT, zero deps, used by VS Code — proven at scale
- Flask-SocketIO: active maintenance, native Flask integration, handles reconnection
- pyxtermjs pattern: working Flask terminal exists, needs multi-session extension
- TermLink hybrid: polling for observation, direct PTY for interaction — covers both use cases
- Security: origin check + CSRF sufficient for single-user LAN (V6 threat model confirms)
- Orchestrator: provider registry + type/provider separation prevents v2 rewrite (V7 analysis)

**Risk:** Medium. WebSocket adds complexity to Watchtower's currently-simple request/response model. Flask-SocketIO requires eventlet or gevent worker. Terminal UX expectations are high — users compare against VS Code.

**Mitigation:** Phase 1 (single terminal) validates the WebSocket integration before committing to multi-session. If Flask-SocketIO proves problematic, ttyd sidecar is a clean fallback.
