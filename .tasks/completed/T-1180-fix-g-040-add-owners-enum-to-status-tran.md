---
id: T-1180
name: "Fix G-040: Add owners enum to status-transitions.yaml and remove hardcoded
  owner lists"
description: >
  Fix G-040: Add owners enum to status-transitions.yaml and remove hardcoded owner
  lists

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T17:44:49Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-12T17:50:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 1
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=1 (body:hard-coded-removed); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1180: Fix G-040: Add owners enum to status-transitions.yaml and remove hardcoded owner lists

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `owners:` section added to status-transitions.yaml
- [x] `_load_enums()` in tasks.py reads owners from YAML
- [x] Hardcoded `allowed_owners` lists removed from tasks.py
- [x] Template owner dropdowns use dynamic enum
- [x] Web tests pass
- [x] lib/enums.sh exports VALID_OWNERS + is_valid_owner() + list_valid_owners()

## Verification

# owners section exists in status-transitions.yaml
grep -q "^owners:" status-transitions.yaml
# No hardcoded allowed_owners in tasks.py
bash -c '! grep -q "allowed_owners.*=.*\[" web/blueprints/tasks.py'
# Web route tests pass
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/test_app.py::TestRoutes -x -q 2>&1 | tail -1 | grep -q "passed"
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-12T17:44:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1180-fix-g-040-add-owners-enum-to-status-tran.md
- **Context:** Initial task creation

### 2026-04-12T17:50:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f814db2a
- **Timestamp:** 2026-06-02T14:55:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#6 (Agent)** — lib/enums.sh exports VALID_OWNERS + is_valid_owner() + list_valid_owners()
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/enums.sh in: lib/enums.sh exports VALID_OWNERS + is_valid_owner() + list_valid_owners()`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest web/test_app.py::TestRoutes -x -q 2>&1 | tail -1 | grep -q "passed"`
