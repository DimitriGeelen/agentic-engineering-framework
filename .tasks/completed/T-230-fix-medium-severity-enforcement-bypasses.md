---
id: T-230
name: "Fix MEDIUM severity enforcement bypasses — B-009, B-012, integrity checks"
description: >
  Address MEDIUM severity bypass vectors from T-228: (1) B-012: Extend task gate matcher
  to cover NotebookEdit and side-effect tools. (2) B-009: Add pre-execution validation
  for likely-failing destructive commands. (3) Add enforcement integrity audit to
  fw doctor — verify hooks installed, settings.json intact, gate scripts present.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/context/check-active-task.sh, bin/fw]
related_tasks: []
created: 2026-02-21T14:27:14Z
last_update: '2026-06-11T22:24:14Z'
date_finished: 2026-02-21T14:33:34Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-230: Fix MEDIUM severity enforcement bypasses — B-009, B-012, integrity checks

## Context

MEDIUM severity fixes from T-228 analysis. See `docs/reports/T-228-enforcement-bypass-analysis.md`.

## Acceptance Criteria

### Agent
- [x] B-012: check-active-task.sh handles `notebook_path` (NotebookEdit) in addition to `file_path`
- [x] fw doctor checks matcher coverage — warns if NotebookEdit/WebFetch not in PreToolUse matchers
- [x] fw doctor checks enforcement baseline — stores/verifies settings.json hooks hash
- [x] `fw enforcement baseline` command saves current hook config hash
- [x] Existing `fw doctor` checks still pass

### Human
- [x] Review whether to add NotebookEdit to settings.json PreToolUse matcher

## Verification

# check-active-task.sh handles notebook_path
grep -q "notebook_path" /opt/999-Agentic-Engineering-Framework/agents/context/check-active-task.sh
# fw doctor exits 0 (warnings OK, failures not)
fw doctor > /dev/null 2>&1
# enforcement baseline command exists
grep -q "enforcement" /opt/999-Agentic-Engineering-Framework/bin/fw

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

### 2026-02-21T14:27:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-230-fix-medium-severity-enforcement-bypasses.md
- **Context:** Initial task creation

### 2026-02-21T14:33:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-37711939
- **Timestamp:** 2026-06-02T15:01:35Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 4
     - evidence: `fw doctor > /dev/null 2>&1`
