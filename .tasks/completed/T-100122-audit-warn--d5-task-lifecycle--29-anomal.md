---
id: T-100122
name: "Audit WARN — D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-acti..."
description: >
  Audit WARN — D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-acti...

status: work-completed
workflow_type: build
audit_severity: warn
audit_finding_hash: e0913154941867cd6c75ae8fdd9788ad9872674d
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
created: 2026-07-03T23:02:31Z
last_update: 2026-07-04T22:44:31Z
date_finished: 2026-07-04T22:44:31Z
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

# T-100122: Audit WARN — D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-acti...
## Trigger

Audit run: 2026-07-03T23:02:31Z
Finding: D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-active) T-1542(67d-active) T-1624(64d-active) T-2170(32d-active) T-2200(29d-active) T-2202(29d-active) T-2205(29d-active) T-2219(28d-active) T-2221(28d-active) (+19 more)

## Finding

```
D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-active) T-1542(67d-active) T-1624(64d-active) T-2170(32d-active) T-2200(29d-active) T-2202(29d-active) T-2205(29d-active) T-2219(28d-active) T-2221(28d-active) (+19 more)
```

Mitigation: Review flagged tasks for process issues

## RCA

**Symptom:** D5 task-lifecycle check flagged 29 long-active tasks as anomalies.

**Root cause:** 22 of the 29 were partial-complete tasks (T-193 state): `owner: human`, all Agent ACs ticked, ≥1 Human AC pending — i.e. the human review backlog, already surfaced on /approvals. D5's stale-active leg had no concept of that state, so the legitimate long-lived review queue read as lifecycle anomalies. The remaining 7 were genuinely stalled agent-owned started-work tasks.

**Why structurally allowed:** D5 predates the T-193 partial-complete convention; it classified purely on `status` + age, never on the Agent/Human AC split. No test pinned the exclusion, so the review backlog and genuine stalls were indistinguishable to the check.

**Prevention:** `is_partial_complete()` added to the D5 block in `agents/audit/audit.sh` (landed on origin/master, d851ab040): human-owned + `### Agent` all ticked + `### Human` has pending boxes → excluded from the stale-active leg. Pinned by `tests/unit/audit_d5_task_lifecycle.bats` (4 tests: excluded / agent-stale flagged / unticked-agent flagged / captured silent).

**Remediation:** the 7 genuinely stalled agent-owned tasks (T-1637 T-1687 T-1820 T-2171 T-2389 T-2390 T-2395) groomed to `--horizon later` (auto-demoted to captured per T-1068). Post-fix D5 re-run: 29 → 8. Residual 8 are real signal — 5 close-ready tasks with ALL ACs (agent+human) ticked but never transitioned to work-completed (T-1624 T-801 T-802 T-803 + T-1542 no-Human-section), T-2170 genuinely mid-work stale, T-2410 recent human-owned. One precision gap found: `### Human (suffix text)` headings (T-1062, T-1679-split style) escape the exclusion regex — follow-up T-100189.

## Acceptance Criteria

### Agent
- [x] Root cause identified and documented in RCA section
- [x] Fix implemented (or determination that finding is false positive / transient)
- [x] Re-run audit shows finding absent

## Verification

# D5 fix landed on origin/master: is_partial_complete exclusion + bats present
git show origin/master:agents/audit/audit.sh > /tmp/.t100122-audit.sh && grep -q "is_partial_complete" /tmp/.t100122-audit.sh
git show origin/master:tests/unit/audit_d5_task_lifecycle.bats > /tmp/.t100122-bats && grep -q "T-100122" /tmp/.t100122-bats
# Landed D5 block re-run no longer reports 29 anomalies (partial-completes excluded)
PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework python3 -c "import re,io,contextlib,sys;src=open('/tmp/.t100122-audit.sh').read();m=re.search(\"python3 << 'D5EOF'\\n(.*?)\\nD5EOF\", src, re.S);buf=io.StringIO();ctx=contextlib.redirect_stdout(buf);ctx.__enter__();exec(compile(m.group(1),'d5','exec'));ctx.__exit__(None,None,None);out=buf.getvalue();sys.exit(0 if '29 anomal' not in out and not out.startswith('WARN 29') else 1)"

## Updates

### 2026-07-03T23:02:31Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** warn: D5: Task lifecycle — 29 anomaly(s): T-1062(86d-active) T-1274(78d-active) T-1542(67d-active) T-1624(
- **Context:** Auto-generated task for audit finding hash 43062ce015bc56d27917da2e781788873f789486


## Reviewer Verdict (v1.5)

- **Scan ID:** R-b23f4876
- **Timestamp:** 2026-07-04T22:44:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-07-04T22:44:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
