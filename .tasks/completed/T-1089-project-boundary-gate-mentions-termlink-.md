---
id: T-1089
name: "Project boundary gate mentions TermLink dispatch as cross-project escape"
description: >
  T-1084 follow-up: check-project-boundary.sh's BLOCKED error message tells the agent
  cross-project work requires human approval but doesn't show HOW. Add a pointer to
  'fw termlink dispatch --project /opt/other' or direct termlink session spawn as
  the documented cross-project mechanism. Single-file change: agents/context/check-project-boundary.sh
  lines 180-195.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-11T10:45:20Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-04-11T10:46:57Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 4
      D4: 4
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=4 (body:cross-machine); F-RECALL=0 
      (no-signal); F-ORCH=1 (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1089: Project boundary gate mentions TermLink dispatch as cross-project escape

## Context

T-1084 follow-up. Boundary gate error at `agents/context/check-project-boundary.sh:180-196` says "Cross-project operations require explicit human approval" but doesn't point to the documented escape. CLAUDE.md references `fw termlink dispatch --project /opt/other` as the canonical cross-project mechanism — the error should mention it so the agent self-unblocks without the human having to recite the trick.

## Acceptance Criteria

### Agent
- [x] Boundary gate BLOCK message includes the TermLink dispatch pattern as the documented cross-project escape route with a copy-pasteable example.
- [x] Change mirrored to `.agentic-framework/agents/context/check-project-boundary.sh`.
- [x] Existing message sections (reason, command, project root, policy) preserved — additive change.

## Verification

grep -q "termlink dispatch" agents/context/check-project-boundary.sh
grep -q "termlink dispatch" .agentic-framework/agents/context/check-project-boundary.sh
grep -q -- "--project" agents/context/check-project-boundary.sh
grep -q -- "--project" .agentic-framework/agents/context/check-project-boundary.sh

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

### 2026-04-11T10:45:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1089-project-boundary-gate-mentions-termlink-.md
- **Context:** Initial task creation

### 2026-04-11T10:46:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6048bd63
- **Timestamp:** 2026-06-02T14:55:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-project`
