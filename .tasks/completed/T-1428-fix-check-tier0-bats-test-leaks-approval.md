---
id: T-1428
name: "fix check-tier0 bats test leaks approval files into real .context/approvals/"
description: >
  fix check-tier0 bats test leaks approval files into real .context/approvals/

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T15:04:25Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-24T15:05:21Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1428: fix check-tier0 bats test leaks approval files into real .context/approvals/

## Context

T-1427 added `tests/unit/check_tier0_comment_stripping.bats` which invokes the real `check-tier0.sh`. The hook resolves `PROJECT_ROOT` via `lib/paths.sh` (git toplevel when unset) and writes pending approval files to `$PROJECT_ROOT/.context/approvals/`. The test didn't override `PROJECT_ROOT`, so every "blocked" test case (T-123, T-999, T-1) leaked a real `pending-*.yaml` into the project's live approvals queue — these showed up in Watchtower as phantom pending Tier 0 approvals. Same test-isolation class as T-1017 / L-227.

## Acceptance Criteria

### Agent
- [x] Test exports `PROJECT_ROOT="$TEST_TEMP_DIR"` in `setup()` so the hook writes to the sandbox
- [x] `tests/unit/check_tier0_comment_stripping.bats` still passes (all 8 tests)
- [x] Running the bats file does NOT create new `pending-*.yaml` in real `.context/approvals/`
- [x] 3 leaked approval files from the previous run are deleted

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

bats tests/unit/check_tier0_comment_stripping.bats
grep -q 'export PROJECT_ROOT' tests/unit/check_tier0_comment_stripping.bats
# After a fresh test run, no leaked fixed-hash approvals should remain:
test ! -f .context/approvals/pending-3e7791af1d88.yaml
test ! -f .context/approvals/pending-9509dbac4bba.yaml
test ! -f .context/approvals/pending-b76239da5dd4.yaml

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

### 2026-04-24T15:04:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1428-fix-check-tier0-bats-test-leaks-approval.md
- **Context:** Initial task creation

### 2026-04-24T15:05:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4c6e826a
- **Timestamp:** 2026-06-02T14:57:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
