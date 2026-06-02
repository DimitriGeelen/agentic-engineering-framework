---
id: T-1584
name: "Surface Recommendation + Reviewer Verdict cards on /tasks/T-XXX page (cross-surface parity with /review T-1575/T-1583 and /approvals T-1531/T-1569)"
description: >
  Surface Recommendation + Reviewer Verdict cards on /tasks/T-XXX page (cross-surface parity with /review T-1575/T-1583 and /approvals T-1531/T-1569)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [web/blueprints/tasks.py, web/templates/task_detail.html]
related_tasks: []
created: 2026-04-28T15:24:55Z
last_update: 2026-04-29T08:33:51Z
date_finished: 2026-04-28T15:30:38Z
---

# T-1584: Surface Recommendation + Reviewer Verdict cards on /tasks/T-XXX page (cross-surface parity with /review T-1575/T-1583 and /approvals T-1531/T-1569)

## Context

`/approvals` (T-1531/T-1569) and `/review` (T-1575/T-1583) both render structured Recommendation and Reviewer Verdict cards. `/tasks/T-XXX` (the canonical task-detail page — every cross-link from cockpit/fabric/search/Watchtower nav lands here) renders neither: the Recommendation and `## Reviewer Verdict (vX.Y)` sections appear ONLY inside the collapsed `<details>` raw markdown block at the bottom of the page, with literal `**Recommendation:** GO` / `**Overall:** PASS` markers visible as plain text.

Same drift class as L-316 (cross-surface inheritance drift) but for the cockpit-extending side: three surfaces consume the same body, only two were upgraded. The most-trafficked surface — the one humans land on by default — was the missed third.

Helpers already exist: `web/shared.py:extract_recommendation` and `web/shared.py:extract_reviewer_verdict`. The `task_detail` route (`web/blueprints/tasks.py:553`) doesn't import them.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/tasks.py:task_detail` imports `extract_recommendation` and `extract_reviewer_verdict`, calls them on `task_content`, passes structured `recommendation` (verdict + rationale_html + evidence_html + complete) and `reviewer` dicts as kwargs to `render_template("task_detail.html", ...)`
- [x] `web/templates/task_detail.html` renders a `.recommendation-block` (with `data-verdict` attribute) immediately after the metadata table, mirroring `review.html` palette (GO green / DEFER orange / NO-GO red / NO-REC cyan)
- [x] `web/templates/task_detail.html` renders a `.reviewer-verdict-block` (with `data-reviewer-overall` attribute) immediately after the recommendation block when the task body has a `## Reviewer Verdict (vX.Y)` section; absent otherwise
- [x] Inline CSS for both blocks added to `task_detail.html` `<style>` block, matching the visual rules already in `review.html`
- [x] When recommendation rationale is empty/placeholder, render an `.rec-incomplete-warning` instead of a verdict badge — same convention as `/review` (T-1575)
- [x] Verification curl-greps confirm: T-1582 (has both blocks) shows `data-verdict="GO"` AND `data-reviewer-overall="PASS"`; T-967 (no reviewer block) does NOT show `.reviewer-verdict-block`
- [x] Existing `/tasks/T-XXX` AC interactivity unchanged — page returns HTTP 200 with familiar structure intact
- [x] `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'` (no regression in shared parsing)

### Human
- [x] [REVIEW] Recommendation + Reviewer cards on /tasks/T-XXX read cleanly alongside metadata (reclassified per T-954 — sections at correct slot on /tasks/T-1582 line 913 (Recommendation, GO) + line 936 (Reviewer Verdict, PASS) + line 944 (Research Artifacts); palette mirrors review.html (#ecfdf5/#10b981/#065f46 for GO/PASS); T-1597 W3 confirm-GO; user-authorized batch close)
  **Steps:**
  1. Open `http://192.168.10.107:3000/tasks/T-1582` in a browser
  2. Look between the metadata table and Research Artifacts section
  **Expected:** Two stacked cards — green Recommendation (GO) with rendered rationale + bullet evidence, then green Reviewer card (PASS, no findings). Neither overshadows the metadata; both visually parallel to the cards on `/review/T-1582`.
  **If not:** Screenshot the section; note whether one or both cards are missing, miscoloured, or visually conflated with the metadata table.

## Verification

# Implementation files exist and call extractors (ACs)
test -f web/blueprints/tasks.py
grep -q "extract_recommendation\|extract_reviewer_verdict" web/blueprints/tasks.py
test -f web/templates/task_detail.html
grep -q "recommendation-block" web/templates/task_detail.html
grep -q "reviewer-verdict-block" web/templates/task_detail.html
# Rendered /tasks page emits both blocks
curl -sf "$(bin/fw watchtower url)/tasks/T-1582" | grep -q '<section class="recommendation-block" data-verdict="GO">'
curl -sf "$(bin/fw watchtower url)/tasks/T-1582" | grep -q '<section class="reviewer-verdict-block" data-reviewer-overall="PASS">'
! curl -sf "$(bin/fw watchtower url)/tasks/T-967" | grep -q '<section class="reviewer-verdict-block"'
curl -sf -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/tasks/T-1582" | grep -q '^200$'
python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'

## RCA

**Symptom:** Opening `/tasks/T-XXX` for any task with a `## Recommendation` and/or `## Reviewer Verdict` section showed neither structurally — both appeared only as raw markdown text inside the collapsed `<details>` raw-body block at the bottom of the page. Verdict markers like `**Recommendation:** GO` and `**Overall:** PASS` were visible as literal text, indistinguishable from any other line in the body. The only mechanical second opinion the framework produces was hidden two surfaces deep on the most-trafficked task viewer.

**Root cause:** When T-1531 added the `verdict` badge to `/approvals` and T-1569 added the reviewer's PASS/FAIL/WARN to the same surface, the per-task viewer (`/tasks/T-XXX`, route in `web/blueprints/tasks.py:553`) was overlooked. T-1575/T-1583 then upgraded `/review/T-XXX` to render both blocks structurally, but again `/tasks/T-XXX` was untouched. Three surfaces consume the same task body; only the two surfaced in immediate scope of the originating tasks got the upgrade. `task_detail` route never imported the existing `extract_recommendation` / `extract_reviewer_verdict` helpers from `web/shared.py`.

**Why structurally allowed:** No invariant test pins "every surface that renders task body must also surface Recommendation + Reviewer Verdict structurally." Same drift class as L-316 (cross-surface inheritance), L-298 (cross-surface count drift), and the F5/F9/F10/F11/T-1582/T-1583 family. The `/tasks` page is not a queue surface (unlike `/approvals` or `/review` which were created specifically as approval surfaces), so it slipped past the F-series sweep that targeted approval queues.

**Prevention:** This task ships parity. Verification commands pin both directions — block presence on T-1582 (has both) AND block absence on T-967 (no reviewer block). The structural-section-element grep (`<section class="..."` rather than just `class="..."`) avoids false positives from CSS rules that share the same class name. A future invariant test ("every blueprint that renders task body must import extract_recommendation + extract_reviewer_verdict") is noted as overkill for the now-three consumers — the next new surface arriving is the natural extraction trigger (matching the toast-machinery threshold T-1582 cited).

## Recommendation

**Recommendation:** GO

**Rationale:** `/tasks/T-XXX` (the canonical task-detail page humans land on by default) now surfaces the agent's Recommendation and the reviewer's mechanical verdict structurally — cross-surface parity with `/approvals` (T-1531/T-1569) and `/review` (T-1575/T-1583). The third surface in the cross-surface drift class L-316 is no longer blind. Both cards stack between metadata and Research Artifacts; palette mirrors `/review` exactly so the same task reads identically across surfaces.

**Evidence:**
- `web/blueprints/tasks.py` — `extract_recommendation` + `extract_reviewer_verdict` + `render_markdown_safe` imported; `task_detail` route extracts and passes `verdict`, `rec_state`, `rec_complete`, `rec_rationale_html`, `rec_evidence_html`, `reviewer` as kwargs.
- `web/templates/task_detail.html` — `.recommendation-block` + `.rec-rationale` + `.rec-evidence` + `.rec-incomplete-warning` + `.reviewer-verdict-block` CSS rules added (mirroring `review.html` palette: GO #ecfdf5/#10b981/#065f46, DEFER #fff7ed/#fb923c/#9a3412, NO-GO #fef2f2/#ef4444/#991b1b, NO-REC #0e74901a/#0e7490/#155e75, PASS/FAIL/WARN reviewer states). Two `<section>` blocks rendered between metadata table and Research Artifacts, guarded by `rec_complete` / `verdict` / `rec_state == 'NO-REC'` for the recommendation card and `reviewer.overall` for the reviewer card.
- All 5 verification commands pass on live `http://192.168.10.107:3000`: T-1582 shows `<section class="recommendation-block" data-verdict="GO">` AND `<section class="reviewer-verdict-block" data-reviewer-overall="PASS">`; T-967 (no reviewer block) does NOT show the reviewer section element; HTTP 200; 24 unit tests pass.
- Cross-checked: extractor returns `{'overall': 'PASS', 'findings': 0, 'needs_human': False}` on T-1582, `{'overall': None, ...}` on T-967 — Jinja guard correctly silences the latter.
- Verification command shape (T-1583 lesson applied): grep specifically for `<section class="..."` rather than bare `class="..."` — avoids false matches against the inline CSS rules that share the same class names (10 CSS rule occurrences vs 0/1 actual section elements).

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

### 2026-04-28T15:24:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1584-surface-recommendation--reviewer-verdict.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b13bb6e9
- **Timestamp:** 2026-06-02T14:58:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 5

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `curl -sf "$(bin/fw watchtower url)/tasks/T-1582" | grep -q '<section class="recommendation-block" data-verdict="GO">'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 9
     - evidence: `curl -sf "$(bin/fw watchtower url)/tasks/T-1582" | grep -q '<section class="reviewer-verdict-block" data-reviewer-overall="PASS">'`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `! curl -sf "$(bin/fw watchtower url)/tasks/T-967" | grep -q '<section class="reviewer-verdict-block"'`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `curl -sf -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/tasks/T-1582" | grep -q '^200$'`
  5. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 12
     - evidence: `python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'`
### 2026-04-28T15:30:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
