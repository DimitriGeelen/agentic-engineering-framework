---
id: T-350
name: "Fix main→master branch references in install scripts and docs"
description: >
  Fix main→master branch references in install scripts and docs

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-08T13:37:29Z
last_update: '2026-06-11T22:24:19Z'
date_finished: 2026-03-08T13:42:21Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:19Z'
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

# T-350: Fix main→master branch references in install scripts and docs

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Zero `raw.githubusercontent.com/.../main/install.sh` references remain in codebase
- [x] `install.sh` BRANCH default is `master`

## Verification

# No raw GitHub URLs should reference /main/
! grep -r 'raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/main/' install.sh action.yml README.md FRAMEWORK.md docs/
# install.sh BRANCH default must be master
grep -q 'BRANCH="${BRANCH:-master}"' install.sh

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

### 2026-03-08T13:37:29Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-350-fix-mainmaster-branch-references-in-inst.md
- **Context:** Initial task creation

### 2026-03-08T13:42:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-398029e0
- **Timestamp:** 2026-06-02T15:02:18Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Zero `raw.githubusercontent.com/.../main/install.sh` references remain in codebase
  - **AC-verify-mismatch** (narrow, heuristic) — `path=raw.githubusercontent.com/.../main/install.sh in: Zero `raw.githubusercontent.com/.../main/install.sh` references remain in codebase`
