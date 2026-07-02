---
id: T-1095
name: "fw doctor: hoist version-pin drift check from lib/upgrade.sh as a read-only
  doctor check (G-026)"
description: >
  Add a fw doctor check that runs the same version-pin detection as fw upgrade (e.g.
  'Pinned: vdev (behind v2.46.alpha)') without applying changes. Surfaces stale pins
  between upgrade runs. Origin: G-026. Trigger: cross-session ring20-dashboard onboarding
  incident 2026-04-11.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: [T-1093]
created: 2026-04-11T12:15:36Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-04-12T07:20:54Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
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
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1095: fw doctor: hoist version-pin drift check from lib/upgrade.sh as a read-only doctor check (G-026)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `fw doctor` shows version-pin drift for consumer projects
      (already implemented in doctor Consumer Projects fleet scan,
      bin/fw lines 1109-1189: shows `WARN name (vX → vY)`)
- [x] `fw doctor` shows version-pin drift for current project when
      running as consumer (bin/fw lines 569-578)

## Verification

bash -c 'bin/fw doctor 2>&1 | grep -qE "Consumer Projects|All.*consumer"'

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

### 2026-04-11T12:15:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1095-fw-doctor-hoist-version-pin-drift-check-.md
- **Context:** Initial task creation

### 2026-04-12T07:19:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T07:20:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e00b55f2
- **Timestamp:** 2026-06-02T14:55:07Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `bash -c 'bin/fw doctor 2>&1 | grep -qE "Consumer Projects|All.*consumer"'`
