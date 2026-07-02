---
id: T-207
name: "Add YAML parse validation to audit — regression test for all project YAML files"
description: >
  Add YAML parse validation to audit — regression test for all project YAML files

status: work-completed
workflow_type: build
owner: agent
horizon: null
related_tasks: []
created: 2026-02-19T22:59:03Z
last_update: '2026-06-11T22:24:06Z'
date_finished: 2026-02-19T23:01:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:06Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=4 (body:fw-audit-or-doctor); 
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-207: Add YAML parse validation to audit — regression test for all project YAML files

## Context

T-206 fix revealed: learnings.yaml was broken for unknown time, Watchtower showed 0 entries silently. Root cause: no regression test validates project YAML files parse. L-047 and L-045 both called for this — now implementing structural enforcement.

## Acceptance Criteria

### Agent
- [x] Audit structure section validates all .context/project/*.yaml files parse with yaml.safe_load
- [x] Broken YAML produces FAIL (not WARN) — data loss is not a warning
- [x] Valid YAML produces single PASS with count
- [x] CTL-027 registered in controls.yaml

## Verification

# Audit structure section runs clean
bash -c 'fw audit --section structure 2>&1 | grep -c "project YAML files parse correctly" > /dev/null'
# CTL-027 registered
grep -q "CTL-027" .context/project/controls.yaml

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

### 2026-02-19T22:59:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-207-add-yaml-parse-validation-to-audit--regr.md
- **Context:** Initial task creation

### 2026-02-19T23:01:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-508fc6f4
- **Timestamp:** 2026-06-02T15:01:02Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
