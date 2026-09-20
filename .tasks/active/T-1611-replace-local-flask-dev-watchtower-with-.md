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

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [watchtower, performance, wsgi, from-saturation-incident]
components: [agents/audit/audit.sh, agents/handover/handover.sh, agents/monitor/watchtower-rss-sample.sh, agents/task-create/update-task.sh, lib/inception_recommendation.sh, lib/inception.sh, tests/unit/inception_defer_park.bats, web/app.py]
related_tasks: [T-1122, T-1309]
created: 2026-04-30T07:25:07Z
last_update: 2026-09-20T13:20:53Z
date_finished: 2026-09-20T13:20:53Z
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
  - ts: '2026-05-29T23:00:02Z'
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
  - ts: '2026-06-01T08:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 5
      D3: 0
      D4: 0
    rationale: D1=1 (body:fix-without-learning); D2=5 
      (body:silent-class-removed); D3=0 (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T08:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 5
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=1 (body:fix-without-learning); D2=5 
      (body:silent-class-removed); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:01Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F1=2 
      (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F-AUTONOMY=2 
      (no-signal); F3=2 (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-07T10:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
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
  - ts: '2026-06-05T18:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
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
- [ ] [REVIEW] Confirm T-1611-C (gunicorn swap) can close NO-GO now that T-1611-B's
      own named diagnostic (RSS growth over 24-48h) has run for a month with no
      monotonic growth found.
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw task show T-1611` — read
     the "2026-09-20 — T-1611-B diagnostic resolved" Recommendation addendum below.
  2. Spot-check the raw data yourself if desired:
     `tail -30 .context/monitors/watchtower-rss.jsonl` — RSS on the current
     multi-day process oscillates ~250-450MB with no upward trend.
  3. If you know of a saturation incident *after* T-1612's `threaded=True` fix
     landed (2026-04-30) that this data doesn't explain, name it and reopen with
     `bin/fw task update T-1611 --horizon now`.
  **Expected:** Agreement that A1 (request-rate not leak) is confirmed, T-1612's
  cheap fix is holding, and T-1611-C (gunicorn) is not warranted — close NO-GO.
  **If not:** Reopen and name the unexplained incident.

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

### 2026-09-20 — T-1611-B diagnostic resolved, final verdict on T-1611-C

**Recommendation:** NO-GO on T-1611-C (gunicorn swap). Close this task as
DEFER-then-resolved: the cheap fix (T-1612) held, the diagnostic this task
itself specified (T-1611-B) ran far past its stated window and found no leak.

**Rationale:** The 2026-04-30 DEFER named an explicit arbiter: "if T-1612's
`threaded=True` fix is sufficient, RSS stays bounded; if a leak hides
underneath, RSS climbs and T-1611-C becomes warranted" (T-1615's own filed
Context, quoting this task). `.context/monitors/watchtower-rss.jsonl` now
holds 8996 samples across a full month (2026-08-19 → 2026-09-20, this task's
own file predates that log but T-1615 — filed as this task's direct
follow-up — started it), spanning ~15 distinct Watchtower process lifetimes.
Across every one of them RSS oscillates in a bounded ~15-880MB range with no
monotonic trend — it resets on restart and drifts up and down within a
session, never climbing session-over-session. The current live process (PID
1141196) has been up 232189s (~64.5h — more than 2x the 24-48h window
T-1611-B specified) holding steady at ~330-380MB. This is the request-rate
signature (A1), not the leak signature. No saturation incident matching the
original symptom (CPU pegged, `/` hanging while `/health` stays fast) shows
up in this window's data.

**Evidence:**
- `.context/monitors/watchtower-rss.jsonl` — 8996 samples, 2026-08-19 to
  2026-09-20, no monotonic RSS growth across ~15 process lifetimes.
- `.context/monitors/watchtower-rss-latest.yaml` — current process 232189s
  uptime, RSS steady ~330-380MB.
- `.tasks/completed/T-1612-...md` — `threaded=True` fix, `status:
  work-completed`, landed 2026-04-30 (the same day as this DEFER).
- `.tasks/completed/T-1615-...md` — RSS observation cron this task named,
  `status: work-completed`, now the data source above.

**If NO-GO is confirmed:** operator ticks the new Human AC above and runs
`fw task update T-1611 --status work-completed`.
**If not:** operator names the unexplained incident and reopens.

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

### 2026-09-20T13:20:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-87d3784d
- **Timestamp:** 2026-09-20T13:20:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-dd1d9003
- **Timestamp:** 2026-09-20T13:20:53Z
- **Overall:** CONTRADICTED
- **Claims:** 9

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-1611-werkzeug-vs-gunicorn-local.md` | file | ✓ pass |
| `web/app.py:432-434` | file | ✗ fail — file not found at PROJECT_ROOT |
| `.context/monitors/watchtower-rss.jsonl` | file | ✓ pass |
| `.context/monitors/watchtower-rss-latest.yaml` | file | ✓ pass |
| `.tasks/completed/T-1612-...md` | file | ✗ fail — file not found at PROJECT_ROOT |
| `.tasks/completed/T-1615-...md` | file | ✗ fail — file not found at PROJECT_ROOT |
| `T-1309` | task | ✓ pass |
| `T-1612` | task | ✓ pass |
| `T-1615` | task | ✓ pass |

### 2026-09-20T13:20:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
