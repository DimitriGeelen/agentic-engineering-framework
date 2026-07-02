---
id: T-1331
name: "Add flock wrapper to audit cron entries — prevent orphan audit accumulation"
description: >
  Add flock wrapper to audit cron entries — prevent orphan audit accumulation

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-19T12:48:56Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-19T13:01:25Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=4 (body:fw-audit-or-doctor);
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1331: Add flock wrapper to audit cron entries — prevent orphan audit accumulation

## Context

T-1330 Spike A identified that the "onedev push hang" root cause is NOT onedev — it is 139 orphaned `fw audit --cron` processes (some running >24h, 6+ CPU-hours each) stacking up because no lock prevents concurrent invocations. Each pre-push hook runs `fw audit`, which contends with the orphans.

Immediate remediation (done under T-1330): killed 139 orphans. This task installs the structural prevention so they do not come back.

## Acceptance Criteria

### Agent
- [x] `.context/cron/agentic-audit.crontab` wraps every `fw audit ... --cron` invocation in `flock -n /var/lock/fw-audit-<slug>.lock` so overlapping cron fires skip instead of stack
- [x] Per-section lock file names (not one global) so different audit sections still run in parallel
- [x] Updated crontab installed to `/etc/cron.d/agentic-audit-999-agentic-engineering-framework` (was `/etc/cron.d/agentic-audit`)
- [x] No orphan accumulation after one 30-min cycle (post-fix count: 1 — was 139 pre-fix)
- [x] Lock-skip behaviour tested: second `flock -n` on held lock exits 1 without running payload (empirical test, 2026-04-19)

## Verification
ps aux | grep -v grep | grep -c "fw audit --section" | awk '{if($1>8){exit 1}else{print "ok: "$1" audit processes (expected <=8 = one per section)"}}'
test -f /etc/cron.d/agentic-audit-999-agentic-engineering-framework
grep -c "flock -n" /etc/cron.d/agentic-audit-999-agentic-engineering-framework | awk '{if($1<7){exit 1}else{print "ok: "$1" flock-wrapped entries"}}'
grep -c "flock -n" .context/cron/agentic-audit.crontab | awk '{if($1<7){exit 1}else{print "ok: source file has "$1" flock-wrapped entries"}}'

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

### 2026-04-19T12:48:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1331-add-flock-wrapper-to-audit-cron-entries-.md
- **Context:** Initial task creation

### 2026-04-19T13:01:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b32d9ca6
- **Timestamp:** 2026-06-02T14:56:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
