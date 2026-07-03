---
id: T-100106
name: "Audit WARN — CTL-012: Completed task T-100077 has unchecked AC"
description: >
  Audit WARN — CTL-012: Completed task T-100077 has unchecked AC

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: f7c00965919737caf203c52b58809f225793a634
tags: [audit-finding, severity:warn, section:CTL-012]
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
created: 2026-07-03T11:02:19Z
last_update: 2026-07-03T16:03:19Z
date_finished: 2026-07-03T16:03:19Z
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

# T-100106: Audit WARN — CTL-012: Completed task T-100077 has unchecked AC
## Trigger

Audit run: 2026-07-03T11:02:19Z
Finding: CTL-012: Completed task T-100077 has unchecked AC

## Finding

```
CTL-012: Completed task T-100077 has unchecked AC
```

Mitigation: Review task completion — AC gate may have been bypassed

## RCA

**Symptom:** Audit CTL-012 flagged T-100077/078/079/087 as having unchecked ACs despite being in completed/ with work-completed status.

**Root cause:** Duplicate `## Acceptance Criteria` sections. Each file has two AC sections - first with checked boxes (correct), second with unchecked template boxes (spurious). Audit detector counts both sections and sees unchecked boxes.

**Why structurally allowed:** Template AC section was appended during earlier edit without removing the original. No gate prevents duplicate markdown headers.

**Prevention:** Fixed by removing duplicate AC sections. Broader fix: update-task.sh could detect duplicate ## sections on completion and refuse/warn. Or template could use unique anchor names.

## Acceptance Criteria

### Agent
- [x] Root cause identified: Duplicate AC sections in 4 completed tasks
- [x] Fixed by removing duplicate sections from T-100077/078/079/087
- [x] Re-run audit should show findings absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-012: Completed task T-100077 has unchecked AC" && exit 1 || exit 0

## Updates

### 2026-07-03T11:02:19Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: CTL-012: Completed task T-100077 has unchecked AC
- **Context:** Auto-generated task for audit finding hash f7c00965919737caf203c52b58809f225793a634


## Reviewer Verdict (v1.5)

- **Scan ID:** R-e2815641
- **Timestamp:** 2026-07-03T16:03:20Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "CTL-012: Completed task T-100077 has unchecked AC" && exit 1 || exit 0`

### 2026-07-03T16:03:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
