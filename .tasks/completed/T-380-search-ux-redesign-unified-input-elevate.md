---
id: T-380
name: "Search UX redesign: unified input, elevated Q&A, relevance bars"
description: >
  Redesign search page: unified smart input (auto-detect search vs Q&A), AI answer
  above results in distinct article, category pills replacing accordions, 5-segment
  relevance bars, empty state with suggestions. Depends on T-376 (search_utils dedup).
  Parent: T-375.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [ui, search]
components: [C-003, web/templates/search.html]
related_tasks: []
created: 2026-03-09T09:41:43Z
last_update: '2026-06-11T22:24:20Z'
date_finished: 2026-03-09T10:06:25Z
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

# T-380: Search UX redesign: unified input, elevated Q&A, relevance bars

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Unified search input with auto-detect (questions trigger Q&A, keywords trigger search)
- [x] AI answer elevated to distinct article above results (not hidden in details)
- [x] Category pills replace accordion details for filtering
- [x] 5-segment relevance bars with labels replace raw scores
- [x] Empty state with suggestion pills
- [x] path_to_link Jinja2 filter used for server-side path resolution
- [x] Default search mode changed from keyword to hybrid
- [x] Follow-up input for multi-turn conversations
- [x] All search tests pass

### Human
- [x] [REVIEW] Search UX feels intuitive and looks good
  **Steps:**
  1. Open http://localhost:3000/search
  2. Try a keyword search: "healing loop"
  3. Try a question: "How does the audit system work?"
  4. Check relevance bars and category pills
  5. Check mobile layout (resize browser to 400px wide)
  **Expected:** Clean layout, Q&A auto-triggers on questions, pills filter results, bars show relevance
  **If not:** Note which element looks off

## Verification

curl -sf http://localhost:3000/search | grep -q "Search or ask"
curl -sf "http://localhost:3000/search?q=healing&mode=hybrid" | grep -q "search-result"

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

### 2026-03-09T09:41:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-380-search-ux-redesign-unified-input-elevate.md
- **Context:** Initial task creation

### 2026-03-09T09:57:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-09T10:06:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:14Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a10abb31
- **Timestamp:** 2026-06-02T15:02:29Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf http://localhost:3000/search | grep -q "Search or ask"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf "http://localhost:3000/search?q=healing&mode=hybrid" | grep -q "search-result"`
