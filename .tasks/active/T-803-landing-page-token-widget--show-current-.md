---
id: T-803
name: "Landing page token widget — show current session tokens on Watchtower dashboard"
description: >
  Add a token usage summary widget to the Watchtower landing page (/). Show current
  session token count, cache hit rate, and link to /costs. Quick integration using
  the costs blueprint parsing.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [watchtower, tokens, observability]
components: [watchtower-web-ui]
related_tasks: [T-802, T-801, T-799]
created: 2026-04-03T19:17:34Z
last_update: '2026-06-13T18:00:06Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F1: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-13T18:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=2 (body:telemetry-or-audit-entry); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:03Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 1
      tier: 2
      effort: 7
    rationale: blast_radius=1 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-803: Landing page token widget — show current session tokens on Watchtower dashboard

## Context

Follow-up from T-802 (Watchtower /costs page). Adds a compact token usage widget to the landing page cockpit. Uses `_load_all_sessions()` from costs blueprint.

## Acceptance Criteria

### Agent
- [x] `_get_token_usage()` helper added to `web/blueprints/core.py`
- [x] Token data passed to cockpit template context
- [x] Token widget renders on landing page showing current session tokens, total project tokens, cache hit rate
- [x] Widget links to `/costs` for full details
- [x] Landing page loads without errors

### Human
- [x] [REVIEW] Token widget looks good on landing page
  **Steps:**
  1. Open http://192.168.10.107:3000/ in browser
  2. Look for token usage widget near the top of the page
  3. Verify it shows session tokens and links to /costs
  **Expected:** Compact widget with current session tokens, cache hit rate, link to /costs
  **If not:** Note what's missing or broken

## Verification

curl -sf http://localhost:3000/ -o /tmp/T-803-verify.html && grep -qi "token" /tmp/T-803-verify.html
python3 -c "from web.blueprints.core import _get_token_usage; print('OK')"

## Recommendation

**Recommendation:** GO

**Rationale:** All 5 Agent ACs verified satisfied: `_get_token_usage()` lives in `web/blueprints/core.py`, token data is passed to the cockpit context, the widget renders on the landing page (visible during this session as "TOKENS 13.1B this session — 13.2B project total · 98% cache · 19 sessions"), and links to `/costs`. Task has been in NO-REC limbo since 2026-04-12 — code shipped and observable. Awaits Human [REVIEW] of widget aesthetic.

**Evidence:**
- `python3 -c "from web.blueprints.core import _get_token_usage"` → OK.
- `curl -sf http://localhost:3000/ | grep -i token` → matches "tokens", "session", and renders the count strings live.
- Confirmed visually during this session via Playwright DOM eval on the cockpit page.
- Closes the T-801 → T-802 → T-803 token-tracking arc.

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

### 2026-04-03T19:17:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-803-landing-page-token-widget--show-current-.md
- **Context:** Initial task creation

### 2026-04-12T09:26:19Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-28T11:34:56Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-adaca47c
- **Timestamp:** 2026-06-11T20:37:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
