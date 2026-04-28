---
id: T-1577
name: "F10 — extend NO-REC distinction to landing-page Action Required widget (T-1576 follow-up)"
description: >
  F10 — extend NO-REC distinction to landing-page Action Required widget (T-1576 follow-up)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-28T10:42:51Z
last_update: 2026-04-28T10:42:51Z
date_finished: null
---

# T-1577: F10 — extend NO-REC distinction to landing-page Action Required widget (T-1576 follow-up)

## Context

T-1576 distinguished NO-REC from `?` on `bin/fw review-queue`, `agents/handover/handover.sh`, and Watchtower `/approvals`. The landing-page **Action Required** widget (`web/templates/cockpit.html:131-175`) was not in T-1576's scope and still conflates the two states behind a single `?` pill.

`web/blueprints/cockpit.py:96` calls `extract_recommendation_verdict` (compat shim) and `:151` aggregates `verdict in ("?", None)` into `unknown_ac_count`. That count powers the cockpit `?` pill (`cockpit.html:169-173`) — so a task missing the `## Recommendation` section entirely renders the same as one with an unparseable verdict, exactly the gap T-1576 closed elsewhere.

L-298 (count divergence across UI surfaces) and L-309 (two systems with different definitions of "needs human") both flag this kind of cross-surface drift as the failure mode worth catching now.

## Acceptance Criteria

### Agent
- [ ] `web/blueprints/cockpit.py:get_human_verify_tasks` adds a `state` field per task using `extract_recommendation_state` (alongside existing `verdict` for backwards compat)
- [ ] `web/blueprints/cockpit.py:get_action_summary` adds `no_rec_ac_count` (state == NO-REC) and updates `unknown_ac_count` to exclude NO-REC (state == "?" only)
- [ ] `web/templates/cockpit.html` renders a NO-REC pill (cyan #0e7490, distinct from `?`) when `no_rec_ac_count > 0`
- [ ] `?` pill tooltip clarifies it now means "verdict unparseable" — separate from "agent owes a recommendation"
- [ ] Counts on cockpit landing page match `/approvals` (NO-REC count, `?` count) — no divergence (L-298)
- [ ] Playwright/screenshot evidence captured per L-310: actual rendered DOM verified, not just template grep
- [ ] `python3 -m pytest tests/unit/test_extract_recommendation.py -q` passes (no regression)

### Human
- [ ] [REVIEW] Cockpit landing-page Action Required pills visually match `/approvals` filter buttons
  **Steps:**
  1. Open `$(bin/fw watchtower url)` in browser (cockpit landing page)
  2. Locate the "Action Required" card; confirm pill row shows `N GO`, `N DEFER`, `N NO-GO`, `N NO-REC` (cyan), `N ?` (separate)
  3. Open `$(bin/fw watchtower url)/approvals` in another tab; confirm the NO-REC and `?` filter button counts match the cockpit pills exactly
  **Expected:** Cockpit and `/approvals` agree on NO-REC count and `?` count
  **If not:** Screenshot both surfaces; note which surface diverges and by how much

## Verification

python3 -m pytest tests/unit/test_extract_recommendation.py -q
curl -sf "$(bin/fw watchtower url)/" | grep -qE 'NO-REC' && echo "NO-REC pill present" || echo "NO-REC pill missing"
python3 -c "from web.blueprints.cockpit import get_action_summary; s = get_action_summary(); assert 'no_rec_ac_count' in s, 'no_rec_ac_count missing from action_summary'; print('action_summary has no_rec_ac_count:', s['no_rec_ac_count'])"

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

### 2026-04-28T10:42:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1577-f10--extend-no-rec-distinction-to-landin.md
- **Context:** Initial task creation
