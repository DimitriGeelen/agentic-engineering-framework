---
id: T-391
name: "Search page layout redesign with simplified mode UX"
description: >
  Redesign the search page layout for cohesion. Replace technical mode dropdown (Hybrid/Keyword/Semantic)
  with clear Search vs Ask toggle. Clean up visual hierarchy: prominent search bar,
  clear mode selection, organized secondary elements (recent searches, saved answers).
  Use frontend-design skill for the redesign. Predecessor: T-388.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-09T11:36:04Z
last_update: '2026-08-16T22:25:29Z'
date_finished: 2026-03-09T12:45:41Z
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
  - ts: '2026-08-16T22:25:29Z'
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

# T-391: Search page layout redesign with simplified mode UX

## Context

Redesign search page from T-388 inception. Replace confusing mode dropdown with segmented pills, fix cramped search bar (caused by Pico CSS fieldset equal-width children), clean up visual hierarchy.

## Acceptance Criteria

### Agent
- [x] Search bar full-width (Pico fieldset group with flex override)
- [x] Mode dropdown replaced with segmented pill buttons (All/Keyword/Semantic)
- [x] Hidden select synced with pill clicks for form submission
- [x] Pill active state persists on page reload (server-rendered from mode param)
- [x] Gear icon circular with hover state
- [x] Hint text on same row as pills
- [x] Search with mode=keyword works correctly (URL reflects selected mode)

### Human
- [x] [REVIEW] Search page layout looks clean and natural
  **Steps:**
  1. Open http://localhost:3000/search
  2. Check search bar is full width with readable placeholder
  3. Click each mode pill (All, Keyword, Semantic) — active state should toggle
  4. Search for "healing loop" — results should load, pill state should persist
  5. Ask a question like "how does the audit system work?" — AI answer should stream
  **Expected:** Clean layout, pills work, search and Q&A both functional
  **If not:** Note which element looks off or doesn't work

## Verification

curl -sf http://localhost:3000/search | grep -q mode-pill
curl -sf http://localhost:3000/search | grep -q search-mode-select

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

### 2026-03-09T11:36:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-391-search-page-layout-redesign-with-simplif.md
- **Context:** Initial task creation

### 2026-03-09T12:45:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e421b7ae
- **Timestamp:** 2026-06-02T15:02:33Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/search | grep -q mode-pill`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/search | grep -q search-mode-select`
