---
id: T-1334
name: "Wrap pickup-process cron in flock -n (G-051 mitigation, same pattern as T-1331)"
description: >
  Wrap pickup-process cron in flock -n (G-051 mitigation, same pattern as T-1331)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-19T14:00:34Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-19T14:03:10Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
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

# T-1334: Wrap pickup-process cron in flock -n (G-051 mitigation, same pattern as T-1331)

## Context

G-051 mitigation. Same class as T-1330 audit orphans (fixed by T-1331). The pickup-process cron fires every minute without lock coordination — if invocations run slow (e.g. subprocess contention, slow disk), child `fw task create` processes accumulate. Apply the same flock -n pattern T-1331 used for audit sections.

## Acceptance Criteria

### Agent
- [x] `.context/cron/agentic-audit.crontab` pickup-process line wrapped in `flock -n /var/lock/fw-pickup-process.lock -c '...'`
- [x] `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` updated with the same wrapped line
- [x] Flock skip-on-held-lock verified empirically (second flock in same lock returns without running command; first releases → third succeeds)

## Verification

grep -q "flock -n /var/lock/fw-pickup-process.lock" .context/cron/agentic-audit.crontab
grep -q "flock -n /var/lock/fw-pickup-process.lock" /etc/cron.d/agentic-audit-999-agentic-engineering-framework

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

### 2026-04-19T14:00:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1334-wrap-pickup-process-cron-in-flock--n-g-0.md
- **Context:** Initial task creation

### 2026-04-19T14:03:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-49c4ebaf
- **Timestamp:** 2026-06-02T14:56:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
