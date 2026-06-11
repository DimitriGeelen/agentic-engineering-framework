---
id: T-542
name: "Remove sudo calls from install.sh"
description: >
  Remove sudo privilege escalation from install.sh — use ~/.local/bin user-space install
  instead

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-21T15:59:21Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-03-23T09:45:42Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-542: Remove sudo calls from install.sh

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] No sudo calls in install.sh
- [x] link_fw uses ~/.local/bin with PATH instruction
- [x] MODIFY_PATH env var added for CI/automation with idempotency
- [x] install.sh syntax valid (bash -n)
- [x] Exit 0 on success

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-21T15:59:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /home/dimitri-mint-dev/.agentic-framework/.tasks/active/T-514-remove-sudo-calls-from-installsh.md
- **Context:** Initial task creation

### 2026-03-23T09:45:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9a11b4f0
- **Timestamp:** 2026-06-02T15:03:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
