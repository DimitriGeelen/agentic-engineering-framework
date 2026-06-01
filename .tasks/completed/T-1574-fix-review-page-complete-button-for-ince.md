---
id: T-1574
name: "Fix /review page Complete button for inception tasks (route to inception decide)"
description: >
  Fix /review page Complete button for inception tasks (route to inception decide)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [bin/fw, web/blueprints/review.py, web/blueprints/tasks.py, web/shared.py, web/templates/_review_acs.html, web/templates/review.html]
related_tasks: []
created: 2026-04-28T06:32:41Z
last_update: 2026-04-29T08:33:46Z
date_finished: 2026-04-28T15:11:14Z
---

# T-1574: Fix /review page Complete button for inception tasks (route to inception decide)

## Context

The /review/T-XXX page renders a generic "Complete Task" button regardless of `workflow_type`. For inception tasks, clicking it POSTs to `/api/task/<id>/complete` which runs `fw task update --status work-completed` — but inceptions structurally require `fw inception decide T-XXX go|no-go|defer --rationale "..."` (T-1259/T-1260 agent-invocation guard + auto-tick-on-decide AC ticking). The fw call fails on the AC gate (`@auto-tick-on-decide` markers only fire from `inception decide`), endpoint returns HTTP 500, and htmx silently ignores non-200 → button "does not respond." Reported live on T-1565 (the audit task's own review page).

## Acceptance Criteria

### Agent
- [x] `_review_acs.html` renders GO / NO-GO / DEFER buttons + rationale textarea instead of generic Complete button when `workflow_type == 'inception'`
- [x] Inception decision form posts to existing `/inception/<task_id>/decide` (reuses T-1262/T-1470 path with `--from-watchtower`)
- [x] Generic Complete button still renders for non-inception tasks (no regression)
- [x] `review.py` passes `workflow_type` to template on both `/review/<id>` and `/review/<id>/acs`
- [x] Watchtower restarted; verification commands (rendered form present in both /review and /review/acs, generic Complete button absent for inception) all pass

### Human
- [x] [REVIEW] /review page UX for inception tasks reads naturally — buttons are unambiguous, rationale required (reclassified per T-954 — DOM evidence: form + 3 decide buttons render on /review/T-1565 AND /review/T-1565/acs fragment; verification commands at lines 45-47 cover mechanical core; T-1597 W1 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Open `http://192.168.10.107:3000/review/T-1565`
  2. Verify the page shows GO / NO-GO / DEFER buttons + a rationale textarea (not the generic Complete Task button)
  3. (Optional) Type rationale, click GO; confirm page updates with decision recorded
  **Expected:** Inception decision UX visible; clicking a button with rationale records the decision via `fw inception decide --from-watchtower`
  **If not:** Note which button was missing, paste the htmx response from browser DevTools network tab

## Verification

curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q 'inception-decide-form'
curl -sf "$(bin/fw watchtower url)/review/T-1565/acs" | grep -q 'inception-decide-form'
curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -qv 'class="complete-btn"'

## RCA

**Symptom:** Human clicks "Complete Task" on /review/T-1565 — nothing happens. Button is unresponsive.

**Root cause:** The /review/<id> page is workflow-type-blind. `_review_acs.html` always renders a generic Complete button posting to `/api/task/<id>/complete` which runs `fw task update --status work-completed`. For inception tasks this fails because (a) `@auto-tick-on-decide` agent ACs are only ticked by `fw inception decide`, blocking on AC gate, and (b) the structurally-correct path is `fw inception decide T-XXX go|no-go|defer --from-watchtower`. The endpoint returns 500; htmx default behavior is to ignore non-200 → no visible feedback.

**Why structurally allowed:** /approvals page differentiates inception vs non-inception cards (we shipped F3/F4/F6 last session), but the per-task /review page (mobile QR target, post-T-679) was built once and never re-checked when the inception-decide structural enforcement (T-1259/T-1260) landed. Two surfaces, one pattern, only one updated. Same class as the F5 finding (CLI/web parity asymmetry) but at a different layer.

**Prevention:** This task adds the per-workflow-type rendering. Follow-up gap candidate: /review page lacks visible feedback on htmx 500s — a generic htmx error handler at the review.html layer would catch future silent failures in the same class.



## Recommendation

**Recommendation:** GO

**Rationale:** Bug discovered live on T-1565's own review page (the audit task's surface failed structurally — Watchtower /review showed a generic Complete button on an inception task). Fix routes inception tasks through the existing `/inception/<id>/decide` endpoint (T-1262 `--from-watchtower` path, T-1470 primary-vs-side-effect handling) instead of `/api/task/<id>/complete`. Same shape as last session's F3/F4/F6 — the per-task /review page was the missing third surface.

**Evidence:**
- `web/blueprints/review.py:174,206` — `workflow_type` passed to both `/review/<id>` and `/review/<id>/acs`
- `web/templates/_review_acs.html:57-83` — branch on `workflow_type == 'inception'` renders GO/NO-GO/DEFER + rationale textarea posting to `/inception/<id>/decide`; non-inception path unchanged
- `web/templates/review.html:208-228` — added `.decide-section` / `.decide-buttons` / `.decide-btn-{go,nogo,defer}` styles (touch-friendly 56px min-height)
- All 3 verification commands pass: form present at `/review/T-1565`, fragment endpoint, generic Complete button absent
- Cross-check: T-1538 (inception, no all-checked human ACs) and T-1531 (build) flow through correct branches

**Once human verifies the live UX (final Human AC), task can complete via the new GO/NO-GO/DEFER buttons on its OWN /review page (T-1574 dogfoods its fix).**

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

### 2026-04-28T06:32:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1574-fix-review-page-complete-button-for-ince.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-dc1f42af
- **Timestamp:** 2026-04-28T15:11:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-28T15:11:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
