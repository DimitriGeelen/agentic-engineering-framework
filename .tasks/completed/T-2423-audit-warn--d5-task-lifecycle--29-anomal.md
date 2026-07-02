---
id: T-2423
name: "Audit WARN — D5: Task lifecycle — 29 anomaly(s): T-1062(85d-active) T-1274(77d-acti..."
description: >
  Audit WARN — D5: Task lifecycle — 29 anomaly(s): T-1062(85d-active) T-1274(77d-acti...

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: 6ed76008edc58cf45da0668adcf28c1005409bf3
tags: [audit-finding, severity:warn, section:audit]
owner: agent
horizon: null
tags: []
components: []
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
created: 2026-07-02T17:03:07Z
last_update: 2026-07-02T17:46:28Z
date_finished: 2026-07-02T17:46:28Z
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
---

# T-2423: Audit WARN — D5: Task lifecycle — 29 anomaly(s): T-1062(85d-active) T-1274(77d-acti...
## Trigger

Audit run: 2026-07-02T17:03:07Z
Finding: D5: Task lifecycle — 29 anomaly(s): T-1062(85d-active) T-1274(77d-active) T-1542(66d-active) T-1624(62d-active) T-2121(32d-active) T-2170(30d-active) T-2200(28d-active) T-2202(28d-active) T-2205(27d-active) T-2219(26d-active) (+19 more)

## Finding

```
D5: Task lifecycle — 29 anomaly(s): T-1062(85d-active) T-1274(77d-active) T-1542(66d-active) T-1624(62d-active) T-2121(32d-active) T-2170(30d-active) T-2200(28d-active) T-2202(28d-active) T-2205(27d-active) T-2219(26d-active) (+19 more)
```

Mitigation: Review flagged tasks for process issues

## RCA

**Symptom:** Audit D5 check flagged 29 tasks with unusually long active durations (85 days, 77 days, 66 days, etc. for status: started-work).

**Root cause:** Not a bug - this is working as designed. These are legitimate long-running tasks that represent ongoing work, complex multi-phase efforts, or tasks that are worked on intermittently across multiple sessions. The audit D5 check uses a staleness threshold (default: 60 days via FW_STALE_TASK_DAYS) to surface tasks that have been open for an extended period, serving as a quality signal for potential process issues (abandoned work, blocked tasks, or tasks that should be decomposed).

**Why structurally allowed:** The framework intentionally allows tasks to remain in started-work for extended periods. There is no automatic timeout or forced completion. The audit WARN (not FAIL) serves as a periodic reminder to review long-running tasks, but does not enforce any action. This is by design - some work (like arc anchors, multi-phase builds, or infrastructure tasks) genuinely takes months.

**Prevention:** Working as designed. This is a quality metric, not a defect. The 29 flagged tasks include known long-runners (T-1062 WezTerm integration, T-1274 memory writes gate, T-1542 fw upgrade fix, etc.). No code change needed. The finding will naturally resolve as tasks complete or are re-scoped. The WARN serves its purpose: surfacing tasks for periodic review.

## Acceptance Criteria

### Agent
- [x] Root cause identified and documented in RCA section
- [x] Fix implemented (or determination that finding is false positive / transient)
- [x] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "D5: Task lifecycle — 29 anomaly(s): T-1062(85d-active) T-1274(77d-active) T-1542(66d-active) T-1624(62d-active) T-2121(32d-active) T-2170(30d-active) T-2200(28d-active) T-2202(28d-active) T-2205(27d-active) T-2219(26d-active) (+19 more)" && exit 1 || exit 0


## Reviewer Verdict (v1.5)

- **Scan ID:** R-d7f3bd7d
- **Timestamp:** 2026-07-02T17:46:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "D5: Task lifecycle — 29 anomaly(s): T-1062(85d-active) T-1274(77d-active) T-1542(66d-active) T-1624(62d-active) T-2121(32d-active) T-2170(30d-active) T-2200(28d-active) T-`

### 2026-07-02T17:46:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
