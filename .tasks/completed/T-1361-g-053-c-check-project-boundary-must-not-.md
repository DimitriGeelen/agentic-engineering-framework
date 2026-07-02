---
id: T-1361
name: "G-053-C: check-project-boundary must not scan quoted string content"
description: >
  G-053-C: check-project-boundary must not scan quoted string content

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-20T14:28:52Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T14:38:06Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
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
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1361: G-053-C: check-project-boundary must not scan quoted string content

## Context

Resolves G-053 item C.

`agents/context/check-project-boundary.sh` at lines 147/160/168 applies regex patterns to the raw command string, including content INSIDE quoted arguments. False-positives on benign commands:

- `git commit -m "mentions /root/.agentic-framework/bin/fw"` → matched by fw_pattern
- `echo "cd /opt/foo" > note.txt` → matched by cd_pattern

Saw twice in session 2026-04-20 — commit-msg bodies with path examples got blocked.

Fix: strip content between balanced `"..."` and `'...'` before pattern scanning.

## Acceptance Criteria

### Agent
- [x] `check-project-boundary.sh` strips `"..."` and `'...'` content before pattern scanning
- [x] Commit with path in `-m` message is allowed (not blocked)
- [x] Actual unquoted `cd /opt/other` is STILL blocked (unchanged)
- [x] Bats test covers: (a) FP fix, (b) TP still blocks

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

bats tests/unit/check_project_boundary.bats
bash -n agents/context/check-project-boundary.sh

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

### 2026-04-20T14:28:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1361-g-053-c-check-project-boundary-must-not-.md
- **Context:** Initial task creation

### 2026-04-20T14:38:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d792e90b
- **Timestamp:** 2026-06-02T14:56:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
