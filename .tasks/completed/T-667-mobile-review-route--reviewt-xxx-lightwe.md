---
id: T-667
name: "Mobile review route — /review/T-XXX lightweight approval card for QR scan"
description: >
  Mobile review route — /review/T-XXX lightweight approval card for QR scan

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T17:39:16Z
last_update: '2026-08-16T22:25:36Z'
date_finished: 2026-03-28T17:45:17Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-667: Mobile review route — /review/T-XXX lightweight approval card for QR scan

## Context

Phase 2 of T-636 unified approval experience. Creates a lightweight `/review/T-XXX` route optimized for mobile QR scan — standalone template (no base.html), Human ACs only, large touch targets, htmx polling for live updates. Design: docs/reports/fw-agent-t636-05-mobile-qr.md

## Acceptance Criteria

### Agent
- [x] `web/blueprints/review.py` blueprint registered and serving `/review/T-XXX`
- [x] `web/templates/review.html` standalone template (no base.html inheritance)
- [x] Only Human ACs shown (Agent ACs hidden)
- [x] AC checkboxes toggle via existing `/api/task/T-XXX/toggle-ac` endpoint
- [x] Pending Tier 0 approvals shown above ACs with approve/reject buttons
- [x] "Complete Task" button appears when all Human ACs checked
- [x] `lib/review.sh` QR URL updated from `/tasks/T-XXX#human-ac` to `/review/T-XXX`
- [x] Auto-refresh via htmx polling (`hx-trigger="every 5s"`) for AC state changes

### Human
- [x] [REVIEW] Mobile layout is usable on phone-sized screen
  **Steps:**
  1. Start Watchtower: `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve`
  2. Open `/review/T-667` in a mobile browser (or use Chrome DevTools mobile emulation, 375px)
  3. Check: task header visible, Human ACs have large tap targets, no horizontal scrolling
  **Expected:** Clean single-column layout, checkboxes are easy to tap, no desktop chrome
  **If not:** Note which elements overflow or are too small to tap

## Verification

python3 -c "from web.blueprints.review import bp; print('review blueprint importable')"
curl -sf http://localhost:3000/review/T-667 | grep -q 'review-page'
grep -q '/review/' lib/review.sh

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

### 2026-03-28T17:39:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-667-mobile-review-route--reviewt-xxx-lightwe.md
- **Context:** Initial task creation

### 2026-03-28T17:45:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f5695b45
- **Timestamp:** 2026-06-02T15:04:14Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Agent)** — `web/templates/review.html` standalone template (no base.html inheritance)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/review.html in: `web/templates/review.html` standalone template (no base.html inheritance)`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `curl -sf http://localhost:3000/review/T-667 | grep -q 'review-page'`
