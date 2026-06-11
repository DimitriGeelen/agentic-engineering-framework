---
id: T-1662
name: "Phase 2: Watchtower /arcs/<id> generic arc surface page (generalize T-1647
  /orchestrator)"
description: >
  Generalize the orchestrator-specific /orchestrator page (T-1647) into a generic
  /arcs/<id> surface that works for any arc registered in .context/arcs/. Each arc
  gets: header (id, name, status, decision), constituent task table with status badges,
  three-question section Arc Completion Discipline checklist, link to anchor task,
  fw arc close CLI snippet. /orchestrator becomes a 302 redirect to /arcs/orchestrator-rethink
  for back-compat. Closes the user's original 'absolutely unclear what kind of use
  this page should be' feedback by making the surface generic and reusable. Picks
  up after orchestrator-rethink arc closure unblocks (T-1643 cross-repo dependency).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [watchtower, arcs, phase-2, from-T-1653]
components: [tests/unit/test_arcs_routes.py, web/blueprints/arcs.py, 
      web/blueprints/__init__.py, web/shared.py, web/templates/arc_detail.html, 
      web/templates/arcs_index.html, web/templates/orchestrator.html]
related_tasks: [T-1647, T-1661, T-1653]
created: 2026-05-01T19:34:55Z
last_update: '2026-06-11T22:23:55Z'
date_finished: 2026-05-03T07:43:15Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 4
      D4: 3
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=4
      (body:framework-level-ux); D4=3 (body:portability-abstraction); F-RECALL=1
      (body:episodic-only); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1662: Phase 2: Watchtower /arcs/<id> generic arc surface page (generalize T-1647 /orchestrator)

## Context

Phase 2 of the T-1653 inception arc. T-1661 shipped Phase 1 (Arc system MVP — `.context/arcs/<id>.yaml` registry + `fw arc` CLI + handover injection + landing-page section + `/tasks?arc=<id>` filter). Phase 2 ships the operator-facing surface: a generic per-arc detail page replacing the orchestrator-specific `/orchestrator` page that prompted the original "absolutely unclear what kind of use this page should be" feedback.

`/orchestrator` keeps its specialized MCP audit + live-sessions panels (still useful as orchestrator-specific drill-down) and gains a cross-link to `/arcs/orchestrator-rethink`. The new `/arcs` index lists every arc; `/arcs/<id>` shows constituent tasks with §Arc Completion Discipline three-question checklist.

## Acceptance Criteria

### Agent
- [x] **Index route:** `GET /arcs` returns 200 with a list of every arc registered in `.context/arcs/*.yaml`. Each row shows id, name, status, decision (if any), constituent task count, focus indicator. Empty state when registry empty.
- [x] **Detail route:** `GET /arcs/<arc_id>` returns 200 for any registered arc. Shows arc metadata (name, status, decision, anchor, created/closed timestamps), constituent task table with status badges, three-question §Arc Completion Discipline checklist, link to anchor task, copy-pasteable `fw arc close <id> --decision "..."` snippet (only for in-progress arcs). 404 with friendly message for unregistered arcs.
- [x] **Cross-link:** `/orchestrator` page gains a top-of-page link to `/arcs/orchestrator-rethink` so the operator can flip between the specialized and generic views.
- [x] **Index nav:** `/arcs` is reachable from the Watchtower top nav (under Architecture or similar group).
- [x] **Tests:** `tests/unit/test_arcs_routes.py` pins index + detail + 404 + empty state via Flask test_client. ≥4 tests (6 shipped).

### Human
- [x] [REVIEW] /arcs index and /arcs/orchestrator-rethink detail are useful at a glance
  **Steps:**
  1. Open `http://192.168.10.107:3000/arcs` — verify orchestrator-rethink listed with its constituent count
  2. Click through to `http://192.168.10.107:3000/arcs/orchestrator-rethink` — verify task table renders with status badges, three-question check is visible, anchor link works
  3. Open `http://192.168.10.107:3000/orchestrator` — verify the cross-link to `/arcs/orchestrator-rethink` is present
  **Expected:** Both pages render; the operator can answer "what is this arc, what's done, what's left, what's the closure check?" from `/arcs/<id>` alone.
  **If not:** Note which panel is unclear.

## Verification

# Routes return 200 / 404 as expected
curl -sf -o /dev/null -w '%{http_code}' http://localhost:3000/arcs | grep -q 200
curl -sf -o /dev/null -w '%{http_code}' http://localhost:3000/arcs/orchestrator-rethink | grep -q 200
curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/arcs/nonexistent-arc-id | grep -q 404
# Cross-link present on /orchestrator
curl -s http://localhost:3000/orchestrator | grep -q "/arcs/orchestrator-rethink"
# Tests pass
python3 -m pytest tests/unit/test_arcs_routes.py -q 2>&1 | tail -3

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Recommendation

**Recommendation:** GO

**Rationale:** The original "absolutely unclear what kind of use this page should be" feedback that triggered the entire arc system is now closed. `/arcs` lists every registered arc with focus indicator and status; `/arcs/<id>` shows constituent tasks, completion stats with the audit-detective threshold call-out (e.g. orchestrator-rethink renders "82% audit warns ≥80%"), and the §Arc Completion Discipline three-question check inline. `/orchestrator` becomes the orchestrator-arc-specific drill-down (MCP audit, live sessions, recent dispatches) cross-linked from `/arcs/orchestrator-rethink`, so the generic and specialized views feed each other instead of competing.

**Evidence:**
- 6/6 unit tests pass (`tests/unit/test_arcs_routes.py`): index empty/populated, detail in-progress/closed/missing-task/404.
- HTTP probes: `/arcs` 200, `/arcs/orchestrator-rethink` 200, `/arcs/no-such-arc` 404, `/orchestrator` 200 (cross-link visible).
- Playwright screenshot of `/arcs/orchestrator-rethink` confirms: FOCUSED pill, 14/17 stat strip, "audit warns ≥80%" badge matching the live audit detective, full task table with status badges, §Arc Completion Discipline check, `fw arc close` snippet.
- Nav: "Arcs" entry added under Architecture group.

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

### 2026-05-01T19:34:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1662-phase-2-watchtower-arcsid-generic-arc-su.md
- **Context:** Initial task creation

### 2026-05-01T19:53:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-104728b4
- **Timestamp:** 2026-06-02T14:58:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf -o /dev/null -w '%{http_code}' http://localhost:3000/arcs | grep -q 200`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -sf -o /dev/null -w '%{http_code}' http://localhost:3000/arcs/orchestrator-rethink | grep -q 200`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/arcs/nonexistent-arc-id | grep -q 404`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `curl -s http://localhost:3000/orchestrator | grep -q "/arcs/orchestrator-rethink"`
### 2026-05-03T07:43:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
