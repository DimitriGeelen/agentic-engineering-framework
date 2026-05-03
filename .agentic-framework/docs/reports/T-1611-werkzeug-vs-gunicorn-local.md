# T-1611: Local Watchtower — Werkzeug vs gunicorn under saturation

**Status:** Inception in progress
**Date:** 2026-04-30
**Trigger:** Saturation incident at 09:22 — local Watchtower (PID 3642923, 33h uptime) at 52% CPU, `/health` <50ms but `/` hangs >10s, three sequential localhost curls timeout. Restart cleared it (HTTP 200 in 240ms post-restart). T-1122 (TermLink, 2026-04-04) had concluded WSGI swap unwarranted because Flask-SocketIO threading mode "should" handle single-host LAN load. Today's evidence contradicts that for long-uptime browser-driven traffic.

---

## Problem Statement

Local Watchtower runs `python -m web.app` (web/app.py:432 `socketio.run(...)`). After extended uptime under realistic browser load (auto-refresh + htmx polling), it becomes unresponsive. Production on LXC 170 uses gunicorn and does not exhibit this. Question: should the local launcher (`bin/watchtower.sh start`) swap Werkzeug for gunicorn too?

This is distinct from:
- **T-1309** — systemd wrapping for restart hygiene (no restart involved today)
- **T-1122** — concluded WSGI swap unwarranted; today's evidence reopens
- **T-403** — read-time YAML error rendering (different layer)

## Assumptions (test in spikes)

| # | Assumption | Spike |
|---|------------|-------|
| 1 | Saturation is request-rate, not memory leak | 1 |
| 2 | Gunicorn 2-4 workers handles current load with p99 < 500ms | 3 |
| 3 | `socketio.run()` is the saturating layer | 1 |
| 4 | SocketIO survives gunicorn with eventlet/gevent worker class | 2, 3 |
| 5 | Existing prod gunicorn recipe is portable | 2 |

## Spike Results

### Spike 1 — Memory leak vs request-rate

- Original saturated PID 3642923: 33h uptime, 52% CPU, restart cleared symptom (HTTP 200 in 240ms post-restart).
- Fresh PID 1147671 (3min uptime): 10.9% CPU, **651 MB RSS already** — that's a large baseline from cold start. Suggests a memory-heavy app (fabric loaded, episodic indexes, embeddings cache) regardless of WSGI choice.
- Saturation pattern (3 sequential localhost curls timeout WHILE concurrent LAN requests get 200) is classic single-threaded request queueing. Either:
  - `socketio.run()` runs in single-threaded mode (despite Flask-SocketIO's "threading" async_mode default), OR
  - some handler holds a global lock blocking other requests during heavy work
- **Conclusion:** evidence consistent with serving-capacity (request-rate) not memory leak. But can't fully rule out leak without time-series RSS — flag for follow-up.

### Spike 2 — Prod gunicorn recipe

- `gunicorn 25.1.0` installed locally at `/usr/local/bin/gunicorn`.
- `eventlet`, `gevent` NOT installed locally — gunicorn with default sync worker WILL BREAK Flask-SocketIO. Worker class swap requires `pip install eventlet` (or gevent + monkey-patching).
- Production recipe (LXC 170 systemd unit) is not in the framework repo — `docs/deployment-runbook.md` mentions gunicorn but no unit file or invocation. Reading the actual config requires ssh to 192.168.10.170 (out of bounded inception scope; record as follow-up).
- Without eventlet/gevent installed AND without seeing prod's exact worker class, a local gunicorn swap is premature.

### Spike 3 — Gunicorn dry-run on :3010

**Skipped** — blocked by Spike 2: cannot dry-run gunicorn without first deciding worker class, which requires the prod recipe + dep install. Reopening Spike 3 would expand scope past the inception time-box.

### Spike 4 (added) — Cheaper alternative

Reading `web/app.py:432-434`:
```python
socketio = app.extensions.get("socketio")
if socketio:
    socketio.run(app, host=host, port=port, debug=args.debug, allow_unsafe_werkzeug=True)
else:
    app.run(host=host, port=port, debug=args.debug)
```

Werkzeug's `app.run()` defaults to `threaded=False` in older versions, `threaded=True` in newer Werkzeug 2.x+. SocketIO's `async_mode` is auto-detected; without eventlet/gevent installed it falls back to "threading" — but threading mode in Flask-SocketIO uses a single worker thread for the SocketIO loop while web requests still queue.

**Cheap fix candidate:** explicitly pass `threaded=True` to `app.run()` AND verify SocketIO is actually using `async_mode='threading'` (not the silent fallback to single-thread). One-line code change, no new dependencies. If this resolves saturation, gunicorn swap is unnecessary.

## Decision Artifact

### Recommendation: DEFER

**Rationale:**
1. **Cheaper path not yet tried.** Werkzeug `threaded=True` + explicit `async_mode='threading'` is a one-line change with zero new dependencies. Try that first. If it solves the symptom, gunicorn is overkill.
2. **Gunicorn path is blocked on cross-machine work.** Need to read LXC 170's actual systemd + gunicorn invocation to portably copy the recipe. That's a separate exploration step requiring ssh.
3. **Missing dependencies.** Eventlet/gevent not installed locally. Adding them is a real change to runtime deps — needs its own consideration (compat with Werkzeug fallback, dev/prod parity).
4. **T-1309 already covers always-on hygiene.** Systemd wrapping handles auto-restart on hang/leak; combined with the cheaper threaded fix, may make WSGI swap unnecessary.
5. **Memory leak not ruled out.** 651MB RSS on cold start is heavy. If the original 33h symptom was leak-driven, gunicorn workers would just leak in parallel until OOM. Need RSS time-series before concluding gunicorn fixes it.

**Recommended sequence (separate tasks):**
1. **T-1611-A (cheap fix, ~15min build):** Set `threaded=True` on `app.run()`, set explicit `async_mode='threading'` on SocketIO. Restart. Hammer with concurrent localhost+LAN curls. If p99 < 1s, ship.
2. **T-1611-B (RSS observation, passive):** Add a 5-min cron emitting `ps -o rss <watchtower-pid>` to `.context/working/watchtower-rss.log`. After 24-48h of normal use, check for monotonic growth. Cheap, runs in background.
3. **T-1611-C (gunicorn swap, only if A+B insufficient):** Read prod recipe via ssh. Install eventlet. Update `bin/watchtower.sh start` to launch gunicorn. Verify SocketIO + triple-file integration. ~2h build.

**Why DEFER not GO:** committing to gunicorn now skips the cheap fix and locks in a heavier recipe before evidence demands it. Antifragility favors smallest reversible step that exposes the next layer of evidence.

**Why DEFER not NO-GO:** the question is real and the saturation incident is reproducible. Don't kill the inception; sequence it.

## Dialogue Log

- **2026-04-30 09:22** — User asked "why is it not responding?" Investigation showed PID 3642923 at 52% CPU after 33h uptime; `/health` fast, `/` hangs >10s; sequential localhost curls timeout while LAN gets 200s.
- **User picked option 1** (restart) — cleared symptom (HTTP 200 in 240ms).
- **User said "and incept 2"** — requested option 2 (production-grade serving) be filed as inception. This task IS option 2.
- **2026-04-30 09:35** — Spikes 1+2 ran; Spike 3 skipped due to scope; Spike 4 (cheaper alternative) emerged from reading `web/app.py`. Recommendation: DEFER pending cheap fix (T-1611-A).


## Dialogue Log

- **Trigger:** User asked "why is it not responding?" Diagnosed saturation; user picked option 1 (restart) AND requested option 2 as inception ("incept 2"). This task IS option 2.
- Inception runs in autonomous mode based on incident evidence + production recipe contrast.
