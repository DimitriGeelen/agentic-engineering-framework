---
id: T-2428
name: "Audit WARN — free driver F-ORCH: retire_when condition appears met (T-1643 complete..."
description: >
  Audit WARN — free driver F-ORCH: retire_when condition appears met (T-1643 complete...

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: 835d74df1847b46e4e682e756d78e15ae588d7cd
tags: [audit-finding, severity:warn, section:audit]
owner: human
horizon: now
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
created: 2026-07-02T18:32:08Z
last_update: 2026-07-03T22:33:43Z
date_finished: 2026-07-03T22:33:43Z
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

# T-2428: Audit WARN — free driver F-ORCH: retire_when condition appears met (T-1643 complete...
## Trigger

Audit run: 2026-07-02T18:32:08Z
Finding: free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire

## Finding

```
free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire
```

Mitigation: Review the driver; if truly retired, comment it out or move to candidates section. Silence with FW_RETIRE_WHEN_ADVISORY=0.

## RCA

**Symptom:** Audit WARN for F-ORCH driver retire_when condition appearing met.

**Root cause:** T-1643 (orchestrator substrate) is in .tasks/completed/ (completed 2026-07-02), which matches the retire_when condition: "Multi-agent orchestration criterion goes green / orchestrator substrate (T-1643) lands in production."

**Why structurally allowed:** Retire_when advisory (FW_RETIRE_WHEN_ADVISORY=1) emits WARN when heuristic detects the condition text is recognisably satisfied. This is working as designed.

**Prevention:** Not applicable - advisory is functioning correctly. The question is whether to ACT on it.

**Decision required:** F-ORCH was created to score tasks that expand routable-dispatch surface (T-1643 substrate). Memory shows orchestrator is now LIVE (T-2484 GO: `fw resolver run/pick` dispatch real workers; litellm :4000 + systemd). The retire_when says to retire when the substrate lands - but does "lands in production" mean substrate exists, or substrate is fully adopted across all workflow types? This is a strategic driver decision requiring human judgment.

**Options:**
1. RETIRE F-ORCH now (comment out in value-drivers.yaml) - substrate landed
2. KEEP F-ORCH active (update retire_when text) - substrate landed but adoption ongoing
3. SILENCE warning (FW_RETIRE_WHEN_ADVISORY=0) - defer decision

## Acceptance Criteria

### Agent
- [x] Root cause identified: T-1643 completed, matches retire_when text
- [x] Documented in RCA section with strategic context and decision options
- [x] Determination: Not FP/transient - requires human strategic decision (ownership transferred)

### Human
- [ ] [REVIEW] Review F-ORCH driver status given T-1643/T-2484 orchestrator landing
  **Steps:** 
  1. Read RCA above + memory `project_orchestrator_wired_live_t2484.md`
  2. Decide: retire driver (substrate exists) OR keep scoring (adoption ongoing)?
  3. If retire: comment out F-ORCH in `policy/value-drivers.yaml`
  4. If keep: update retire_when text to clarify adoption threshold
  5. If defer: set `FW_RETIRE_WHEN_ADVISORY=0` to silence
  **Expected:** One of three actions taken, audit WARN absent on next run
  **If not:** Driver remains in limbo with persistent WARN

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire" && exit 1 || exit 0

## Updates

### 2026-07-02T18:32:08Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: free driver F-ORCH: retire_when condition appears met
- **Context:** Auto-generated task for audit finding hash 3d6037d518b559e687a0801455de7b4c56778435

## Recommendation

**Recommendation:** DEFER

**Rationale:** F-ORCH's retire_when condition (T-1643 substrate landed) is technically met, but the driver may still provide strategic value during orchestrator adoption phase. The orchestrator is LIVE (T-2484) but usage patterns and adoption across workflow types are unknown. Deferring allows continued scoring while gathering adoption data. Recommend revisit in 30 days when adoption metrics are available.

**Evidence:**
- T-1643 in `.tasks/completed/` (substrate landed 2026-07-02)
- T-2484 GO: orchestrator wired live (`fw resolver run/pick` dispatching workers)
- Memory `project_orchestrator_wired_live_t2484.md` confirms litellm :4000 + systemd
- No adoption metrics available yet (how many tasks scored high on F-ORCH vs other drivers?)
- Retire_when text ambiguous: "lands in production" could mean exists OR fully adopted


## Reviewer Verdict (v1.5)

- **Scan ID:** R-4b0d1e39
- **Timestamp:** 2026-07-03T22:33:44Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire" && exit 1 || exit 0`

### 2026-07-03T22:33:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
