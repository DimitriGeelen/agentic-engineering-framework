---
id: T-888
name: "Extract ensure_firewall_open to lib/firewall.sh for reuse"
description: >
  Extract ensure_firewall_open to lib/firewall.sh for reuse

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: [bin/watchtower.sh, lib/firewall.sh]
related_tasks: []
created: 2026-04-05T12:34:31Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-05T12:36:05Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
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

# T-888: Extract ensure_firewall_open to lib/firewall.sh for reuse

## Context

`ensure_firewall_open` lives in `bin/watchtower.sh` but will be needed by the service registry (T-885). Extract to `lib/firewall.sh` as a shared utility.

## Acceptance Criteria

### Agent
- [x] `lib/firewall.sh` exists with `ensure_firewall_open` function
- [x] `bin/watchtower.sh` sources `lib/firewall.sh` instead of inlining the function
- [x] Watchtower still starts correctly with firewall check working

## Verification

# lib/firewall.sh exists and is sourceable
bash -c 'source lib/firewall.sh && type ensure_firewall_open'
# watchtower.sh sources it
grep -q 'lib/firewall.sh' bin/watchtower.sh

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

### 2026-04-05T12:34:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-888-extract-ensurefirewallopen-to-libfirewal.md
- **Context:** Initial task creation

### 2026-04-05T12:36:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2df9f983
- **Timestamp:** 2026-06-02T15:05:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
