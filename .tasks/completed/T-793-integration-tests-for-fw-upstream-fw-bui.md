---
id: T-793
name: "Integration tests for fw upstream, fw build, and fw ask subcommands"
description: >
  Integration tests for fw upstream, fw build, and fw ask subcommands

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-30T16:06:06Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T16:09:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-793: Integration tests for fw upstream, fw build, and fw ask subcommands

## Context

lib/ask.sh, lib/build.sh, lib/upstream.sh all have `set -euo pipefail` at top level, preventing bats sourcing for unit tests. Integration tests via `fw` command work fine though.

## Acceptance Criteria

### Agent
- [x] Integration tests for `fw upstream` (19 tests: help, config, status, report guards, list)
- [x] Integration tests for `fw build` (5 tests: help, build execution, dist output)
- [x] Integration tests for `fw ask` (5 tests: help, options, examples, no-args guard)
- [x] Integration tests for `fw pickup` (14 tests: help, status, list, send, process)
- [x] All 43 new tests pass
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bats tests/integration/fw_upstream.bats
bats tests/integration/fw_build.bats
bats tests/integration/fw_ask.bats
bats tests/integration/fw_pickup.bats

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

### 2026-03-30T16:06:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-793-integration-tests-for-fw-upstream-fw-bui.md
- **Context:** Initial task creation

### 2026-03-30T16:09:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2ce1b76a
- **Timestamp:** 2026-06-02T15:04:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
