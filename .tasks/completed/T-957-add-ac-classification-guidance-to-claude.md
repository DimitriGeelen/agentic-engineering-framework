---
id: T-957
name: "Add AC classification guidance to CLAUDE.md — risk matrix for Human vs Agent
  ACs (T-954 Phase 1)"
description: >
  Add AC classification rule to CLAUDE.md Agent/Human AC Split section. Risk matrix:
  reversibility x subjectivity x blast radius x external visibility. Default RUBBER-STAMP
  functional tests to Agent ACs with verification commands. Keep sovereignty decisions,
  subjective reviews, irreversible external actions as Human. From T-954 GO.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-06T12:11:30Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-06T12:38:09Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
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

# T-957: Add AC classification guidance to CLAUDE.md — risk matrix for Human vs Agent ACs (T-954 Phase 1)

## Context

Add AC classification guidance from T-954 research to CLAUDE.md §Agent/Human AC Split. See `docs/reports/T-954-human-ac-classification-reform.md`.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md contains AC classification rule with risk dimensions
- [x] Classification covers: when to use Human AC vs Agent AC
- [x] "When in doubt, Human" default is explicit
- [x] RUBBER-STAMP conversion guidance included
- [x] Verification tier reference (programmatic, TermLink E2E, Playwright)

## Verification

grep -q "AC Classification" CLAUDE.md
grep -q "Reversible" CLAUDE.md
grep -qi "when in doubt" CLAUDE.md

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

### 2026-04-06T12:11:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-957-add-ac-classification-guidance-to-claude.md
- **Context:** Initial task creation

### 2026-04-06T12:37:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-06T12:38:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-449bafc7
- **Timestamp:** 2026-06-02T15:05:53Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
