---
id: T-1341
name: "L-019 follow-up: raise FW_HANDOVER_PUSH_TIMEOUT default from 15s to 60s (pre-push
  audit consumes ~10s)"
description: >
  L-019 follow-up: raise FW_HANDOVER_PUSH_TIMEOUT default from 15s to 60s (pre-push
  audit consumes ~10s)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-19T17:56:42Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-19T17:58:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 2
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=4 (body:fw-audit-or-doctor); D3=2 
      (body:default-change); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1341: L-019 follow-up: raise FW_HANDOVER_PUSH_TIMEOUT default from 15s to 60s (pre-push audit consumes ~10s)

## Context

L-019 observed both github and onedev push hit the 15s T-1277 timeout during `fw handover --commit`. Post-fix analysis: the pre-push hook runs `fw audit` which takes ~10s on its own, leaving <5s for the actual network push. The T-1277 bound was conservative (targeted malicious stall), but real operations need headroom for legitimate audit + push. Bumping default to 60s gives ~50s for network after the audit, matching the manual `timeout 120 git push` that reliably succeeds this session.

## Acceptance Criteria

### Agent
- [x] `agents/handover/handover.sh` default changed from `15` to `60`
- [x] CLAUDE.md `FW_HANDOVER_PUSH_TIMEOUT` row updated to reflect new default
- [x] `bash -n agents/handover/handover.sh` passes
- [x] Config table invariant preserved: env override still works (shell `${VAR:-default}` syntax unchanged)

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

bash -n agents/handover/handover.sh
grep -q 'FW_HANDOVER_PUSH_TIMEOUT:-60' agents/handover/handover.sh
grep -q '`FW_HANDOVER_PUSH_TIMEOUT` | `15` ' CLAUDE.md && exit 1 || true
grep -q '`FW_HANDOVER_PUSH_TIMEOUT` | `60` ' CLAUDE.md

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

### 2026-04-19T17:56:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1341-l-019-follow-up-raise-fwhandoverpushtime.md
- **Context:** Initial task creation

### 2026-04-19T17:58:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ba05f5e6
- **Timestamp:** 2026-06-02T14:56:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
