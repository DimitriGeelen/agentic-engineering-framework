---
id: T-1514
name: "Extend fw inception sweep to recover started-work + decision stuck-state (T-1491
  fallout class 2)"
description: >
  Extend fw inception sweep to recover started-work + decision stuck-state (T-1491
  fallout class 2)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-26T19:27:42Z
last_update: '2026-08-16T22:24:35Z'
date_finished: 2026-04-26T19:31:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1514: Extend fw inception sweep to recover started-work + decision stuck-state (T-1491 fallout class 2)

## Context

T-1491 root-caused that `do_inception_decide` silently swallowed `update-task.sh` failures, leaving 49 historical inceptions in stuck states. T-1423's `fw inception sweep` recovers one class — `status: work-completed + decision recorded` — but **misses class 2**: `status: started-work + decision recorded`. T-1388 is in class 2 and currently can't close: decision GO recorded 2026-04-22, all ACs ticked, but status frontmatter never moved.

This task extends `do_inception_sweep` in `lib/inception.sh` to detect and recover class 2 by promoting `started-work → work-completed` in place when the Decision block is present, then falling through to the existing tick + move logic.

## Acceptance Criteria

### Agent
- [x] Sweep eligibility extended to include `status: started-work` when a Decision block is present
- [x] Class 2 entries are promoted to `work-completed` in place (frontmatter rewrite + last_update touch) before tick + move
- [x] Dry-run output distinguishes class 1 vs class 2 (shows `status=` per task)
- [x] Sweep summary reports `promoted=N` count separately from `ticked` and `moved`
- [x] T-1388 (live class 2 case) recovers: status moves to `work-completed`, file moves to `.tasks/completed/` after sweep
- [x] Existing class 1 behavior unchanged (T-1372/T-1376 still tick + stay-pending on unchecked Human ACs)

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

# T-1388 (and T-1283, T-1284) recovered to completed/ after sweep
test -f .tasks/completed/T-1388-watchtower-inceptiont-xxx-page-is-one-sh.md
test -f .tasks/completed/T-1283-prompt-register-in-watchtower--reusable-.md
test -f .tasks/completed/T-1284-watchtower-port-discovery-regression--cu.md
# Sweep code carries the new class 2 logic + reports promoted= in summary
grep -q "T-1491 class 2 recovery" lib/inception.sh
grep -q "promoted=\$promoted" lib/inception.sh
# Dry-run output shows status= per task (class 1 vs class 2 distinction).
# SIGPIPE-safe form: capture full output then test (T-1495 pattern).
test -n "$(bin/fw inception sweep --dry-run 2>&1 | grep -E 'status=(work-completed|started-work) decision=' || true)"

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

### 2026-04-26T19:27:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1514-extend-fw-inception-sweep-to-recover-sta.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-90dc6de0
- **Timestamp:** 2026-06-02T14:58:00Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T19:31:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Sweep extended, T-1283/T-1284/T-1388 recovered, class 1 behavior preserved
