---
id: T-1490
name: "Add D13 audit discovery check — limbo inceptions (OBS-025)"
description: >
  Inception tasks where decision is recorded but workflow stuck in active/
  go undetected. D5 catches by age only. Add D13 to surface two specific
  classes: A (work-completed + Human AC unticked → sweep eligible) and
  B (started-work + decision + all ACs ticked → transition bug).

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004]
related_tasks: [T-1346, T-1372, T-1376, T-1388]
created: 2026-04-26T09:32:00Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T09:46:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=4 (body:fw-audit-or-doctor);
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1490: Add D13 audit discovery check — limbo inceptions (OBS-025)

## Context

OBS-025 (this session) captured: T-1346 + T-1388 had all Human ACs ticked, decision GO recorded
via inception-workflow, but `status: started-work` with the file still in `.tasks/active/`. T-1372
+ T-1376 sit in the parallel state (status: work-completed in active/ with Human AC unticked,
sweep-eligible).

D5 (lifecycle anomaly) only catches these by AGE (>7 days started-work). It does not detect the
combination signature: inception + decision recorded + stuck. Add D13 to surface them
deterministically.

The underlying transition-failure bug (do_inception_decide writes Decision section but
update-task.sh refuses status transition) deserves its own RCA — out of scope for this task,
which is the *visibility* layer.

## Acceptance Criteria

### Agent

- [x] D13 inserted in agents/audit/audit.sh right after D5 (same idiom — Python heredoc → WARN/PASS line → case)
- [x] D13 detects Class A: workflow_type=inception + status=work-completed + has Decision GO/NO-GO/DEFER + ≥1 unchecked Human AC
- [x] D13 detects Class B: workflow_type=inception + status=started-work + has Decision GO/NO-GO/DEFER + 0 unchecked Human ACs
- [x] WARN message labels A vs B counts and includes per-task tags (e.g. `T-1388(B) T-1372(A:1hu)`)
- [x] Output capped at 8 items with `(+N more)` suffix for readability
- [x] Mitigation hint distinguishes the two classes' fixes (sweep vs manual update-task.sh)
- [x] `bash -n agents/audit/audit.sh` parses
- [x] D13 reports current limbo state correctly (T-1372 + T-1376 + T-1388 = 3 tasks; T-1346 closed earlier this session)
- [x] No regression in surrounding D-checks (D5, D3 still emit normally)
- [x] Bats test in `tests/unit/audit_d13_inception_limbo.bats`: synthesize fixture tasks for each class, run the D13 python block standalone, assert WARN count + per-task tags

## Verification

bash -n agents/audit/audit.sh
bats tests/unit/audit_d13_inception_limbo.bats >/dev/null
bin/fw audit > /tmp/fw-audit-T-1490.log 2>&1; grep -q "^\[WARN\] D13: Inception limbo" /tmp/fw-audit-T-1490.log

## Updates

### 2026-04-26T09:32:00Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cddfce05
- **Timestamp:** 2026-06-02T14:57:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 2
     - evidence: `bats tests/unit/audit_d13_inception_limbo.bats >/dev/null`
### 2026-04-26T09:46:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
