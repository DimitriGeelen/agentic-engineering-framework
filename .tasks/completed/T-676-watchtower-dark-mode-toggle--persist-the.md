---
id: T-676
name: "Watchtower dark mode toggle — persist theme preference"
description: >
  Watchtower dark mode toggle — persist theme preference

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T20:18:56Z
last_update: '2026-08-16T22:25:37Z'
date_finished: 2026-03-28T20:21:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-676: Watchtower dark mode toggle — persist theme preference

## Context

Pico CSS supports dark mode natively via `data-theme="dark"` on `<html>`. Add a toggle button to the nav bar, persist choice in localStorage.

## Acceptance Criteria

### Agent
- [x] Theme toggle button in base.html nav bar
- [x] Theme persisted in localStorage across page loads
- [x] Standalone templates (review.html) also respect theme preference
- [x] No flash of wrong theme on page load (script in `<head>`)

### Human
- [x] [RUBBER-STAMP] Toggle dark mode and verify it persists across pages
  **Steps:**
  1. Open `http://localhost:3000/` in browser
  2. Click the theme toggle in the nav bar
  3. Navigate to /approvals, /tasks, /review/T-671
  **Expected:** Dark mode persists across all pages, no flash of light mode
  **If not:** Check browser console for localStorage errors

## Verification

# Theme toggle exists in base template
grep -q 'theme-toggle' web/templates/base.html
# Theme script in head for flash prevention
grep -q 'localStorage.*theme' web/templates/base.html
# Standalone review template also has theme support
grep -q 'localStorage.*theme' web/templates/review.html

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

### 2026-03-28T20:18:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-676-watchtower-dark-mode-toggle--persist-the.md
- **Context:** Initial task creation

### 2026-03-28T20:21:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7a8bf858
- **Timestamp:** 2026-06-02T15:04:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
