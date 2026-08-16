---
id: T-1418
name: "Send T-1332 GO pickup to termlink — fleet-reauth UX prioritisation"
description: >
  Send T-1332 GO pickup to termlink — fleet-reauth UX prioritisation

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T09:29:55Z
last_update: '2026-08-16T22:24:31Z'
date_finished: 2026-04-24T09:34:17Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1418: Send T-1332 GO pickup to termlink — fleet-reauth UX prioritisation

## Context

Follow-up build from T-1332 GO decision (recorded this session, 2026-04-24). Send a cross-project feature-proposal pickup envelope to the termlink project asking them to prioritise / ship T-1054 (fleet reauth tier-1) and T-1055 (fleet reauth --bootstrap-from tier-2), because framework has now observed G-045 (fleet cert/secret co-rotation) trigger 5+ times this week on `.121` alone. Scope-fence inherited from T-1332 inception: IN = draft and deliver the envelope; OUT = implementing the remediation on termlink's side (their call).

## Acceptance Criteria

### Agent
- [x] Pickup envelope P-040-feature-proposal.yaml created and delivered to `/opt/termlink/.context/pickup/inbox/` (TermLink project repo on same host)
- [x] Envelope summary cites G-045 and references T-1054 + T-1055 by name (see payload.summary field)
- [x] Envelope detail includes fleet failure evidence (ring20-dashboard 5 consecutive auth-mismatch failures since 2026-04-23T17:17Z, .fleet-failure-state.json cited)
- [x] TermLink-side `fw pickup status`: inbox 1, processed 21 (was 20 before) — envelope reached their pipeline. Note: termlink-agent session ran with a read-only `.tasks/active/` so inception-task auto-creation failed mid-process; envelope was restored to inbox so termlink can retry when session has write perms.

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

### 2026-04-24T09:29:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1418-send-t-1332-go-pickup-to-termlink--fleet.md
- **Context:** Initial task creation

### 2026-04-24T09:34:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b20f2914
- **Timestamp:** 2026-06-02T14:57:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
