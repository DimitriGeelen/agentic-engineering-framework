---
id: T-1433
name: "sync 4 drifted vendored hook scripts (budget-gate, check-agent-dispatch, checkpoint,
  check-project-boundary) — source newer, consumers missing T-1277 timeout fix and
  _fw_cmd resolution"
description: >
  sync 4 drifted vendored hook scripts (budget-gate, check-agent-dispatch, checkpoint,
  check-project-boundary) — source newer, consumers missing T-1277 timeout fix and
  _fw_cmd resolution

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T15:49:49Z
last_update: '2026-08-16T22:24:32Z'
date_finished: 2026-04-24T15:50:45Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1433: sync 4 drifted vendored hook scripts (budget-gate, check-agent-dispatch, checkpoint, check-project-boundary) — source newer, consumers missing T-1277 timeout fix and _fw_cmd resolution

## Context

Continuation of T-1432 scope. A diff sweep across `lib/` and `agents/context/` found 4 more drifted vendored scripts. All drifts are source-newer-than-vendored; consumers pulling via `fw upgrade` get stale copies:

- **`agents/context/checkpoint.sh`** — source has T-1277 timeout fix (`FW_HANDOVER_TOTAL_TIMEOUT`, bounded auto-handover wall time). Vendored (April 11) predates that fix. Consumers vulnerable to the 4h stall that T-1277 was created to kill.
- **`agents/context/budget-gate.sh`** — source uses `$(_fw_cmd)` helper to emit `bin/fw` in framework repo / `.agentic-framework/bin/fw` in consumers. Vendored hardcodes bare `fw` (the pattern rejected by T-1257).
- **`agents/context/check-agent-dispatch.sh`** — same `_fw_cmd` vs bare `fw` drift as budget-gate.
- **`agents/context/check-project-boundary.sh`** — same `_fw_cmd` drift + a lost comment.

Root cause is the same pattern L-257 captured: source edits don't auto-propagate to vendored copies. Fix: `cp` + track + commit.

## Acceptance Criteria

### Agent
- [x] `.agentic-framework/agents/context/budget-gate.sh` matches `agents/context/budget-gate.sh`
- [x] `.agentic-framework/agents/context/check-agent-dispatch.sh` matches source
- [x] `.agentic-framework/agents/context/checkpoint.sh` matches source (T-1277 fix)
- [x] `.agentic-framework/agents/context/check-project-boundary.sh` matches source
- [x] `for f in lib/*.sh agents/context/*.sh; do diff -q "$f" ".agentic-framework/$f" >/dev/null || echo DRIFT; done` produces no output

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

diff -q .agentic-framework/agents/context/budget-gate.sh agents/context/budget-gate.sh
diff -q .agentic-framework/agents/context/check-agent-dispatch.sh agents/context/check-agent-dispatch.sh
diff -q .agentic-framework/agents/context/checkpoint.sh agents/context/checkpoint.sh
diff -q .agentic-framework/agents/context/check-project-boundary.sh agents/context/check-project-boundary.sh
grep -q 'FW_HANDOVER_TOTAL_TIMEOUT' .agentic-framework/agents/context/checkpoint.sh

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

### 2026-04-24T15:49:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1433-sync-4-drifted-vendored-hook-scripts-bud.md
- **Context:** Initial task creation

### 2026-04-24T15:50:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c0700f48
- **Timestamp:** 2026-06-02T14:57:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
