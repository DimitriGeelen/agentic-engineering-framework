---
id: T-385
name: "Search page refinement: gear icon, saved searches, Q&A history"
description: >
  Search page refinement: gear icon, saved searches, Q&A history

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [ui, search]
components: []
related_tasks: []
created: 2026-03-09T11:09:23Z
last_update: '2026-06-11T22:24:20Z'
date_finished: 2026-03-09T11:18:17Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
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
---

# T-385: Search page refinement: gear icon, saved searches, Q&A history

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Gear icon moved from main nav to search page controls row
- [x] Saved Answers section shows .context/qa/ entries in empty state
- [x] Recent Searches with localStorage persistence and clear button
- [x] Two-column empty state grid with suggestions + saved answers
- [x] Search input full width (mode selector on secondary row)

### Human
- [x] [REVIEW] Search page layout looks good
  **Steps:**
  1. Open http://localhost:3000/search
  2. Check search bar, gear icon, suggestion pills, saved answers
  3. Perform a search, verify recent searches appear on return
  **Expected:** Clean layout, gear icon next to mode selector, saved answers visible
  **If not:** Note which element looks off

## Verification

curl -sf http://localhost:3000/search | grep -q 'search-settings-btn'
curl -sf http://localhost:3000/search | grep -q 'Saved Answers'
curl -sf http://localhost:3000/search | grep -q 'recent-searches'

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

### 2026-03-09T11:09:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-385-search-page-refinement-gear-icon-saved-s.md
- **Context:** Initial task creation

### 2026-03-09T11:18:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-68bba517
- **Timestamp:** 2026-06-02T15:02:31Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/search | grep -q 'search-settings-btn'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/search | grep -q 'Saved Answers'`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `curl -sf http://localhost:3000/search | grep -q 'recent-searches'`
