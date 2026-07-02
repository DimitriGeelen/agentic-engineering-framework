---
id: T-2422
name: "Audit WARN — Completed task T-2411 has no episodic summary"
description: >
  Audit WARN — Completed task T-2411 has no episodic summary

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: d9cbb1994184c0f4f089012980edf167b9185451
tags: [audit-finding, severity:warn, section:audit]
owner: agent
horizon: null
tags: []
components: [lib/review.sh]
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
created: 2026-07-02T17:02:46Z
last_update: 2026-07-02T17:45:43Z
date_finished: 2026-07-02T17:45:43Z
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

# T-2422: Audit WARN — Completed task T-2411 has no episodic summary
## Trigger

Audit run: 2026-07-02T17:02:46Z
Finding: Completed task T-2411 has no episodic summary

## Finding

```
Completed task T-2411 has no episodic summary
```

Mitigation: Run: ./agents/context/context.sh generate-episodic T-2411

## RCA

**Symptom:** Audit detected T-2411 in `.tasks/completed/` with no corresponding episodic summary file in `.context/episodic/`.

**Root cause:** T-2411 was moved to `completed/` via `git mv` (or similar direct file operation) without running `fw task update T-2411 --status work-completed`. The task file still shows `status: started-work` and `date_finished:` (empty), confirming the completion flow was bypassed. The episodic generator (`agents/context/context.sh generate-episodic`) is automatically invoked by `update-task.sh` on `--status work-completed`, but this never ran.

**Why structurally allowed:** File system operations (git mv, manual moves) cannot be prevented. The audit WARN (not FAIL) serves as the detection mechanism for this class. The framework relies on `fw task update` being the canonical completion path, but direct file operations bypass all hooks and auto-triggers.

**Prevention:** Working as designed. The audit detected the gap and emitted this task. Manual episodic generation via `./agents/context/context.sh generate-episodic T-2411` has now created the summary (status: complete, 1 commit, 5 files tracked). The L-390 learning documents this class: "Tasks moved to .tasks/completed/ via git mv (without fw task update --status work-completed) bypass episodic generation." The audit serves as the backstop.

## Acceptance Criteria

### Agent
- [x] Root cause identified and documented in RCA section
- [x] Fix implemented (or determination that finding is false positive / transient)
- [x] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "Completed task T-2411 has no episodic summary" && exit 1 || exit 0


## Reviewer Verdict (v1.5)

- **Scan ID:** R-01110c8d
- **Timestamp:** 2026-07-02T17:45:44Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "Completed task T-2411 has no episodic summary" && exit 1 || exit 0`

### 2026-07-02T17:45:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
