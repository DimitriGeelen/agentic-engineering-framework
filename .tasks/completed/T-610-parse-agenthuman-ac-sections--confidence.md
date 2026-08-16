---
id: T-610
name: "Parse Agent/Human AC sections + confidence markers in Watchtower"
description: >
  Extend Watchtower task detail page to distinguish Agent vs Human ACs. Parse ###
  Agent and ### Human section headers in AC parsing. Parse [RUBBER-STAMP] and [REVIEW]
  confidence markers. Render Human ACs as structured cards (steps/expected/if-not)
  instead of raw text. Disable agent-side checkbox toggling for Human ACs. Prerequisite
  for T-608 Watchtower approval surface.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [web/blueprints/tasks.py, web/templates/task_detail.html]
related_tasks: [T-608, T-611, T-612]
created: 2026-03-25T16:51:14Z
last_update: '2026-08-16T22:25:35Z'
date_finished: 2026-03-27T18:31:55Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
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
  - ts: '2026-08-16T22:25:35Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-610: Parse Agent/Human AC sections + confidence markers in Watchtower

## Context

Part of T-608 Watchtower approval surface (GO decision 2026-03-25). See `docs/reports/T-608-tier0-approval-surface.md`.

## Acceptance Criteria

### Agent
- [x] `_parse_acceptance_criteria()` in `web/blueprints/tasks.py` returns section type (agent/human/none) per AC item
- [x] `[RUBBER-STAMP]` and `[REVIEW]` confidence markers parsed and available in template context
- [x] Human ACs rendered as structured cards with steps/expected/if-not sections
- [x] Human AC checkboxes visually distinct from Agent ACs (disabled or styled differently)
- [x] Task detail page groups ACs under Agent/Human headers when sections exist

### Human
- [x] [REVIEW] Human AC cards render correctly with structured layout
  **Steps:**
  1. Start Watchtower: `cd /opt/999-Agentic-Engineering-Framework && python3 web/app.py`
  2. Open http://localhost:3000/tasks/T-608 (or any task with Human ACs)
  3. Verify Human ACs show as cards with steps/expected/if-not, not raw markdown
  4. Verify Agent ACs show as normal checkboxes
  **Expected:** Clear visual separation between Agent and Human ACs
  **If not:** Screenshot the task detail page and note what's wrong

## Verification

# AC parser exists with section + confidence support
grep -q "_parse_acceptance_criteria" web/blueprints/tasks.py
grep -q "confidence" web/blueprints/tasks.py

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

### 2026-03-25T16:51:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-610-parse-agenthuman-ac-sections--confidence.md
- **Context:** Initial task creation

### 2026-03-25T16:57:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-27T18:31:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-46a97683
- **Timestamp:** 2026-06-02T15:03:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
