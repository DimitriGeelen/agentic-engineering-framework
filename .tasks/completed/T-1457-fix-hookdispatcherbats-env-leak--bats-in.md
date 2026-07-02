---
id: T-1457
name: "Fix hook_dispatcher.bats env leak — bats inherits PROJECT_ROOT, polluting framework
  crash log"
description: >
  Fix hook_dispatcher.bats env leak — bats inherits PROJECT_ROOT, polluting framework
  crash log

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-25T12:27:22Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T12:28:56Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
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
---

# T-1457: Fix hook_dispatcher.bats env leak — bats inherits PROJECT_ROOT, polluting framework crash log

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `tests/unit/hook_dispatcher.bats` setup() exports `PROJECT_ROOT="$TEST_PROJECT"` so the dispatcher writes to the test's `.context/working/.hook-crashes.log`, not the framework's
- [x] After running the test suite, the framework's `.context/working/.hook-crashes.log` does NOT gain new test-marker entries (verified: re-ran bats after prune; entries=0)
- [x] Existing test-marker entries pruned (23 → 1 — only the legitimate 2026-04-24 `--help` typo remains)
- [x] All 5 test cases in hook_dispatcher.bats still pass (5/5 ok)
- [x] `fw doctor` downgraded "Hook crashes: 3 today (23 total) — WARN" to "Hook crash log: 1 historical entries (none today) — INFO"

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

### 2026-04-25T12:27:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1457-fix-hookdispatcherbats-env-leak--bats-in.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4c729118
- **Timestamp:** 2026-06-02T14:57:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `tests/unit/hook_dispatcher.bats` setup() exports `PROJECT_ROOT="$TEST_PROJECT"` so the dispatcher writes to the test's `.context/working/.hook-crashes.log`, not the framework's
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/hook_dispatcher.bats in: `tests/unit/hook_dispatcher.bats` setup() exports `PROJECT_ROOT="$TEST_PROJECT"` so the dispatcher writes to the test's `.context/working/.hook-crashe`
### 2026-04-25T12:28:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
