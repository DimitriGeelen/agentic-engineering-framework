---
id: T-100114
name: "Audit WARN — D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-acti..."
description: >
  Audit WARN — D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-acti...

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: 5e2f5d710864f40107f9bd1b2f9b3b4c0f2adf74
tags: [audit-finding, severity:warn, section:audit]
owner: agent
horizon: null
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
created: 2026-07-03T17:02:27Z
last_update: 2026-07-03T22:06:19Z
date_finished: 2026-07-03T22:06:19Z
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

# T-100114: Audit WARN — D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-acti...
## Trigger

Audit run: 2026-07-03T17:02:27Z
Finding: D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-active) T-1542(67d-active) T-1624(63d-active) T-2170(31d-active) T-2200(29d-active) T-2202(29d-active) T-2205(28d-active) T-2219(27d-active) T-2221(27d-active) (+19 more)

## Finding

```
D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-active) T-1542(67d-active) T-1624(63d-active) T-2170(31d-active) T-2200(29d-active) T-2202(29d-active) T-2205(28d-active) T-2219(27d-active) T-2221(27d-active) (+19 more)
```

Mitigation: Review flagged tasks for process issues

## RCA

**Symptom:** 29 tasks flagged as active 25+ days (D5 lifecycle check) - one day after T-100062/T-100087.

**Root cause:** DUPLICATE of T-100062. Same 29 tasks, same finding - all are partial-complete tasks (owner=human, unchecked Human ACs) awaiting human review. This is organizational backlog from the 2026-07-02 bulk owner=human operation, not a technical defect. Audit ran again 2026-07-03T17:02:27Z (10 hours after T-100087's run) and detected the same pattern with day counts incremented by 1.

**Why structurally allowed:** Framework correctly moves tasks to owner=human when Agent ACs pass but Human ACs remain. Audit D5 check flags long-idle tasks as WARN (not FAIL) - appropriate for backlog awareness. Multiple audit runs detecting the same organizational debt is expected behavior.

**Prevention:** Not applicable - working as designed. See T-100062 for full analysis of the underlying human review queue issue.

## Acceptance Criteria

### Agent
- [x] Root cause identified: DUPLICATE of T-100062
- [x] Documented in RCA section
- [x] No fix needed - references T-100062 as canonical task

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-active) T-1542(67d-active) T-1624(63d-active) T-2170(31d-active) T-2200(29d-active) T-2202(29d-active) T-2205(28d-active) T-2219(27d-active) T-2221(27d-active) (+19 more)" && exit 1 || exit 0

## Updates

### 2026-07-03T17:02:27Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-active) T-1542(67d-active) T-1624(
- **Context:** Auto-generated task for audit finding hash 5e2f5d710864f40107f9bd1b2f9b3b4c0f2adf74


## Reviewer Verdict (v1.5)

- **Scan ID:** R-8ea1f793
- **Timestamp:** 2026-07-03T22:14:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-active) T-1542(67d-active) T-1624(63d-active) T-2170(31d-active) T-2200(29d-active) T-2202(29d-active) T-`

### 2026-07-03T22:06:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
