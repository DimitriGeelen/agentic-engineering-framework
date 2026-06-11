---
id: T-868
name: "Fix ((count++)) set -e crash in healing suggest.sh"
description: >
  Fix ((count++)) set -e crash in healing suggest.sh

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/healing/lib/suggest.sh]
related_tasks: []
created: 2026-04-04T22:42:18Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-04T22:43:55Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-868: Fix ((count++)) set -e crash in healing suggest.sh

## Context

`((count++))` under `set -e` exits with code 1 when count=0, silently crashing `fw healing suggest`. Known pattern — see memory and L-001.

## Acceptance Criteria

### Agent
- [x] No `((var++))` pattern in healing suggest.sh
- [x] `fw healing suggest` runs without error

## Verification

grep -vq '((count++))' agents/healing/lib/suggest.sh
bash -n agents/healing/lib/suggest.sh

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

### 2026-04-04T22:42:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-868-fix-count-set--e-crash-in-healing-sugges.md
- **Context:** Initial task creation

### 2026-04-04T22:43:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ff64059d
- **Timestamp:** 2026-06-02T15:05:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
