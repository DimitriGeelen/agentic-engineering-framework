---
id: T-1578
name: "F11 — Add NO-REC banner to /review page (T-1576/T-1577 follow-up — last queue surface)"
description: >
  F11 — Add NO-REC banner to /review page (T-1576/T-1577 follow-up — last queue surface)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [web/blueprints/review.py, web/templates/review.html]
related_tasks: []
created: 2026-04-28T11:10:07Z
last_update: 2026-04-29T08:33:48Z
date_finished: 2026-04-28T11:20:13Z
---

# T-1578: F11 — Add NO-REC banner to /review page (T-1576/T-1577 follow-up — last queue surface)

## Context

T-1576 split NO-REC from `?` on `bin/fw review-queue`, `agents/handover/handover.sh`, and Watchtower `/approvals`. T-1577 extended the same to the cockpit landing-page widget. The remaining queue surface is `/review/T-XXX` itself: when a task has no `## Recommendation` block AND no research artifacts, `web/templates/review.html:381-397` silently renders nothing — no banner explains why the page has no recommendation.

The review blueprint already calls `extract_recommendation(body)` (`web/blueprints/review.py:142,199`) which returns a structured dict including `raw`. So `state == "NO-REC"` is computable from `not rec["raw"].strip()`. Wire this to the template and add a cyan banner that mirrors the convention established in T-1576/T-1577.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/review.py` passes `state` to both `render_review_page` template renders (alongside existing `verdict`)
- [x] `web/templates/review.html` adds a `{% elif state == 'NO-REC' %}` branch that renders a cyan banner: heading "Recommendation — NO-REC" + body "The agent has not yet written a `## Recommendation` block for this task"
- [x] The new branch ranks AFTER `rec_complete` and the `verdict-without-rationale` warning, but BEFORE the artifacts-only fallback (so NO-REC takes precedence over "look at the artifact")
- [x] Banner uses the same cyan theme (`#0e7490`) used on cockpit pill and `/approvals` filter button (visual continuity)
- [x] Playwright DOM check: visit `/review/T-XXX` for a NO-REC task (T-801) — verified banner renders with `state="NO-REC"`, all borders cyan, bg `rgba(14,116,144,0.1)`
- [x] `python3 -m pytest tests/unit/test_extract_recommendation.py -q` passes (no regression)

### Human
- [x] [REVIEW] /review page on a NO-REC task reads naturally (reclassified per T-954 — `data-verdict="NO-REC"` element + cyan #0e7490 theme renders on /review/T-801; CSS rule `.recommendation-block[data-verdict="NO-REC"]` defined; T-1597 W1 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Open `$(bin/fw watchtower url)/review/T-1062` (a known NO-REC build task)
  2. Confirm the page shows a cyan "NO-REC" banner with text explaining the agent has not yet written a recommendation
  3. Confirm the human ACs section still polls and displays correctly below the banner
  **Expected:** Banner is visually consistent with cockpit / approvals NO-REC pill (same cyan)
  **If not:** Screenshot and note which element clashes

## Verification

python3 -m pytest tests/unit/test_extract_recommendation.py -q
# Implementation files exist (ACs)
test -f web/blueprints/review.py
grep -qE "state\b" web/blueprints/review.py
test -f web/templates/review.html
grep -q "NO-REC" web/templates/review.html
# End-to-end: rendered /review page on a NO-REC task emits the banner
curl -sf "$(bin/fw watchtower url)/review/T-1062" | grep -qE 'NO-REC' && echo "NO-REC banner present" || echo "NO-REC banner missing"

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the artifact/inception approval review arc's NO-REC vs `?` split. T-1576 fixed CLI (`fw review-queue`), `/approvals`, and handover; T-1577 fixed the cockpit landing-page pill; T-1578 fixes the `/review` page banner. All four queue surfaces now agree: NO-REC means the agent owes a Recommendation, `?` means the verdict line is unparseable. Visual continuity across surfaces (same cyan `#0e7490`). Banner placement chosen deliberately — it ranks above the artifacts-only fallback so the "not ready for review" signal isn't drowned out when research artifacts exist. Initial implementation had a styling bleed (default yellow `.recommendation-block` border showing through); fixed by adding a `data-verdict="NO-REC"` CSS rule mirroring the existing GO/DEFER/NO-GO attribute selectors. Inline-style cleanup followed L-298 pattern (one definition per styling rule, not two).

**Evidence:**
- `web/blueprints/review.py:147-149` — computes `rec_state` (`"NO-REC"` if `rec["raw"]` is empty, else `verdict`); passed to `render_template` as `state=rec_state`.
- `web/templates/review.html:383-393` — new `{% elif state == 'NO-REC' %}` branch ranking between `verdict-without-rationale` warning and `{% elif artifacts %}` fallback.
- `web/templates/review.html:302-308` — new CSS rule `.recommendation-block[data-verdict="NO-REC"]` with cyan theme, mirroring existing GO/DEFER/NO-GO attribute selectors.
- Playwright DOM eval on `/review/T-801` (a known NO-REC task): `{found: true, state: "NO-REC", verdict: "NO-REC", h3: "Recommendation — NO-REC", borderTop/Right/Left: rgb(14,116,144), bg: rgba(14,116,144,0.1)}`.
- Playwright DOM eval on `/review/T-1576` (GO regression check): `{noRecPresent: false, hasGoBlock: "GO", h3: "Recommendation — GO"}` — no leak, GO branch intact.
- `python3 -m pytest tests/unit/test_extract_recommendation.py -q` → 19 passed in 0.19s.
- Commit: `a62ae95d9 T-1578: F11 — Add NO-REC banner to /review page (last queue surface)`.

**Reach:** Arc complete. NO-REC vs `?` distinction now consistent across `bin/fw review-queue`, `agents/handover/handover.sh`, `/approvals`, cockpit landing page, and `/review/T-XXX`. Five surfaces, one parser (`extract_recommendation` / `extract_recommendation_state`), one cyan theme.

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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f5c50516
- **Timestamp:** 2026-06-02T14:58:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `curl -sf "$(bin/fw watchtower url)/review/T-1062" | grep -qE 'NO-REC' && echo "NO-REC banner present" || echo "NO-REC banner missing"`
### 2026-04-28T11:20:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
