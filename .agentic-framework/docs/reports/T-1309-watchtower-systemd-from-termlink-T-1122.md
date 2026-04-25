# T-1122 — Watchtower WSGI migration (DEFER on swap; GO on systemd)

**Date:** 2026-04-18
**Status:** Recommendation DEFER on WSGI swap, GO on systemd wrapping; awaiting human decision.
**Origin task:** `.tasks/active/T-1122-migrate-watchtower-from-werkzeug-dev-ser.md`

## What was proposed

Migrate Watchtower from Werkzeug development server to a production-grade WSGI (gunicorn / waitress / hypercorn). Motivated by the dev-server warning and observed restart races during a recent session.

## Recommendation

**DEFER on WSGI swap; GO on systemd wrapping (the actual root cause).**

The failure mode that matters ("restart races") is a process-management problem, not a WSGI-server problem. Swapping the server does not fix restart races; systemd does. The Werkzeug warning is aesthetic on a single-host LAN tool. Adding gunicorn + gevent + flask-socketio_websocket adds dependency surface without proportional benefit.

## Findings

### Spike 1 — server comparison

| Server | Linux | macOS | WebSocket | Multi-worker safe with our hooks? |
|---|---|---|---|---|
| **waitress** | ✓ | ✓ | ✗ (long-poll fallback only) | N/A — single-process |
| **gunicorn + gevent** | ✓ | ✗ (no Windows; macOS uneven) | ✓ via gevent-websocket | ✗ — multi-worker would race `.tool-counter` and `_client_sessions` |
| **hypercorn** | ✓ | ✓ | ✓ via ASGI | Behavior change for Flask-SocketIO; not drop-in |
| **Werkzeug + socketio.run** (status quo) | ✓ | ✓ | ✓ via socketio threading mode | ✓ — single-process |

### Spike 2 — compatibility

- App exposes WSGI callable: `web.app:app` at `web/app.py:376` — confirmed.
- `SocketIO(app, async_mode="threading")` at `web/app.py:159` is single-process by design.
- Multi-worker WSGI would break: (a) websocket session affinity, (b) framework hook counters, (c) in-process `_client_sessions` dict.

### Spike 3 — hooks/signals

- The framework's PreToolUse/PostToolUse hooks update `.context/working/.tool-counter` from each tool call. Multi-worker WSGI = race-prone. Single-worker is the only safe option, which negates the main concurrency argument for migration.

### Spike 4 — startup ergonomics

- Restart-race fix: systemd (`Restart=on-failure`, `Type=notify`, `KillMode=mixed`). Independent of WSGI choice.

## Proposed follow-up tasks (post-DEFER on swap, GO on systemd)

1. **[framework, S]** Ship `watchtower.service` systemd unit template under `agents/monitor/`. `Type=notify` if practical, otherwise `Type=simple` with PIDFile. `Restart=on-failure`, `RestartSec=2`.
2. **[framework, XS]** `fw watchtower start` learns to detect a systemd unit and prefer `systemctl --user start watchtower` over direct spawn when installed.
3. **[framework, XS]** Suppress the Werkzeug warning in production-mode startup OR document explicitly in CLAUDE.md that the warning is acceptable on a single-host LAN tool.

## Reopen if

- Watchtower is exposed across LAN with auth, or
- Web terminal sees real production load, or
- Multi-host federation lands.

Then the WSGI-swap calculus changes (multi-worker becomes valuable; HTTPS/TLS becomes mandatory; gevent overhead is justified).

## The mistake to avoid

Swapping the WSGI server is a tempting "production-ize" move that doesn't address the actual symptom (restart races) and adds dependency surface. Fix the cause (no process supervisor), not the smell (the warning string).

## Decision path

```
fw inception decide T-1122 no-go --rationale "DEFER on WSGI swap; replaced by systemd wrapping (T-N) and watchtower start systemd-aware (T-N) and Werkzeug-warning suppression (T-N)"
```
(or `go` if the human prefers the full migration regardless of the cost/benefit analysis.)
