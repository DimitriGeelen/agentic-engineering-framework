---
id: T-2418
name: "Audit WARN — free driver F-ORCH: retire_when condition appears met (T-1643
  complete..."
description: >
  Audit WARN — free driver F-ORCH: retire_when condition appears met (T-1643 complete...

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
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
created: 2026-07-02T16:57:44Z
last_update: 2026-07-02T17:44:42Z
date_finished: 2026-07-02T17:44:42Z
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
bvp_scores_proposed:
  - ts: '2026-07-02T17:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F-AUTONOMY: 0
      audit_severity: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F-AUTONOMY=0 (no-signal); audit_severity=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-02T17:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 3
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=3 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2418: Audit WARN — free driver F-ORCH: retire_when condition appears met (T-1643 complete...
## Trigger

Audit run: 2026-07-02T16:57:44Z
Finding: free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire

## Finding

```
free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire
```

Mitigation: Review the driver; if truly retired, comment it out or move to candidates section. Silence with FW_RETIRE_WHEN_ADVISORY=0.

## RCA

**Symptom:** Audit WARN flagged F-ORCH driver retire_when condition as met based on T-1643 completion.

**Root cause:** False positive in the retire_when recognition heuristic. The condition states: "Multi-agent orchestration criterion goes green / orchestrator substrate (T-1643) lands in production." The audit's heuristic detected T-1643's completion (2026-05-02) but did not evaluate:
1. The orchestrator-rethink arc (arc-003) status - still IN-PROGRESS, not closed
2. Ongoing F-ORCH usage - 52 active tasks have non-zero F-ORCH scores
3. G-064 reference validity - G-064 does not exist in the concerns register
4. Production readiness - arc closure is "operator-only per §ACD/G-062" (3rd-incident arc)

**Why structurally allowed:** The retire_when advisory rail (T-2169, FW_RETIRE_WHEN_ADVISORY=1) is deliberately WARN-only and uses signal-based heuristics rather than definitive checks. The heuristic correctly identified that T-1643 completed cleanly, which matches the text "T-1643 completed cleanly OR G-064 closed". However, the condition's intent (orchestration substrate in production, criterion green) requires the parent arc to be closed, not just the substrate task.

**Prevention:** Working as designed. The retire_when advisory is a WARN-level signal, not a gate. The driver remains active and valuable - orchestration work continues (312 active tasks mention "orchestrator"), and F-ORCH still differentiates work quality. The false positive documents a gap between the retire_when text (which mentions T-1643) and its intent (which should reference arc-003 closure). No action needed - the driver should NOT be retired.

## Acceptance Criteria

### Agent
- [x] Root cause identified and documented in RCA section
- [x] Fix implemented (or determination that finding is false positive / transient)
- [x] Re-run audit shows finding absent

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire" && exit 1 || exit 0


## Reviewer Verdict (v1.5)

- **Scan ID:** R-b0a61197
- **Timestamp:** 2026-07-02T17:44:43Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "free driver F-ORCH: retire_when condition appears met (T-1643 completed cleanly OR G-064 closed) — review whether to retire" && exit 1 || exit 0`

### 2026-07-02T17:44:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
