---
id: T-810
name: "Unit tests for web/blueprints/costs.py token dashboard"
description: >
  Unit tests for web/blueprints/costs.py token dashboard

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
components: [web/test_costs.py]
related_tasks: []
created: 2026-04-03T20:22:04Z
last_update: '2026-08-16T22:25:40Z'
date_finished: 2026-04-03T20:24:31Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-810: Unit tests for web/blueprints/costs.py token dashboard

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Test file `web/test_costs.py` exists following project pytest conventions
- [x] Tests cover `_parse_session()` and `_load_all_sessions()` with JSONL fixtures
- [x] Tests cover `/costs` route response and template rendering
- [x] Tests cover edge cases: empty JSONL dir, malformed data
- [x] All tests pass: `pytest web/test_costs.py -v`

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

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
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

## Updates

### 2026-04-03T20:22:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-810-unit-tests-for-webblueprintscostspy-toke.md
- **Context:** Initial task creation

### 2026-04-03T20:24:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-65669b2e
- **Timestamp:** 2026-06-02T15:04:59Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — Test file `web/test_costs.py` exists following project pytest conventions
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/test_costs.py in: Test file `web/test_costs.py` exists following project pytest conventions`
- **AC#5 (Agent)** — All tests pass: `pytest web/test_costs.py -v`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/test_costs.py in: All tests pass: `pytest web/test_costs.py -v``
