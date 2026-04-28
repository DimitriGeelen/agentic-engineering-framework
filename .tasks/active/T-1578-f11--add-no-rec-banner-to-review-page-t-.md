---
id: T-1578
name: "F11 — Add NO-REC banner to /review page (T-1576/T-1577 follow-up — last queue surface)"
description: >
  F11 — Add NO-REC banner to /review page (T-1576/T-1577 follow-up — last queue surface)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-28T11:10:07Z
last_update: 2026-04-28T11:10:07Z
date_finished: null
---

# T-1578: F11 — Add NO-REC banner to /review page (T-1576/T-1577 follow-up — last queue surface)

## Context

T-1576 split NO-REC from `?` on `bin/fw review-queue`, `agents/handover/handover.sh`, and Watchtower `/approvals`. T-1577 extended the same to the cockpit landing-page widget. The remaining queue surface is `/review/T-XXX` itself: when a task has no `## Recommendation` block AND no research artifacts, `web/templates/review.html:381-397` silently renders nothing — no banner explains why the page has no recommendation.

The review blueprint already calls `extract_recommendation(body)` (`web/blueprints/review.py:142,199`) which returns a structured dict including `raw`. So `state == "NO-REC"` is computable from `not rec["raw"].strip()`. Wire this to the template and add a cyan banner that mirrors the convention established in T-1576/T-1577.

## Acceptance Criteria

### Agent
- [ ] `web/blueprints/review.py` passes `state` to both `render_review_page` template renders (alongside existing `verdict`)
- [ ] `web/templates/review.html` adds a `{% elif state == 'NO-REC' %}` branch that renders a cyan banner: heading "Recommendation — NO-REC" + body "The agent has not yet written a `## Recommendation` block for this task"
- [ ] The new branch ranks AFTER `rec_complete` and the `verdict-without-rationale` warning, but BEFORE the artifacts-only fallback (so NO-REC takes precedence over "look at the artifact")
- [ ] Banner uses the same cyan theme (`#0e7490`) used on cockpit pill and `/approvals` filter button (visual continuity)
- [ ] Playwright DOM check: visit `/review/T-XXX` for a NO-REC task (e.g. T-1062) — verify the banner renders with `state="NO-REC"`
- [ ] `python3 -m pytest tests/unit/test_extract_recommendation.py -q` passes (no regression)

### Human
- [ ] [REVIEW] /review page on a NO-REC task reads naturally
  **Steps:**
  1. Open `$(bin/fw watchtower url)/review/T-1062` (a known NO-REC build task)
  2. Confirm the page shows a cyan "NO-REC" banner with text explaining the agent has not yet written a recommendation
  3. Confirm the human ACs section still polls and displays correctly below the banner
  **Expected:** Banner is visually consistent with cockpit / approvals NO-REC pill (same cyan)
  **If not:** Screenshot and note which element clashes

## Verification

python3 -m pytest tests/unit/test_extract_recommendation.py -q
curl -sf "$(bin/fw watchtower url)/review/T-1062" | grep -qE 'NO-REC' && echo "NO-REC banner present" || echo "NO-REC banner missing"

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

### 2026-04-28T11:10:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1578-f11--add-no-rec-banner-to-review-page-t-.md
- **Context:** Initial task creation
