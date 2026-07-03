---
id: T-2431
name: "Audit WARN — CTL-028: T-1700 is in .tasks/completed/ but frontmatter status='starte..."
description: >
  Audit WARN — CTL-028: T-1700 is in .tasks/completed/ but frontmatter status='starte...

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: c6f1d09be89502eb30ad98b3794addf244dda883
tags: [audit-finding, severity:warn, section:CTL-028]
owner: agent
horizon: null
tags: []
components: [bin/fw]
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
created: 2026-07-02T18:33:13Z
last_update: 2026-07-03T22:40:52Z
date_finished: 2026-07-03T22:40:52Z
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

# T-2431: Audit WARN — CTL-028: T-1700 is in .tasks/completed/ but frontmatter status='starte...
## Trigger

Audit run: 2026-07-02T18:33:13Z
Finding: CTL-028: T-1700 is in .tasks/completed/ but frontmatter status='started-work' (expected: work-completed)

## Finding

```
CTL-028: T-1700 is in .tasks/completed/ but frontmatter status='started-work' (expected: work-completed)
```

Mitigation: Fix: bin/fw task update T-1700 --status work-completed --force, or hand-edit frontmatter to status: work-completed + set date_finished

## RCA

**Symptom:** CTL-028 audit finding - T-1700 is in .tasks/completed/ but frontmatter has status='started-work' instead of 'work-completed'.

**Root cause:** DATA INCONSISTENCY. T-1700 was moved to .tasks/completed/ (likely via `git mv` or hand-move) without updating the frontmatter fields. The task file location (completed/) and frontmatter status field were out of sync.

**Why structurally allowed:** The framework enforces location-status consistency via `fw task update`, but direct file moves (git mv, hand edits) can bypass this. L-390 documents this pattern: "Tasks moved to .tasks/completed/ via git mv (without fw task update --status ...)".

**Prevention:** This is caught by CTL-028 detector in daily audit. Fix: hand-edited frontmatter to set status=work-completed and date_finished=2026-06-15T17:24:03Z (using last_update as completion date).

## Acceptance Criteria

### Agent
- [x] Root cause identified: file location/frontmatter status inconsistency
- [x] Fix implemented: hand-edited T-1700 frontmatter (status + date_finished)
- [x] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "CTL-028: T-1700 is in .tasks/completed/ but frontmatter status='started-work' (expected: work-completed)" && exit 1 || exit 0

## Updates

### 2026-07-02T18:33:13Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: CTL-028: T-1700 status inconsistency
- **Context:** Auto-generated task for audit finding hash c6f1d09be89502eb30ad98b3794addf244dda883

### 2026-07-03T22:42:00Z — fix [manual-edit]
- **Action:** Fixed T-1700 frontmatter inconsistency
- **Change:** status: started-work → work-completed; date_finished: null → 2026-06-15T17:24:03Z
- **File:** .tasks/completed/T-1700-v1-build-install--integrate-litellm-prox.md


## Reviewer Verdict (v1.5)

- **Scan ID:** R-5a939017
- **Timestamp:** 2026-07-03T22:40:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "CTL-028: T-1700 is in .tasks/completed/ but frontmatter status='started-work' (expected: work-completed)" && exit 1 || exit 0`

### 2026-07-03T22:40:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
