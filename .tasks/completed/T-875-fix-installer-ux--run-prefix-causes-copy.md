---
id: T-875
name: "Fix installer UX — Run: prefix causes copy-paste errors"
description: >
  Fix installer UX — Run: prefix causes copy-paste errors

status: work-completed
workflow_type: build
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-05T05:59:41Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-05T06:02:11Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 4
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=4 
      (body:framework-level-ux); D4=0 (no-signal); F-RECALL=0 (no-signal); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-875: Fix installer UX — Run: prefix causes copy-paste errors

## Context

install.sh prints `Run: /path/fw doctor` when doctor has warnings. Users copy-paste the whole line including `Run:`, getting "Run:: command not found". Discovered from user install output on 025-WokrshopDesigner.

## Acceptance Criteria

### Agent
- [x] install.sh no longer prints `Run:` prefix before commands
- [x] Suggested commands are clearly copy-pasteable without prefix

### Human
- [x] [RUBBER-STAMP] Installer output shows clean copy-pasteable commands
  **Steps:**
  1. `cd /opt/025-WokrshopDesigner && curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash`
  **Expected:** Doctor warning shows command without `Run:` prefix
  **If not:** Check install.sh line ~286

## Verification

grep -q "To see details" install.sh
! grep -q 'echo.*"  Run:' install.sh

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

### 2026-04-05T05:59:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-875-fix-installer-ux--run-prefix-causes-copy.md
- **Context:** Initial task creation

### 2026-04-05T06:02:11Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-12T09:27:24Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9047d0bd
- **Timestamp:** 2026-06-02T15:05:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
