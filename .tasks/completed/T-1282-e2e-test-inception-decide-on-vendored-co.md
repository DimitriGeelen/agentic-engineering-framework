---
id: T-1282
name: "E2E test: inception decide on vendored consumer project via Watchtower"
description: >
  E2E test: inception decide on vendored consumer project via Watchtower

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-17T10:16:32Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-23T19:19:56Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=2
      (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1282: E2E test: inception decide on vendored consumer project via Watchtower

## Context

T-1281 covered the framework-repo case (PROJECT_ROOT == FRAMEWORK_ROOT). T-1282
covers the vendored case: a consumer project where `.agentic-framework/` lives
inside the project tree. The Watchtower → fw inception decide → task body update
chain must work identically when invoked through the vendored shim.

## Acceptance Criteria

### Agent
- [x] New test file `tests/web/test_inception_decide_vendored_e2e.py` exists
- [x] Fixture sets up tmp_path with `.agentic-framework/` symlinked to repo root (vendored mode)
- [x] PROJECT_ROOT is the tmp_path consumer (not the framework repo)
- [x] Test posts to `/inception/T-XXXX/decide` and verifies task body mutation
- [x] Test verifies task moves from active/ → completed/ (auto-complete chain)
- [x] All 5 tests pass: `python3 -m pytest tests/web/test_inception_decide_vendored_e2e.py` → `5 passed in 4.33s`

## Verification

bash -c 'out=$(bin/fw test web tests/web/test_inception_decide_vendored_e2e.py 2>&1); echo "$out" | tail -20; echo "$out" | grep -qE "passed|[0-9]+ passed"'
test -f tests/web/test_inception_decide_vendored_e2e.py

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

### 2026-04-17T10:16:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1282-e2e-test-inception-decide-on-vendored-co.md
- **Context:** Initial task creation

### 2026-04-22T11:14:06Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Change:** horizon: now → later
- **Reason:** placeholder ACs (G-020) — needs real scoping before build; demoted pending proper inception

### 2026-04-23T16:46:49Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-23T19:16:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-23T19:19:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-760f6ffd
- **Timestamp:** 2026-06-02T14:56:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
