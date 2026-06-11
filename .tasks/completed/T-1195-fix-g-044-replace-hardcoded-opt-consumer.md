---
id: T-1195
name: "Fix G-044: Replace hardcoded /opt/* consumer discovery with configurable path"
description: >
  Fix G-044: Replace hardcoded /opt/* consumer discovery with configurable path

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T06:39:42Z
last_update: '2026-06-11T22:23:42Z'
date_finished: 2026-04-13T06:45:01Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1195: Fix G-044: Replace hardcoded /opt/* consumer discovery with configurable path

## Context

G-044: `fw doctor` scans `/opt/*/.framework.yaml` to find consumer projects. Breaks on non-/opt installations. Two hardcoded sites at bin/fw:1141 and bin/fw:1217.

## Acceptance Criteria

### Agent
- [x] `FW_CONSUMER_SCAN_DIRS` config added to lib/config.sh (default: `/opt`)
- [x] Both /opt/* globs in bin/fw replaced with configurable scan
- [x] No hardcoded /opt/* consumer discovery patterns remain in bin/fw
- [x] CLAUDE.md config table updated with new setting
- [x] fw doctor still finds consumer projects on this machine

## Verification

# No hardcoded /opt/* in consumer discovery (body text references are OK)
cd /opt/999-Agentic-Engineering-Framework && ! grep -n 'for fw_yaml in /opt/\*/' bin/fw
# Config key registered
grep -q 'FW_CONSUMER_SCAN_DIRS' lib/config.sh
# fw doctor runs without error
cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor 2>&1 | grep -c 'Consumer Projects' > /dev/null
# The completion gate runs each command — if any exits non-zero, completion is blocked.

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

### 2026-04-13T06:39:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1195-fix-g-044-replace-hardcoded-opt-consumer.md
- **Context:** Initial task creation

### 2026-04-13T06:45:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5939105b
- **Timestamp:** 2026-06-02T14:55:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 6
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor 2>&1 | grep -c 'Consumer Projects' > /dev/null`
