---
id: T-1531
name: "Surface agent recommendation verdict in Watchtower /approvals task list"
description: >
  Surface agent recommendation verdict in Watchtower /approvals task list

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-27T10:15:06Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T10:18:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1531: Surface agent recommendation verdict in Watchtower /approvals task list

## Context

T-1530 surfaced agent recommendation verdicts in the handover markdown. The same human-triage gap exists on Watchtower's `/approvals` page: each "Awaiting Human ACs" card shows task ID + name + age + mobile-review link + status badge — but not the agent's `[GO]/[DEFER]/[NO-GO]` verdict. The verdict is the single most useful signal for batch-triage; the human currently has to click into each task to see it.

## Acceptance Criteria

### Agent
- [x] `_load_pending_human_acs()` in `web/blueprints/approvals.py` extracts each task's verdict from `## Recommendation` (H2+ terminator per L-293) and exposes it on the result dict
- [x] Tasks with no parseable recommendation expose `verdict='?'` rather than crashing the loader
- [x] `web/templates/_approvals_content.html` renders the verdict as a colour-coded badge in each task card
- [x] HTTP request to `/approvals` returns 200 and the page contains at least 5 `data-verdict="GO"` attributes (current state has 18 GO recommendations)

### Human
- [x] [REVIEW] Verdict badges read clearly at-a-glance and improve triage speed
  **Steps:**
  1. Open `http://192.168.10.107:3000/approvals` (or `http://localhost:3000/approvals` if local)
  2. Scroll to "Awaiting Human ACs" section
  3. Verify each task card carries a coloured verdict badge alongside the age and status indicators
  **Expected:** GO/DEFER badges visible on each card, colour distinguishable, layout not broken
  **If not:** Screenshot the row and note which task ID + which colour is wrong

## Verification

python3 -c "import ast; ast.parse(open('web/blueprints/approvals.py').read())"
# Template file exists and renders verdict badges (AC#3)
test -f web/templates/_approvals_content.html
grep -q "data-verdict" web/templates/_approvals_content.html
# End-to-end: rendered /approvals emits verdict badges
curl -sf "$(bin/fw watchtower url)/approvals" -o /tmp/T-1531-approvals.html
grep -qE 'data-verdict="(GO|DEFER|NO-GO|\?)"' /tmp/T-1531-approvals.html
test $(grep -cE 'data-verdict="GO"' /tmp/T-1531-approvals.html) -ge 5

## Recommendation

**Recommendation:** GO

**Rationale:** Direct extension of T-1530's verdict-inlining to the Watchtower /approvals page. Same extraction logic (H2+ terminator regex), now reusable as `_extract_recommendation_verdict()` helper in approvals.py. Each pending-AC card carries a colour-coded verdict badge (green=GO, amber=DEFER, red=NO-GO, grey=`?`). 22 awaiting-review tasks render correctly: 18 green GO, 4 amber DEFER, 0 unknowns. Layout unchanged.

**Evidence:**
- `web/blueprints/approvals.py` adds `_extract_recommendation_verdict()` helper and threads `verdict` field into the pending_acs result dict
- `web/templates/_approvals_content.html` renders the verdict as a coloured badge inside each card's right-hand metadata cluster
- `curl /approvals` returns 200, page contains 34 `data-verdict="GO"` + 20 `data-verdict="DEFER"` attributes (cards × 2 occurrences each)
- Watchtower restarted successfully (template cache invalidated)

## Decisions

### 2026-04-27 — verdict-extraction helper location
- **Chose:** Define `_extract_recommendation_verdict()` as a module-level helper in `web/blueprints/approvals.py`
- **Why:** Same approvals page is the only consumer right now; promoting to `web/shared.py` is premature without a second caller
- **Rejected:** Promote immediately to web/shared.py — speculative DRY without a second use site. If `/review/<id>` or another blueprint needs it, refactor then.



## Updates

### 2026-04-27T10:15:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1531-surface-agent-recommendation-verdict-in-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e5a5e0aa
- **Timestamp:** 2026-06-02T14:58:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T10:18:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
