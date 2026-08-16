---
id: T-891
name: "Add .framework.yaml as persistent tier in fw_config resolution"
description: >
  Add .framework.yaml as persistent tier in fw_config resolution

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/config.sh]
related_tasks: []
created: 2026-04-05T12:46:56Z
last_update: '2026-08-16T22:25:42Z'
date_finished: 2026-04-05T12:49:55Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-891: Add .framework.yaml as persistent tier in fw_config resolution

## Context

`lib/config.sh` has 3 tiers: CLI arg > env var > default. Add a 4th tier between env var and default: read from `.framework.yaml` config section. This makes `fw config set watchtower.port 3001` take effect for all tools using `fw_config`.

## Acceptance Criteria

### Agent
- [x] `fw_config` reads from `.framework.yaml` when env var is not set
- [x] Resolution order: CLI arg > env var > .framework.yaml > default
- [x] Existing behavior unchanged when `.framework.yaml` has no custom settings
- [x] All 524 unit tests still pass

## Verification

bats tests/unit/lib_config.bats
grep -q 'framework.yaml\|_fw_config_file' lib/config.sh

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

### 2026-04-05T12:46:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-891-add-frameworkyaml-as-persistent-tier-in-.md
- **Context:** Initial task creation

### 2026-04-05T12:49:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e4941f21
- **Timestamp:** 2026-06-02T15:05:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
