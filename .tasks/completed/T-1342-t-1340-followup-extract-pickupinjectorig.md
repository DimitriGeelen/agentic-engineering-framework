---
id: T-1342
name: "T-1340 followup: extract pickup_inject_origin_frontmatter as testable unit
  (prevent bats test leakage into real project)"
description: >
  T-1340 followup: extract pickup_inject_origin_frontmatter as testable unit (prevent
  bats test leakage into real project)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-19T18:00:40Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-19T18:09:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1342: T-1340 followup: extract pickup_inject_origin_frontmatter as testable unit (prevent bats test leakage into real project)

## Context

T-1340's bats test (`tests/unit/pickup_origin_frontmatter.bats`) called `pickup_create_inception` which shells out to `fw task create` — this created two tasks (T-1342/T-1343) in the framework project's real `.tasks/active/` despite PROJECT_ROOT being set to a tmpdir. Root cause: subshell inherits env but `fw` binary auto-detection may miss tmpdir context. Fix: extract the frontmatter injection logic into a pure helper (`pickup_inject_origin_frontmatter`) that operates on a file path + args, with no side effects, and update the bats test to target the helper directly. Test leakage eliminated; functional coverage preserved.

## Acceptance Criteria

### Agent
- [x] `pickup_inject_origin_frontmatter` extracted as a standalone function in `lib/pickup.sh` — takes (file, task, project), modifies frontmatter in-place, idempotent
- [x] `pickup_create_inception` calls the new helper (no inline python)
- [x] Bats test rewritten to exercise the helper directly on a fixture file (no `fw task create` invocation) — 4 test cases: inject, idempotent, preserves body, missing-file
- [x] Running the bats test does NOT create any tasks in the real project (leak check empty)
- [x] `bash -n lib/pickup.sh` passes; both bats suites pass (8/8)

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

bash -n lib/pickup.sh
bats tests/unit/pickup_origin_frontmatter.bats
bats tests/unit/pickup_self_deferred.bats

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

### 2026-04-19T18:00:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1342-t-1340-followup-extract-pickupinjectorig.md
- **Context:** Initial task creation

### 2026-04-19T18:09:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8904a702
- **Timestamp:** 2026-06-02T14:56:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
