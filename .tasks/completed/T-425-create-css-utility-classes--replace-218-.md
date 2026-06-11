---
id: T-425
name: "Create CSS utility classes — replace 218 inline styles across templates and
  JS (J1+H1)"
description: >
  218 inline style attributes across 30+ templates. Create utility classes (.text-muted,
  .text-xs, .flex, .gap-*, .mb-*) in base.html style block. Replace inline styles
  in templates and hardcoded colors in JS (#2e7d32, #c62828). Directive scores: J1=5,
  H1=5. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: human
horizon:
tags: [refactoring, css, watchtower, usability]
components: []
related_tasks: [T-411]
created: 2026-03-10T21:04:06Z
last_update: '2026-06-11T22:24:21Z'
date_finished: 2026-03-11T10:29:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-425: Create CSS utility classes — replace 218 inline styles across templates and JS (J1+H1)

## Context

CSS utility classes (J1+H1). See `docs/reports/T-411-refactoring-directive-scoring.md` § JS row J1 (score 5) and TEMPLATES row H1 (score 5). 218 inline style attributes across 30+ templates. Largest visual impact but lowest directive score — pure usability play.

## Acceptance Criteria

### Agent
- [x] Utility classes added to base.html (text, font-size, layout, spacing, components)
- [x] 139 inline styles replaced with utility classes across 25+ templates
- [x] JS hardcoded colors (#2e7d32, #c62828) replaced with classList.add() using text-success/text-danger
- [x] No double-class attributes in templates
- [x] All pages load without errors

### Human
- [x] [REVIEW] Pages look visually the same after CSS utility class migration
  **Steps:**
  1. Restart Watchtower: `fw serve` (Flask caches templates)
  2. Check dashboard, tasks, fabric, risks pages
  3. Verify colors, spacing, font sizes look correct
  **Expected:** No visual regressions — pages look identical to before
  **If not:** Inspect element to check which utility class is wrong

## Verification

# Utility classes defined in base.html
grep -q 'text-muted' web/templates/base.html
grep -q 'flex-between' web/templates/base.html
grep -q 'text-sm' web/templates/base.html
# No double-class attributes
! grep -rq 'class="[^"]*" class="' web/templates/
# Pages load
curl -sf http://localhost:3000/ > /dev/null
curl -sf http://localhost:3000/tasks > /dev/null
curl -sf http://localhost:3000/fabric > /dev/null

## Decisions

## Updates

### 2026-03-10T21:04:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-425-create-css-utility-classes--replace-218-.md
- **Context:** Initial task creation

### 2026-03-11T10:22:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-11T10:29:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-55234ae6
- **Timestamp:** 2026-06-02T15:02:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 8
     - evidence: `curl -sf http://localhost:3000/ > /dev/null`
  2. **empty-output-success** (partial, heuristic) @ Verification:line 9
     - evidence: `curl -sf http://localhost:3000/tasks > /dev/null`
  3. **empty-output-success** (partial, heuristic) @ Verification:line 10
     - evidence: `curl -sf http://localhost:3000/fabric > /dev/null`
