---
id: T-1529
name: "T-1529: Structural gate for ## Recommendation block (T-679 enforcement)"
description: >
  T-1529: Structural gate for ## Recommendation block (T-679 enforcement)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-04-27T06:15:50Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T06:19:12Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 1
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=1 
      (body:error-msg-improved); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1529: T-1529: Structural gate for ## Recommendation block (T-679 enforcement)

## Context

OBS-031 found 19/22 awaiting-review tasks have no `## Recommendation` block. T-679 rule (CLAUDE.md "Presenting Work for Human Review") is advisory only — no structural gate enforces it. This task ships the gate: when transitioning to `work-completed` and Human ACs remain unchecked (PARTIAL_COMPLETE state), block unless task has a substantive `## Recommendation` block with `**Recommendation:**` content.

## Acceptance Criteria

### Agent
- [x] New gate function `check_recommendation_for_review` in `agents/task-create/update-task.sh` fires only when PARTIAL_COMPLETE=true.
- [x] Uses H2+ terminator regex (L-293 compliance) to extract Recommendation section, strips HTML comments, requires substantive `**Recommendation:**` line.
- [x] Blocks `work-completed` with actionable error message (template for what to add) on missing/empty Recommendation.
- [x] Bypassable via `--skip-recommendation` flag (logged via `log_gate_bypass` like other gates).
- [x] `--force` triggers `--skip-recommendation` (mirroring AC/verification deprecated bundle).
- [x] Test: closing T-1529 itself (which has Recommendation) succeeds; closing a synthetic task with empty Recommendation + unchecked Human AC blocks.

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

## Recommendation

**Recommendation:** GO

**Rationale:** Ships the structural enforcement that T-679 has needed since the rule was written. 19/22 awaiting-review tasks demonstrate the cost of advisory-only enforcement — agents skip recommendations, reviewers see blank pages, the workflow degrades silently. Gate is narrow (fires only on PARTIAL_COMPLETE), bypassable for edge cases, and uses the same shape as P-010/P-011 (familiar to humans and agents).

**Evidence:**
- OBS-031 quantified the gap: 19/22 missing Recommendation
- T-679 rule already in CLAUDE.md as advisory; this just lifts to structural
- L-293 H2+ terminator pattern reused (consistent with T-1519/T-1526/T-1527/T-1528)
- Same `--skip-X` + `--force` bypass pattern as AC/verification gates
- Self-test: T-1529 itself includes a Recommendation block, demonstrating the path agents should follow

## Verification

bash -n agents/task-create/update-task.sh
grep -q 'check_recommendation_for_review' agents/task-create/update-task.sh
grep -q 'SKIP_RECOMMENDATION' agents/task-create/update-task.sh
grep -q 'skip-recommendation' agents/task-create/update-task.sh

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

### 2026-04-27T06:15:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1529-t-1529-structural-gate-for--recommendati.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b69be561
- **Timestamp:** 2026-06-02T14:58:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T06:19:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
