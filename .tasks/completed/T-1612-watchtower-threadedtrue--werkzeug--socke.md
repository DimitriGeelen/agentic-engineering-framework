---
id: T-1612
name: "Watchtower threaded=True — Werkzeug + SocketIO saturation cheap fix (T-1611-A)"
description: >
  Watchtower threaded=True — Werkzeug + SocketIO saturation cheap fix (T-1611-A)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-30T07:44:04Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-30T07:46:12Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1612: Watchtower threaded=True — Werkzeug + SocketIO saturation cheap fix (T-1611-A)

## Context

T-1611 inception DEFER recommendation: try the cheap fix first before investing in gunicorn swap. Add `threaded=True` to `web/app.py` Werkzeug calls so concurrent requests don't queue head-of-line. See `docs/reports/T-1611-werkzeug-vs-gunicorn-local.md` Spike 4.

## Acceptance Criteria

### Agent
- [x] `web/app.py:434` `app.run(...)` passes `threaded=True`
- [x] `web/app.py:432` `socketio.run(...)` confirmed to use threading mode (Flask-SocketIO default async_mode='threading' when eventlet/gevent absent — verified in T-1611 Spike 2)
- [x] After restart, three concurrent localhost curls to `/` all return 200 within 1s (was 10s timeout pre-fix)
- [x] `web/app.py` still parses (`python3 -c "import ast; ast.parse(open('web/app.py').read())"`)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

python3 -c "import ast; ast.parse(open('web/app.py').read())"
grep -q "threaded=True" web/app.py

## RCA

**Symptom:** Watchtower local Flask instance unresponsive after 33h uptime under browser auto-refresh + htmx polling. PID 3642923 at 52% CPU; `/health` <50ms but `/` hangs >10s; three sequential localhost curls all timeout while LAN browser gets 200s in the same window. Restart cleared it.

**Root cause:** `web/app.py:434` `app.run(...)` did not pass `threaded=True` — Werkzeug serialized concurrent requests through a single worker. Under realistic browser load (auto-refresh + htmx polls), local curl requests queued behind in-flight LAN requests and timed out at 10s before the queue cleared. Flask-SocketIO's `socketio.run()` (the active branch when SocketIO is registered) uses `async_mode='threading'` by default when eventlet/gevent are absent, but the SocketIO threading strategy still serializes HTTP handlers on a single worker thread.

**Why structurally allowed:** No regression test verifies concurrent request handling at the local Watchtower. T-1122 inception (TermLink, 2026-04-04) DEFER'd a WSGI swap on the assumption that "Flask-SocketIO threading mode handles single-host LAN load" — without measurement. No monitoring on `/` p99 latency or RSS-over-time. The `app.run()` fallback branch carried the same defect.

**Prevention:**
1. This fix (`threaded=True`) ships as a regression-resistant default.
2. Follow-up T-1611-B (RSS observation cron, ~5 lines) will catch leak-driven re-saturation distinct from queueing.
3. Add a concurrent-request smoke check to `tests/web/` so future serving-layer changes don't silently regress to single-threaded handling. (Sized for separate task — keep this fix bounded.)

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-30T07:44:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1612-watchtower-threadedtrue--werkzeug--socke.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7ca3e515
- **Timestamp:** 2026-06-02T14:58:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T07:46:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
