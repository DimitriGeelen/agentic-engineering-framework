---
id: T-680
name: "Fix fw vendor self-referencing — detect source==target and pull from upstream"
description: >
  F-3: When .agentic-framework/ already exists, fw vendor copies from itself to itself
  (source==target), making it a no-op. Should detect this and pull from the framework
  source that invoked the command. Discovered during T-679 Path C experiment.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw]
related_tasks: []
created: 2026-03-28T21:37:27Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-28T22:35:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-680: Fix fw vendor self-referencing — detect source==target and pull from upstream

## Context

When `fw vendor` or `fw init` runs and `FRAMEWORK_ROOT` resolves to `$PROJECT_ROOT/.agentic-framework` (the vendored copy itself), source == target. This is a no-op at best, corruption at worst. Discovered during T-679 Path C experiment (F-3). The fix: detect self-referencing in `do_vendor()` and either abort with a clear message or fall back to an upstream source.

## Acceptance Criteria

### Agent
- [x] `do_vendor()` detects when resolved source == destination (canonicalized paths)
- [x] When self-reference detected, prints clear error with guidance to specify source
- [x] `fw vendor --source /path/to/framework` flag added to allow explicit override
- [x] `fw init --force` on a project with vendored framework uses the invoking fw's real source, not the vendored copy
- [x] Existing vendor flow (source != target) is unaffected

## Verification

# Self-reference detection: vendor into own dir should fail gracefully
grep -q "source.*target.*same" bin/fw || grep -q "self-referenc" bin/fw
# --source flag exists in help
bin/fw vendor --help 2>&1 | grep -q "\-\-source"

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

### 2026-03-28T21:37:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-680-fix-fw-vendor-self-referencing--detect-s.md
- **Context:** Initial task creation

### 2026-03-28T22:32:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T22:35:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-99f3159f
- **Timestamp:** 2026-06-02T15:04:18Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `grep -q "source.*target.*same" bin/fw || grep -q "self-referenc" bin/fw`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `bin/fw vendor --help 2>&1 | grep -q "\-\-source"`
