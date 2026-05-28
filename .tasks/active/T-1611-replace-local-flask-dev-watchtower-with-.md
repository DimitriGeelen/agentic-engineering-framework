---
id: T-1611
name: "Swap local Watchtower Werkzeug dev server for gunicorn — saturation under browser
  auto-refresh"
description: >
  Local Watchtower (python -m web.app on :3000) saturates after long uptime under
  browser auto-refresh + htmx polling. 33h uptime + LAN browser open → 52% CPU, /health
  responds but / hangs >10s, sequential localhost curls all timeout. T-1122 (TermLink)
  concluded WSGI swap was unwarranted because Flask-SocketIO threading mode "should"
  handle load; today's evidence contradicts that. T-1309 covers systemd wrapping (restart
  hygiene), separate concern. This inception asks: should we run gunicorn locally
  too, instead of Werkzeug dev server?

status: captured
workflow_type: inception
owner: agent
horizon: later
tags: [watchtower, performance, wsgi, from-saturation-incident]
components: []
related_tasks: [T-1122, T-1309]
created: 2026-04-30T07:25:07Z
last_update: '2026-05-28T22:54:09Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 5
      D3: 0
      D4: 0
    rationale: D1=1 (body:fix-without-learning); D2=5 
      (body:silent-class-removed); D3=0 (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 5
      D3: 0
      D4: 0
      F1: 0
    rationale: D1=1 (body:fix-without-learning); D2=5 
      (body:silent-class-removed); D3=0 (no-signal); D4=0 (no-signal); F1=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 5
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=5 
      (body:silent-class-removed); D3=0 (no-signal); D4=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1611: Swap local Watchtower Werkzeug dev server for gunicorn — saturation under browser auto-refresh

## Problem Statement

The local Watchtower (`python -m web.app --port 3000`) becomes unresponsive after extended uptime under realistic browser load. Today's incident: 33h uptime, LAN browser open with auto-refresh + htmx polling, process at 52% CPU, `/health` responds in <50ms but `/` hangs past 10s, three sequential localhost curls all timeout. Production on LXC 170 (`:5050`) uses gunicorn and does not exhibit this. T-1122's analysis (TermLink, 2026-04-04) concluded "Flask-SocketIO threading mode handles single-host LAN load, WSGI swap unwarranted" — today's evidence contradicts that conclusion for long-uptime browser-driven traffic.

This is distinct from T-1309 (systemd wrapping for restart hygiene) — restart was not involved. Distinct from T-403 (read-time YAML error rendering). The question is whether Werkzeug-dev-server is the right serving layer for an always-on local instance.

## Assumptions

1. Saturation is request-rate-driven, not memory-leak-driven (gunicorn would help if A1 holds; would not if it's a leak).
2. Gunicorn with 2-4 workers handles current LAN browser load in <500ms p99 on the same host.
3. `socketio.run()` with `allow_unsafe_werkzeug=True` (web/app.py:432) is the saturating layer; fallback `app.run()` (line 434) would have the same problem.
4. SocketIO sessions survive gunicorn workers when configured with `--worker-class eventlet` or `--worker-class gevent` (else SocketIO breaks).
5. Existing prod recipe on LXC 170 (`/opt/watchtower-prod`, gunicorn) is portable to local with minimal config.

## Exploration Plan

Three spikes (each <20min):

- **Spike 1 — confirm root cause is request-rate not memory:** RSS sample on saturated PID before/during/after a quiet window. If RSS climbs monotonically with uptime, it's a leak (gunicorn alone won't fix). If RSS is steady but CPU pegs only under load, it's serving capacity.
- **Spike 2 — read prod gunicorn recipe:** read `/opt/watchtower-prod`'s systemd unit + gunicorn invocation. Capture: worker count, worker class (eventlet/gevent for SocketIO?), bind address, timeout settings.
- **Spike 3 — local gunicorn dry-run:** start gunicorn against `web.app:app` with the prod-recipe args on a different port (:3010), hammer with parallel curl loop, compare p99 latency vs Werkzeug.

All three documented in `docs/reports/T-1611-werkzeug-vs-gunicorn-local.md`.

## Technical Constraints

- Local dev workflow uses `bin/watchtower.sh` start/stop/restart — must continue to work
- Triple-file source-of-truth (`watchtower.url` / `watchtower.port` / PID) must be updated by gunicorn launcher
- SocketIO support must survive (T-1597 events, fleet topology streaming)
- macOS bash 3.2 compat (T-518) — no `declare -A` in the launcher
- Cannot regress on cold-start time — Werkzeug starts in <1s; gunicorn with eventlet should match

## Scope Fence

**IN scope:**
- Decide whether `bin/watchtower.sh start` should launch gunicorn instead of `python -m web.app`
- Worker class + count recommendation
- Compatibility with triple-file PID/port/url tracking
- Local-only — no LXC 170 changes

**OUT of scope (deferred):**
- Systemd wrapping (T-1309 owns this)
- Production deployment changes (LXC 170 already uses gunicorn)
- Changes to `app.py`'s `__main__` block (keep it as a fallback dev entrypoint)
- Memory-leak hunt (separate task if Spike 1 reveals a leak)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1611` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Spike 1 confirms request-rate cause (gunicorn helps), not memory leak (it wouldn't)
- Spike 3 shows gunicorn p99 < Werkzeug p99 by 2x or more under realistic load
- SocketIO compatibility verified with chosen worker class
- Launcher integration is contained to `bin/watchtower.sh` (no `web/app.py` changes required)

**NO-GO if:**
- Spike 1 shows monotonic memory growth — fix is a leak hunt, not a server swap
- Spike 3 shows gunicorn no faster than Werkzeug — root cause is downstream (handler logic, fabric loads)
- SocketIO breaks on every gunicorn worker class — would need substantial app refactor

## Verification

# Inception — no verification commands; decision artifact only.

## Recommendation

- **Recommendation:** DEFER
- **Rationale:** Cheaper one-line fix (Werkzeug `threaded=True` + explicit SocketIO `async_mode='threading'`) not yet tried. Gunicorn path blocked on missing eventlet/gevent deps + prod recipe lives on LXC 170 (not in repo). T-1309 already covers always-on hygiene via systemd. Memory profile (651MB RSS cold-start) suggests leak risk that gunicorn alone wouldn't fix. Sequence as T-1611-A (cheap fix), T-1611-B (RSS observation), T-1611-C (gunicorn swap only if needed).
- **Evidence:**
  - Research artifact: `docs/reports/T-1611-werkzeug-vs-gunicorn-local.md` (Spikes 1, 2, 4; Spike 3 skipped with rationale)
  - Saturation symptom: PID 3642923 at 52% CPU after 33h, sequential localhost curls timeout while LAN gets 200s (queueing, not crash)
  - Restart cleared it (HTTP 200 in 240ms post-restart on PID 1147671)
  - eventlet/gevent NOT installed → gunicorn sync worker would break SocketIO
  - Existing pattern: `web/app.py:432-434` makes `threaded=True` a one-line change
  - T-1309 owns systemd wrapping (auto-restart on hang) — complementary, addresses different concern

## Decisions

<!-- Record decisions ONLY when choosing between alternatives. -->

## Decision

**Decision**: DEFER

**Rationale**: Cheaper one-line fix (Werkzeug `threaded=True` + explicit SocketIO `async_mode='threading'`) not yet tried. Gunicorn path blocked on missing eventlet/gevent deps + prod recipe lives on LXC 170 (not in repo). T-1309 already covers always-on hygiene via systemd. Memory profile (651MB RSS cold-start) suggests leak risk that gunicorn alone wouldn't fix. Sequence as T-1611-A (cheap fix), T-1611-B (RSS observation), T-1611-C (gunicorn swap only if needed).

**Date**: 2026-04-30T08:48:46Z

## Updates

<!-- Auto-populated by git mining at task completion. -->

### 2026-04-30T08:48:46Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** Cheaper one-line fix (Werkzeug `threaded=True` + explicit SocketIO `async_mode='threading'`) not yet tried. Gunicorn path blocked on missing eventlet/gevent deps + prod recipe lives on LXC 170 (not in repo). T-1309 already covers always-on hygiene via systemd. Memory profile (651MB RSS cold-start) suggests leak risk that gunicorn alone wouldn't fix. Sequence as T-1611-A (cheap fix), T-1611-B (RSS observation), T-1611-C (gunicorn swap only if needed).

### 2026-05-15T19:54:39Z — status-update [task-update-agent]
- **Change:** horizon: now → later
- **Change:** status: started-work → captured (auto-sync)
- **Reason:** T-1865 sweep: DEFER limbo recovery
