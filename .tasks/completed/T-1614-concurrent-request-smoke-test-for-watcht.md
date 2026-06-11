---
id: T-1614
name: "Concurrent-request smoke test for Watchtower — pin threaded=True, prevent single-threaded
  regression"
description: >
  Concurrent-request smoke test for Watchtower — pin threaded=True, prevent single-threaded
  regression

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-30T08:05:46Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-30T08:08:19Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1614: Concurrent-request smoke test for Watchtower — pin threaded=True, prevent single-threaded regression

## Context

T-1612 fixed Watchtower saturation by adding `threaded=True` to `web/app.py:434`. T-1612 RCA flagged "add a concurrent-request smoke check to `tests/web/` so future serving-layer changes don't silently regress to single-threaded handling." This is that test — a cheap source-level freeze that asserts the threaded flag stays set, plus a marker for the SocketIO branch's threading expectation.

## Acceptance Criteria

### Agent
- [x] New test file `tests/web/test_serving_threading.py` exists
- [x] Test asserts `web/app.py` `app.run(...)` call includes `threaded=True` (AST scan, not regex)
- [x] Test asserts `web/app.py` does NOT contain `threaded=False` (defensive)
- [x] Test asserts `socketio.run(...)` call exists (SocketIO branch present)
- [x] Test runs and passes: 3/3 pass in 40ms
- [x] Test discovered by `tests/web/conftest.py` sys.path setup (auto-discovered by pytest from tests/web/)

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

python3 -m pytest tests/web/test_serving_threading.py -v

## RCA

This task is **regression prevention**, not a bugfix — but the gate fires on the word "regression" in the title. Filling out the structure for completeness.

**Symptom (of the parent bug, T-1611/T-1612):** Local Watchtower unresponsive after 33h uptime under browser load. Sequential localhost curls timeout while LAN gets 200s.

**Root cause (parent):** `web/app.py:434` `app.run(...)` did not pass `threaded=True`. Single-thread Werkzeug serialised concurrent requests.

**Why structurally allowed (parent):** No regression test verified concurrent request handling. The fix could be silently dropped by any future refactor of `web/app.py`'s `__main__` block — nothing would notice until production hit saturation again.

**Prevention (this task):** AST-level freeze in `tests/web/test_serving_threading.py`. Three assertions:
1. `app.run()` includes `threaded=True` literal.
2. No `threaded=False` anywhere in `web/app.py`.
3. `socketio.run()` call still present (so SocketIO transport assumptions stay valid; if it changes, T-1611 reopens).

Test runs in 40ms, picked up automatically by pytest discovery from `tests/web/`. If the regression class evolves (e.g., async migration), the test will fail loudly and become the place to record the change — same harness pattern as the governance bats suite.

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

### 2026-04-30T08:05:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1614-concurrent-request-smoke-test-for-watcht.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cd31bb2b
- **Timestamp:** 2026-06-02T14:58:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#2 (Agent)** — Test asserts `web/app.py` `app.run(...)` call includes `threaded=True` (AST scan, not regex)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/app.py in: Test asserts `web/app.py` `app.run(...)` call includes `threaded=True` (AST scan, not regex)`
- **AC#3 (Agent)** — Test asserts `web/app.py` does NOT contain `threaded=False` (defensive)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/app.py in: Test asserts `web/app.py` does NOT contain `threaded=False` (defensive)`
- **AC#6 (Agent)** — Test discovered by `tests/web/conftest.py` sys.path setup (auto-discovered by pytest from tests/web/)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/web/conftest.py in: Test discovered by `tests/web/conftest.py` sys.path setup (auto-discovered by pytest from tests/web/)`
### 2026-04-30T08:08:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
