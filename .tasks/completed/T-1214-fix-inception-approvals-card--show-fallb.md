---
id: T-1214
name: "Fix inception approvals card — show fallback context when recommendation missing
  (T-1213 GO)"
description: >
  Fix inception approvals card — show fallback context when recommendation missing
  (T-1213 GO)

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [web/blueprints/approvals.py, web/templates/_approvals_content.html]
related_tasks: []
created: 2026-04-13T09:18:31Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-13T09:20:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
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

# T-1214: Fix inception approvals card — show fallback context when recommendation missing (T-1213 GO)

## Context

T-1213 GO. RC-1: template hides recommendation block entirely when data is missing. Fix: add fallback
context block showing Go/No-Go Criteria and warning when recommendation is absent. Also pass Go/No-Go
Criteria from backend and make problem statement more prominent.

## Acceptance Criteria

### Agent
- [x] Template shows fallback context when `t.recommendation` is empty
- [x] Backend passes `go_nogo_criteria` field to template for fallback display
- [x] Warning banner shown when recommendation is missing
- [x] Approvals page loads without errors (HTTP 200)

### Human
- [x] [REVIEW] Inception cards on /approvals show useful context for decision-making
  **Steps:**
  1. Open http://192.168.10.107:3001/approvals in browser
  2. Look at inception decision cards
  3. Verify recommendation OR fallback context is visible
  **Expected:** Every card shows either agent recommendation or Go/No-Go Criteria with warning
  **If not:** Note which card is bare and what's missing

## Verification

curl -sf -o /dev/null -w "%{http_code}" http://localhost:3001/approvals | grep -q 200

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Recommendation

**Recommendation:** GO

**Rationale:** All 4 Agent ACs verified; the fallback render path is in place and the page returns 200. The remaining `[REVIEW]` Human AC asks for a visual judgment (do cards show useful context). No code changes outstanding.

**Evidence:**
- Template fallback when `t.recommendation` empty (web/templates/_approvals_content.html)
- Backend passes `go_nogo_criteria` (web/blueprints/approvals.py)
- Warning banner present when recommendation missing
- HTTP 200 confirmed at completion

## Updates

### 2026-04-13T09:18:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1214-fix-inception-approvals-card--show-fallb.md
- **Context:** Initial task creation

### 2026-04-13T09:20:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-48ced561
- **Timestamp:** 2026-06-02T14:55:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `curl -sf -o /dev/null -w "%{http_code}" http://localhost:3001/approvals | grep -q 200`

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
