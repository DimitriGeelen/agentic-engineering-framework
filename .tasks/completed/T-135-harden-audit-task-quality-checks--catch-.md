---
id: T-135
name: Harden audit task quality checks — catch thin/stub tasks
description: >
  Audit passes tasks with no acceptance criteria, no verification section, placeholder
  context, and descriptions that just say 'see plan Task X'. Add checks: (1) AC section
  exists with >=1 checkbox, (2) Verification section exists, (3) Context is not template
  placeholder, (4) Description is self-contained. Discovered in T-124 cycle 2: sprechloop
  agent created 11 stub tasks that all passed audit.
status: work-completed
workflow_type: build
horizon:
owner: human
tags: []
related_tasks: []
created: 2026-02-17T23:39:34Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-02-17T23:41:40Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
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

# T-135: Harden audit task quality checks — catch thin/stub tasks

## Context

T-124 cycle 2: sprechloop agent created 11 tasks via subagent-driven-development skill. All passed audit despite having no acceptance criteria, no verification section, and template placeholder context. The audit's quality checks were too lenient — only checked description length and update count.

## Acceptance Criteria

- [x] Quality Check 4: AC section with checkboxes required (non-captured, non-inception)
- [x] Quality Check 5: Verification section required for started-work tasks
- [x] Quality Check 6: Context section must not contain template placeholder
- [x] Sprechloop thin tasks now trigger warnings
- [x] Framework tasks with same issues also flagged (dog-fooding)

## Verification

# Audit catches thin tasks (sprechloop T-008 has no AC)
PROJECT_ROOT=/opt/001-sprechloop /opt/999-Agentic-Engineering-Framework/agents/audit/audit.sh 2>&1 > /tmp/audit-t135.txt; grep -q "has no acceptance criteria" /tmp/audit-t135.txt
# Inception tasks are exempt from AC check
grep -q 'inception' agents/audit/audit.sh

## Updates

### 2026-02-17T23:39:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-135-harden-audit-task-quality-checks--catch-.md
- **Context:** Initial task creation

### 2026-02-17T23:41:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4d4385cc
- **Timestamp:** 2026-06-02T14:56:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
