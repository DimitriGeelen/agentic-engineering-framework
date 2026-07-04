---
id: T-100107
name: "Audit WARN — CTL-012: Completed task T-100078 has unchecked AC"
description: >
  Audit WARN — CTL-012: Completed task T-100078 has unchecked AC

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: eedde001bf259367cd73c288e1d36f34ec5dc7cc
tags: [audit-finding, severity:warn, section:CTL-012]
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
created: 2026-07-03T11:02:44Z
last_update: 2026-07-03T16:04:06Z
date_finished: 2026-07-03T16:04:06Z
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

# T-100107: Audit WARN — CTL-012: Completed task T-100078 has unchecked AC
## Trigger

Audit run: 2026-07-03T11:02:44Z
Finding: CTL-012: Completed task T-100078 has unchecked AC

## Finding

```
CTL-012: Completed task T-100078 has unchecked AC
```

Mitigation: Review task completion — AC gate may have been bypassed

## RCA

**Symptom:** Audit CTL-012 flagged T-100078 as having unchecked ACs (same batch as T-100106).

**Root cause:** Duplicate `## Acceptance Criteria` sections in T-100078. Already fixed in T-100106 batch cleanup.

**Why structurally allowed:** Template AC section appended during edit without removing original.

**Prevention:** Fixed by removing duplicate section in T-100078 (same commit as T-100106).

## Acceptance Criteria

### Agent
- [x] Root cause identified: Same as T-100106 (duplicate AC batch)
- [x] Fixed in T-100106 batch (T-100077/078/079/087 all cleaned)
- [x] Re-run audit should show finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-012: Completed task T-100078 has unchecked AC" && exit 1 || exit 0

## Updates

### 2026-07-03T11:02:44Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: CTL-012: Completed task T-100078 has unchecked AC
- **Context:** Auto-generated task for audit finding hash eedde001bf259367cd73c288e1d36f34ec5dc7cc


## Reviewer Verdict (v1.5)

- **Scan ID:** R-99b8d8da
- **Timestamp:** 2026-07-03T16:04:08Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "CTL-012: Completed task T-100078 has unchecked AC" && exit 1 || exit 0`

### 2026-07-03T16:04:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
