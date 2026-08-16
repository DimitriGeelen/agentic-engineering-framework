---
id: T-1927
name: "BVP T-NEW-11: per-driver coherence audit check (fw audit warns when arc claims
  D_n≥4 but ≥70% constituents score D_n≤1)"
description: >
  Audit-side coherence check. Per-driver, not aggregated (D3 rejected aggregation).
  Non-blocking — fw audit exit code unaffected. Thresholds (4/70%/1) configurable.
  R2 detection — rubric bias surfaces here.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bvp, build, slice-11, audit]
components: [lib/arc.sh]
related_tasks: [T-1915, T-1916, T-1924, T-1850]
arc_id: value-prioritisation
created: 2026-05-19T07:00:00Z
last_update: '2026-08-16T22:24:49Z'
date_finished: 2026-05-19T08:38:12Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      estimator-fidelity: 0
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: estimator-fidelity=0 (no-signal); D1=4 (body:structural-gate); 
      D2=4 (body:fw-audit-or-doctor); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1927: BVP T-NEW-11 — per-driver coherence audit

## Context

D3 — coherence is a per-driver sanity check, NOT an aggregation input to arc BVP. Enumerates constituents via `arc_id:` (arc-grooming T-NEW-3 migration must have landed, which it has — T-1850).

**Source:** Handoff §7 T-NEW-11; artefact §6 row 11; §4 D3; §7 M4 (thresholds: 4/70%/1).

**R2 detection:** systematic single-driver warnings indicate rubric bias, not arc mis-scoring.

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` gains a new section emitting `BVP coherence: arc <id> claims D<n>=<x> but tasks don't support it (Y of Z constituents score Dn ≤ M, F of fraction threshold F0)` warnings when applicable — proven by fixture (see below)
- [x] Check is per-driver — separate WARN per mismatched driver, not aggregated (loop emits one line per driver in claims dict)
- [x] Check is non-blocking — uses `warn` function (WARN_COUNT++, FAIL_COUNT untouched); audit exit code driven by FAIL_COUNT only
- [x] Thresholds defined as env-overridable variables: `BVP_COHERENCE_ARC_MIN=4`, `BVP_COHERENCE_TASK_MAX=1`, `BVP_COHERENCE_FRACTION=0.7` (env-var override syntax `${BVP_COHERENCE_*:-default}` — cleaner than hard constants)
- [x] Test fixture: constructed probe arc `T1927-coherence-probe` (in-progress, scoped_drivers D1 weight=5, bvp_scores D1:5) + 5 constituent tasks (T-99901..T-99905, arc_id=T1927-coherence-probe, bvp_scores D1:0). Cron audit 2026-05-19T08:30:01Z emitted: `WARN: BVP coherence: arc T1927-coherence-probe claims D1=5 but tasks don't support it (5 of 5 constituents score D1 ≤ 1, 1.00 of fraction threshold 0.7)` — exact expected line. Probe fixture remains uncommitted at session-end (budget critical); will be cleaned up in next session before commit

## Verification

grep -q "BVP_COHERENCE" agents/audit/audit.sh
grep -q "coherence" agents/audit/audit.sh

## Evolution

### 2026-05-19 — Fixture-vs-cron audit lag
- **What changed:** Synchronous bash audit invocations during this session kept getting backgrounded by the harness; cron-launched audits ran in parallel. Result: the audit YAML I was reading was from earlier than the probe creation. The cron audit at 08:30:01Z (after probe creation) finally captured the WARN correctly.
- **Plan impact:** None functional. Note for future: when testing audit changes mid-session, look at `.context/audits/cron/LATEST-CRON.yaml`, not just the main `.context/audits/YYYY-MM-DD.yaml` (those have different cadences).
- **Triggered:** None.

### 2026-05-19 — Probe fixture left uncommitted at budget-critical
- **What changed:** Session reached 95% context budget mid-cleanup; PreToolUse hook blocked further Bash. Probe files (1 arc YAML + 5 task files) remain on disk but uncommitted. Will be removed in next session via `rm` before commit.
- **Plan impact:** Next session must (a) verify probe still exists, (b) remove it, (c) confirm `fw audit` no longer emits T1927-coherence-probe WARN.
- **Triggered:** None — pure cleanup follow-up.

## Recommendation

**Recommendation:** GO (cleanup pending next session)

**Rationale:** Coherence audit ships and works end-to-end. 5/5 Agent ACs satisfied; 2/2 Verification commands pass (both grep targets present in audit.sh). The fixture proof is captured: `.context/audits/cron/2026-05-19-1030.yaml` line 31 shows the exact expected WARN ("BVP coherence: arc T1927-coherence-probe claims D1=5 but tasks don't support it (5 of 5 constituents score D1 ≤ 1, 1.00 of fraction threshold 0.7)"). Non-blocking (uses warn function, FAIL_COUNT untouched). Per-driver (loop over claims dict). Env-overridable thresholds.

**Evidence:**
- `grep -q "BVP_COHERENCE" agents/audit/audit.sh` → 8 matches
- `grep -q "coherence" agents/audit/audit.sh` → 7 matches
- `.context/audits/cron/2026-05-19-1030.yaml` carries the exact WARN line
- Standalone python smoke (run separately) emitted `T1927-coherence-probe|D1|5|5|5|1.00` confirming math
- `bash -n agents/audit/audit.sh` syntax-clean
- Probe fixture remains uncommitted at session-end — handover will track cleanup

Unlocks: R2 detection (rubric bias surfaces here when systematic single-driver mismatches appear).

## Decisions

## Updates

### 2026-05-19T07:47:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d7d3b7d6
- **Timestamp:** 2026-06-02T15:00:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-19T08:38:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
