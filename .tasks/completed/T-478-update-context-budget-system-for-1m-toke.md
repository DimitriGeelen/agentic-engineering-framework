---
id: T-478
name: "Update context budget system for 1M token window (Opus 4.6 GA)"
description: >
  Anthropic announced 1M context GA for Opus 4.6/Sonnet 4.6 on 2026-03-13. Framework
  budget-gate.sh, checkpoint.sh, and CLAUDE.md all hardcode 200K window with thresholds
  at 120K/150K/170K. Update to reflect new 1M window while keeping sensible handover
  headroom.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-14T11:54:22Z
last_update: '2026-06-11T22:24:22Z'
date_finished: 2026-03-14T11:58:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-478: Update context budget system for 1M token window (Opus 4.6 GA)

## Context

Anthropic announced 1M context GA for Opus 4.6/Sonnet 4.6 on 2026-03-13. No beta header required, no pricing premium. Framework budget-gate.sh, checkpoint.sh, and CLAUDE.md all hardcode 200K window with thresholds at 120K/150K/170K. These need updating to reflect the 5x larger window.

## Acceptance Criteria

### Agent
- [x] budget-gate.sh uses configurable CONTEXT_WINDOW (default 1M), thresholds derived from it
- [x] checkpoint.sh uses same configurable CONTEXT_WINDOW, thresholds derived from it
- [x] All hardcoded `200000` and `200K` references replaced in both scripts
- [x] CLAUDE.md Work Proposal Rule updated with new thresholds
- [x] CLAUDE.md escalation ladder updated with new thresholds
- [x] Both scripts pass bash -n syntax check

## Verification

bash -n agents/context/budget-gate.sh
bash -n agents/context/checkpoint.sh
# No hardcoded 200000 remaining in budget scripts
test "$(grep -c '200000' agents/context/budget-gate.sh)" = "0"
test "$(grep -c '200000' agents/context/checkpoint.sh)" = "0"
# CONTEXT_WINDOW variable exists in both
grep -q 'CONTEXT_WINDOW' agents/context/budget-gate.sh
grep -q 'CONTEXT_WINDOW' agents/context/checkpoint.sh
# CLAUDE.md references new thresholds
grep -q '600K' CLAUDE.md
grep -q '800K' CLAUDE.md
grep -q '900K' CLAUDE.md

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

### 2026-03-14T11:54:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-478-update-context-budget-system-for-1m-toke.md
- **Context:** Initial task creation

### 2026-03-14T11:58:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-498b2a5f
- **Timestamp:** 2026-06-02T15:03:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
