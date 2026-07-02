---
id: T-971
name: "AC-to-test workflow — Playwright test generation from Agent ACs (T-968 Phase
  3)"
description: >
  When writing UI Agent ACs, generate corresponding Playwright test stubs in tests/playwright/.
  Add test_file field to task template. Update CLAUDE.md AC Classification guidance
  to include test generation requirement for Tier 3 ACs.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-06T19:38:03Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-12T07:55:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-971: AC-to-test workflow — Playwright test generation from Agent ACs (T-968 Phase 3)

## Context

T-968 Phase 3. With T-969 (infrastructure) and T-970 (initial tests) done, codify the going-forward workflow: when writing UI Agent ACs, also write Playwright tests. Update CLAUDE.md §AC Classification and §Verification Tiers. Design: `docs/reports/T-968-v5-ac-to-test-pipeline.md`.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md §AC Classification updated with Playwright test generation requirement for UI ACs
- [x] CLAUDE.md §Verification Tiers updated with `tests/playwright/` reference and `fw test playwright`
- [x] Conversion rules documented (6-row pattern table: curl, grep, element, click, rubber-stamp, review)
- [x] Verification commands pass

## Verification

grep -q 'tests/playwright' CLAUDE.md
grep -q 'Playwright' CLAUDE.md

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

### 2026-04-06T19:38:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-971-ac-to-test-workflow--playwright-test-gen.md
- **Context:** Initial task creation

### 2026-04-06T20:18:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:55:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4f078e1d
- **Timestamp:** 2026-06-02T15:05:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
