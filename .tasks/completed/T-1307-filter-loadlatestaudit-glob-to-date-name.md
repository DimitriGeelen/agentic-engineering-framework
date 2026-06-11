---
id: T-1307
name: "Filter load_latest_audit glob to date-named YAML only"
description: >
  Change web/shared.py::load_latest_audit glob from '*.yaml' to '[0-9][0-9][0-9][0-9]-*.yaml'
  so stray non-date YAML in .context/audits/ (e.g. future upgrades.yaml) can't be
  mis-selected by reverse-alphabetical sort. Sibling to T-1305 inception (pickup from
  termlink T-1128).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-18T19:49:34Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-18T19:51:27Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1307: Filter load_latest_audit glob to date-named YAML only

## Context

Sibling to inception T-1305 (pickup P-032 from termlink T-1128). Defensive glob filter.

## Acceptance Criteria

### Agent
- [x] `web/shared.py::load_latest_audit` globs `[0-9][0-9][0-9][0-9]-*.yaml` instead of `*.yaml`
- [x] Reverse-sort behaviour preserved (newest date wins)
- [x] Regression test proves a non-date YAML in a tmp audit dir is ignored
- [x] `fw test web` still passes

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

grep -q "\[0-9\]\[0-9\]\[0-9\]\[0-9\]-\*\.yaml" web/shared.py
python3 -m pytest tests/web/test_load_latest_audit.py -q
python3 -m pytest tests/web/ -q

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

### 2026-04-18T19:49:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1307-filter-loadlatestaudit-glob-to-date-name.md
- **Context:** Initial task creation

### 2026-04-18T19:49:55Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T19:51:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-23e0c008
- **Timestamp:** 2026-06-02T14:56:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
