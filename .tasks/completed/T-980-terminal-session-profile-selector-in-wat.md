---
id: T-980
name: "Terminal session profile selector in Watchtower UI"
description: >
  Add session type selector to /terminal page using the profile data from /api/sessions/profiles.
  Users can choose between Bash, Zsh, Claude Code, or Dispatch when creating new sessions.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [tests/playwright/test_terminal.py, web/templates/terminal.html]
related_tasks: []
created: 2026-04-06T22:40:09Z
last_update: '2026-08-16T22:25:44Z'
date_finished: 2026-04-06T22:43:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-980: Terminal session profile selector in Watchtower UI

## Context

T-967 added session profiles and `/api/sessions/profiles` API. The terminal page needs a UI to select profiles when creating new sessions. Currently the "New" button creates a plain shell -- it should offer a dropdown/dialog to pick from available profiles.

## Acceptance Criteria

### Agent
- [x] Terminal template updated: "New" button shows profile selector dropdown
- [x] Profile selector fetches from `/api/sessions/profiles` on page load
- [x] Each profile shows name, icon/color, and description
- [x] Selecting a profile creates a session via `createSession(profileId)`
- [x] Terminal page loads without JS errors after changes (8/8 Playwright tests pass)
- [x] Playwright test: profile selector is visible on terminal page (`test_terminal_has_profile_menu`)

### Human
- [x] [REVIEW] Profile selector UI is clean and intuitive
  **Steps:**
  1. Open http://localhost:3000/terminal in browser
  2. Click "New" or the profile dropdown
  3. Verify profiles are listed with labels and colors
  4. Select "Bash" and verify terminal spawns
  **Expected:** Clean dropdown with 4 profiles, session spawns on selection
  **If not:** Screenshot the issue

## Verification

curl -sf http://localhost:3000/terminal | grep -q 'profile'
python3 -m pytest tests/playwright/test_terminal.py -v

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

### 2026-04-06T22:40:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-980-terminal-session-profile-selector-in-wat.md
- **Context:** Initial task creation

### 2026-04-06T22:43:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:27:25Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6c1918cf
- **Timestamp:** 2026-06-02T15:06:01Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/terminal | grep -q 'profile'`
