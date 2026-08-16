---
id: T-1427
name: "check-tier0 hook strips bash comments before pattern match (false-positive
  on literal fw inception decide in comment)"
description: >
  The Tier 0 check-tier0.sh hook blocked a stat+grep command because a bash comment
  # contained the literal phrase 'fw inception decide'. Heredocs and quoted strings
  are already stripped; comments are not. Add strip_comments before pattern matching
  so commented-out references don't trigger Tier 0 blocks.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T13:43:13Z
last_update: '2026-08-16T22:24:32Z'
date_finished: 2026-04-24T13:45:43Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1427: check-tier0 hook strips bash comments before pattern match (false-positive on literal fw inception decide in comment)

## Context

Today (2026-04-24) the Tier 0 hook blocked a benign `stat + grep` diagnostic command because a preceding bash comment contained the literal phrase `fw inception decide` (the agent was investigating an inception audit log). The Python pattern matcher strips heredocs and quoted strings but not comments — so a commented-out reference triggers the inception-decide rule at line 146. This produces meaningless Tier 0 approval file noise (`.context/approvals/pending-efb7be4405b5.yaml`) and teaches the agent to pre-sanitize every diagnostic command. Fix: add `strip_comments` (bash `#` through end-of-line, honoring quotes) alongside the existing strip_heredocs / strip_quotes pass.

## Acceptance Criteria

### Agent
- [x] `strip_comments` helper added to the Python block in `agents/context/check-tier0.sh`; called after strip_heredocs and strip_quotes
- [x] Multi-line commands with `#` comments containing Tier 0 phrases (e.g. `fw inception decide`) pass through without blocking
- [x] Actual Tier 0 commands still blocked (no regression — raw `fw inception decide` and `fw task update --force` still trigger)
- [x] Regression test in `tests/unit/check_tier0_comment_stripping.bats` covers: comment-hides-phrase passes, raw-phrase blocks, comment-after-real-danger still blocks (8/8 pass including URL-fragment edge case)
- [x] Vendored copy `.agentic-framework/agents/context/check-tier0.sh` synced

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

bash -n agents/context/check-tier0.sh
grep -q 'strip_comments' agents/context/check-tier0.sh
bats tests/unit/check_tier0_comment_stripping.bats
diff -q agents/context/check-tier0.sh .agentic-framework/agents/context/check-tier0.sh

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

### 2026-04-24T13:43:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1427-check-tier0-hook-strips-bash-comments-be.md
- **Context:** Initial task creation

### 2026-04-24T13:45:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6e2e74f8
- **Timestamp:** 2026-06-02T14:57:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
