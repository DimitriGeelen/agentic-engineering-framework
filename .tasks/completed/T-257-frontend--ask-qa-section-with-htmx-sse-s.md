---
id: T-257
name: "Frontend — Ask Q&A section with htmx SSE streaming"
description: >
  Add Ask Q&A section to web/templates/search.html: textarea input, Ask button, answer
  div with streaming token display, collapsible Sources panel with inline [1][2] citations.
  Uses htmx 2.0+ SSE extension (hx-ext=sse, sse-connect). Reuses T-253 URL mapping
  for source links. ~80 lines template + check/upgrade htmx version. See docs/reports/T-254-llm-assisted-qa-research.md
  RQ-3. Predecessor: T-256.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:34Z
last_update: '2026-06-11T22:24:17Z'
date_finished: 2026-02-23T21:01:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 1
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-257: Frontend — Ask Q&A section with htmx SSE streaming

## Context

Frontend for LLM Q&A. See `docs/reports/T-254-llm-assisted-qa-research.md` RQ-3.

## Acceptance Criteria

### Agent
- [x] Ask section exists on search page with input and button
- [x] Connects to `/search/ask` SSE endpoint
- [x] Tokens stream into answer div in real-time
- [x] Sources panel shows after answer completes with numbered citations
- [x] Source links are clickable (reuses T-253 URL mapping)
- [x] Model name displayed during generation
- [x] Error messages displayed if LLM fails

### Human
- [x] Streaming UX feels responsive and natural
- [x] Answer formatting (markdown) is readable
- [x] Source panel layout is clean and useful

## Verification

# Search page loads with Ask section
curl -sf http://localhost:3000/search | grep -q "Ask"
# Ask section has SSE attributes
curl -sf http://localhost:3000/search | grep -q "sse"

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

### 2026-02-23T20:38:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-257-frontend--ask-qa-section-with-htmx-sse-s.md
- **Context:** Initial task creation

### 2026-02-23T21:01:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-23T21:01:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-937da2b8
- **Timestamp:** 2026-06-02T15:01:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/search | grep -q "Ask"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `curl -sf http://localhost:3000/search | grep -q "sse"`
