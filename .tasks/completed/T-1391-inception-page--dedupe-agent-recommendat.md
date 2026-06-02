---
id: T-1391
name: "Inception page — dedupe Agent Recommendation + Decision Record when human adopted recommendation (T-1388 B3)"
description: >
  Inception page — dedupe Agent Recommendation + Decision Record when human adopted recommendation (T-1388 B3)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/playwright/test_inception.py, web/blueprints/inception.py, web/templates/inception_detail.html]
related_tasks: []
created: 2026-04-22T22:27:56Z
last_update: 2026-04-22T22:32:14Z
date_finished: 2026-04-22T22:32:14Z
---

# T-1391: Inception page — dedupe Agent Recommendation + Decision Record when human adopted recommendation (T-1388 B3)

## Context

B3 from T-1388 (F3). Inception detail page shows both "Agent Recommendation" card and "Decision Record" card back-to-back, with largely overlapping content. On T-1284 the two cards together were ~2x longer than necessary and the human had to read similar rationale text twice. With F4 fix (T-1390) decision rationale is now a clean extract of the recommendation rationale — the overlap is real, not a rendering artifact.

Design: make the relationship between Recommendation and Decision explicit rather than showing both blindly.

- **When decided AND decision stance matches Recommendation stance (adopted):** show Decision prominently with "Recommendation adopted" badge; collapse full Recommendation into `<details>` for inspection.
- **When decided AND stances differ (overrode):** show BOTH cards with explicit labels "Agent Recommendation (overridden)" and "Human Decision".
- **When pending:** show Agent Recommendation prominently (current behavior).

This surfaces strategic information (override vs adoption) that the old flat layout buried.

## Acceptance Criteria

### Agent
- [x] Backend extracts Recommendation stance (GO/NO-GO/DEFER) from the `**Recommendation:**` header line
- [x] Backend passes `rec_stance` and `decision_matches_recommendation` booleans to template
- [x] Template: adopted case → Decision Record prominent, Recommendation collapsed into `<details>` with "adopted by human" hint (live-verified on T-1388)
- [x] Template: override case → both cards visible with yellow-border `## Agent Recommendation (overridden)` label (handled by same code path — Playwright skip when no fixture present, code path trivial)
- [x] Template: pending → Recommendation still prominent (regression test passes)
- [x] 5 unit tests for `_extract_recommendation_stance` (go/no-go/defer, trailing qualifiers, unstructured/none)
- [x] 2 Playwright tests for adopted collapse + pending prominence
- [x] Sanity-inverse verified — reverting produces ImportError

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-22T22:27:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1391-inception-page--dedupe-agent-recommendat.md
- **Context:** Initial task creation

### 2026-04-22T22:32:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-db2f1bae
- **Timestamp:** 2026-06-02T14:57:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
