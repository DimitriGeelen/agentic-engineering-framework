---
id: T-966
name: "TermLink session observation in Watchtower terminal (T-962 Phase 3)"
description: >
  Phase 3: Integrate TermLink session discovery and observation into Watchtower terminal
  UI. List existing TermLink sessions as attachable tabs, poll TermLink PTY output
  for monitoring, inject input for interactive control. Hybrid architecture: Flask-owned
  PTYs for interactive, TermLink polling for observation. Depends on T-965.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [web/app.py, web/blueprints/terminal.py, web/templates/terminal.html,
  web/terminal.py]
related_tasks: []
created: 2026-04-06T18:25:32Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-06T19:15:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-966: TermLink session observation in Watchtower terminal (T-962 Phase 3)

## Context

Phase 3 of T-962. Add TermLink session discovery and observation to the terminal page. See `docs/reports/T-962-v4-termlink-integration.md` for architecture. Hybrid approach: Flask-owned PTYs for interactive, TermLink polling for observation of existing CLI-spawned sessions.

## Acceptance Criteria

### Agent
- [x] TermLink session list endpoint (`/api/termlink/sessions`) returns active sessions as JSON
- [x] Terminal page shows "Attach" button listing discovered TermLink sessions
- [x] Attaching to a TermLink session opens observation tab with polled output
- [x] TermLink sessions visually distinguished (blue top border on tab)

### Human
- [x] [REVIEW] TermLink session observation works
  **Steps:**
  1. Spawn a TermLink session: `termlink spawn --name test-observe --backend tmux --shell`
  2. Open http://localhost:3000/terminal
  3. Click "Attach" and select the "test-observe" session
  4. In another terminal, inject text: `termlink pty inject test-observe "echo hello" --enter`
  5. Verify the output appears in the Watchtower terminal tab
  **Expected:** TermLink session output streams to browser with ~200ms delay
  **If not:** Note what's missing or broken

## Verification

python3 -c "from web.app import app; c=app.test_client(); r=c.get('/terminal'); exit(0 if r.status_code==200 else 1)"
grep -q 'termlink\|attach' web/templates/terminal.html

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

### 2026-04-06T18:25:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-966-termlink-session-observation-in-watchtow.md
- **Context:** Initial task creation

### 2026-04-06T18:49:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T19:15:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-19df7da9
- **Timestamp:** 2026-06-02T15:05:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
