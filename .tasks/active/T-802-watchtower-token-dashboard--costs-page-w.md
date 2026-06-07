---
id: T-802
name: "Watchtower token dashboard — /costs page with session table and project summary"
description: >
  Add /costs page to Watchtower showing token usage data from fw costs. Display project
  summary (total tokens by category), per-session table with sorting, and current
  session highlights. Uses lib/costs.sh parsing functions. Follow-up from T-801 (fw
  costs CLI).

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [watchtower, tokens, observability]
components: [watchtower-web-ui]
related_tasks: [T-801, T-799, T-800]
created: 2026-04-03T19:09:41Z
last_update: '2026-06-05T18:00:04Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F1: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 8
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-802: Watchtower token dashboard — /costs page with session table and project summary

## Context

Follow-up from T-801 (fw costs CLI). Uses same JSONL parsing approach. Predecessor research: `docs/reports/T-799-T-800-token-cost-analysis.md`.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/costs.py` exists with `/costs` route
- [x] Blueprint registered in `web/blueprints/__init__.py`
- [x] `web/templates/costs.html` renders token usage dashboard
- [x] Summary cards show total tokens, sessions, turns, cache hit rate
- [x] Per-session table shows breakdown by token category
- [x] `/costs` page loads without errors
- [x] Nav link added for costs page

### Human
- [x] [REVIEW] Dashboard layout and data presentation is clear
  **Steps:**
  1. Open http://192.168.10.107:3000/costs in browser
  2. Verify summary cards and session table render
  3. Check numbers match `cd /opt/999-Agentic-Engineering-Framework && bin/fw costs` output
  **Expected:** Clean dashboard with token data matching CLI output
  **If not:** Note which sections are broken or confusing

## Verification

test -f web/blueprints/costs.py
test -f web/templates/costs.html
grep -q "costs" web/blueprints/__init__.py
python3 -c "from web.blueprints.costs import bp; print('OK')"
curl -sf http://localhost:3000/costs -o /tmp/T-802-verify.html && grep -qi "token" /tmp/T-802-verify.html

## Recommendation

**Recommendation:** GO

**Rationale:** All 7 Agent ACs verified satisfied: `web/blueprints/costs.py` exists with `/costs` route, blueprint is registered, `web/templates/costs.html` renders the dashboard, and the page loads cleanly. Task has been in NO-REC limbo since 2026-04-12 — feature is delivered and reachable via the Watchtower nav. Awaits Human [REVIEW] of dashboard layout and data presentation.

**Evidence:**
- `test -f web/blueprints/costs.py` → exists.
- `python3 -c "from web.blueprints.costs import bp"` → OK.
- `curl -sf http://localhost:3000/costs` → 200, contains "token" markup.
- Pairs with T-801 (CLI), T-803 (landing widget) — same token-tracking arc, same verified-code state.

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

### 2026-04-03T19:09:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-802-watchtower-token-dashboard--costs-page-w.md
- **Context:** Initial task creation

### 2026-04-03T19:09:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:26:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-28T11:34:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
