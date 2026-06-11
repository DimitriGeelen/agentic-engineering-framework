---
id: T-1771
name: "make cron drift actionable: audit-summary visibility + cron-touching task verification
  convention"
description: >
  T-1768 GO follow-up. (e) audit.sh replicates fw doctor's cron-drift check and FAILs
  on registry/deployed mismatch — drift becomes counted failure in /audit page + cron
  runs (escalates alongside other findings, established pattern). (c) CLAUDE.md addendum:
  cron-touching tasks MUST include 'bin/fw doctor 2>&1 | grep -q "Cron registry in
  sync"' in ## Verification — catches drift at task-completion time before broken
  state ships. Together: (e) catches drift in autonomous monitoring; (c) prevents
  the T-1767 mode (cron-touching task that never deploys) at task-close. Anchor: T-1687
  (orchestrator-rethink arc, G-064 closure path). Predecessor: T-1768 inception (GO
  2026-05-06).

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [governance, cron, audit]
components: [C-004]
related_tasks: []
created: 2026-05-06T17:08:48Z
last_update: '2026-06-11T22:23:58Z'
date_finished: 2026-05-06T17:53:45Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1771: make cron drift actionable: audit-summary visibility + cron-touching task verification convention

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `agents/audit/audit.sh` structure section runs cron-drift check (replicates `bin/fw doctor:1631-1657` logic) — emits `fail` on registry/deployed mismatch or generated-but-not-installed; `warn` on registry-but-not-generated.
- [x] CLAUDE.md gains an addendum (under §Verification Gate (P-011) or §Task System) instructing cron-touching tasks to include `bin/fw doctor 2>&1 | grep -q "Cron registry in sync"` in `## Verification`.
- [x] Bats fixture `tests/unit/test_audit_cron_drift.bats` exists with at least 3 cases: in-sync (pass), registry-deployed-diff (fail), generated-not-installed (fail). Uses isolated TEST_PROJECT — no host pollution (per T-1700/T-1707 lesson). Shipped with 5 cases.
- [x] All bats cases pass: `bats tests/unit/test_audit_cron_drift.bats` — 5/5 ok.
- [x] `bin/fw audit --section structure` against this repo still passes — Pass: 10 (was 9; new "Cron registry in sync" PASS), Warn: 2 (unchanged), Fail: 0 (unchanged). No regression.

### Human
<!-- All criteria are agent-verifiable. -->

## Verification

bats tests/unit/test_audit_cron_drift.bats </dev/null
{ bin/fw audit --section structure 2>&1 || true; } | grep -qE "^(=== STRUCTURE|=== SUMMARY|Pass:|Fail:)"
grep -q "Cron registry in sync" CLAUDE.md
grep -q "cron drift" agents/audit/audit.sh

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

### 2026-05-06 — Filed plan held; severity escalated WARN→FAIL where T-1768 said "counted failure"

- **What changed:** Confirmed during build that `bin/fw doctor:1631-1657` only WARNs on cron drift. T-1768's GO recommendation said "Bump cron-drift WARN to a counted failure in `fw audit` summary" — the word "failure" was deliberate. Inside `audit.sh` I used `fail` (not `warn`) for the two substantive drift cases (registry-vs-deployed mismatch and generated-but-not-installed) because both mean *scheduled jobs aren't running*. Kept `warn` for "registry exists but not generated" since that's a pre-deployment intermediate state, not a silent execution failure. Asymmetric severity is intentional, not an oversight.
- **Plan impact:** None — implementation matches spec. Documented the WARN/FAIL split in the audit.sh inline comment so the reasoning survives.
- **Triggered:** No new sub-tasks. The CLAUDE.md addendum + audit.sh check + bats fixture form a complete vertical slice for G-064 (orchestrator substrate observability via existing channels).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-06T17:08:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1771-make-cron-drift-actionable-audit-summary.md
- **Context:** Initial task creation

### 2026-05-06T17:10:01Z — status-update [task-update-agent]
- **Change:** tags: +governance

### 2026-05-06T17:10:09Z — status-update [task-update-agent]
- **Change:** tags: +cron

### 2026-05-06T17:10:09Z — status-update [task-update-agent]
- **Change:** tags: +audit

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a4756e61
- **Timestamp:** 2026-06-02T14:59:39Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `{ bin/fw audit --section structure 2>&1 || true; } | grep -qE "^(=== STRUCTURE|=== SUMMARY|Pass:|Fail:)"`
### 2026-05-06T17:53:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
