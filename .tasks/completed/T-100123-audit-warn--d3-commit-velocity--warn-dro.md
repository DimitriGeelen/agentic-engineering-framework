---
id: T-100123
name: "Audit WARN — D3: Commit velocity — WARN drop today=5 avg=55 ratio=0.1x"
description: >
  Audit WARN — D3: Commit velocity — WARN drop today=5 avg=55 ratio=0.1x

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: 418c5b9a1ff29b538b4577b14304f5ad768770ad
tags: [audit-finding, severity:warn, section:audit]
owner: agent
horizon: null
components: [C-004]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-03T23:02:56Z
last_update: 2026-07-04T22:07:09Z
date_finished: 2026-07-04T22:07:09Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-07-04T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 3
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=3 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-04T10:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 4
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=4 (body:fw-audit-or-doctor);
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); audit_severity=4 
      (fm:audit_severity=warn); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-100123: Audit WARN — D3: Commit velocity — WARN drop today=5 avg=55 ratio=0.1x
## Trigger

Audit run: 2026-07-03T23:02:56Z
Finding: D3: Commit velocity — WARN drop today=5 avg=55 ratio=0.1x

## Finding

```
D3: Commit velocity — WARN drop today=5 avg=55 ratio=0.1x
```

Mitigation: Check if velocity reflects budget pressure or unusual activity

## RCA

**Symptom:** Daily audit emitted `WARN drop today=5 avg=55 ratio=0.1x` at 01:02 local (23:02Z snapshot) — commit velocity flagged as anomalous while the day went on to log 63 commits.

**Root cause:** The D3 drop check compared `today_count` (a partial day, sometimes minutes old) against the full-day 7-day average. Any audit run in the early hours of an active project fires spuriously: at 01:02 with avg=55, the 0.3 ratio threshold demands 17 commits in the first 62 minutes.

**Why structurally allowed:** the check was written against end-of-day intuition but runs on a cron that fires at arbitrary times; no test pinned the time-of-day dimension, so the partial-day/full-day mismatch was invisible until an early-morning run hit an otherwise-normal day.

**Prevention:** drop side now compares against the prorated expectation (avg x fraction-of-day-elapsed) and is skipped entirely before 06:00; spike side unchanged (a spike only grows). `tests/unit/audit_d3_commit_velocity.bats` pins all four behaviours with a fake git + pinned clock, including a regression test that fails on the old logic (verified: old snippet emits the exact original WARN on the fixture).


## Acceptance Criteria

### Agent
- [x] Root cause identified and documented in RCA section
- [x] Fix implemented (or determination that finding is false positive / transient)
- [x] Re-run audit shows finding absent

## Verification

git show origin/master:agents/audit/audit.sh > /tmp/.t100123 && grep -q "expected_by_now" /tmp/.t100123
grep -q "day_frac" /tmp/.t100123
git show origin/master:tests/unit/audit_d3_commit_velocity.bats > /tmp/.t100123b && grep -q "T-100123 regression" /tmp/.t100123b


## Updates

### 2026-07-03T23:02:56Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: D3: Commit velocity — WARN drop today=5 avg=55 ratio=0.1x
- **Context:** Auto-generated task for audit finding hash 092e122291be9165775dda563bd07896b84f33a2


## Reviewer Verdict (v1.5)

- **Scan ID:** R-7c1fb043
- **Timestamp:** 2026-07-04T22:07:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-04T22:07:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
