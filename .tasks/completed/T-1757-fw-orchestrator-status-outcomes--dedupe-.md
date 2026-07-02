---
id: T-1757
name: "fw orchestrator status outcomes — dedupe by dispatch_id, prefer latest evaluator"
description: >
  fw orchestrator status outcomes — dedupe by dispatch_id, prefer latest evaluator

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw, tests/unit/test_orchestrator_outcome_dedup.py]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-05T22:38:24Z
last_update: '2026-06-11T22:23:58Z'
date_finished: 2026-05-05T22:41:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1757: fw orchestrator status outcomes — dedupe by dispatch_id, prefer latest evaluator

## Context

T-1756 Evolution flagged this. Replay rows are append-only (audit trail) but the
aggregator in `bin/fw orchestrator status --outcomes` counts ALL outcome rows per
task_type, so post-replay the percentages double-count: PARSE-FAIL still shows 10/221
(4.5%) when the honest picture is 2/213 (0.9% — 8 superseded by replays).

Fix: when aggregating per-task_type, keep only the *latest* outcome per `dispatch_id`
(by `ts`). Original PARSE-FAIL rows stay in the substrate (audit trail) but the rollup
honors the supersession.

## Acceptance Criteria

### Agent
- [x] `_aggregate_outcomes_by_task_type` in bin/fw groups outcomes by `dispatch_id`,
      keeps only the latest by timestamp before counting (lines ~3340-3361)
- [x] After fix: `fw orchestrator status --outcomes` shows escalation-triage with
      `verdict PARSE-FAIL                   2 (  1.0%)` (was 10 / 4.5%)
- [x] Total outcome count for escalation-triage drops 221 → 191 (collapses 30 duplicate
      outcome rows: 22 pre-existing duplicate evaluations + 8 T-1756 replay rows)
- [x] Unit test: `tests/unit/test_orchestrator_outcome_dedup.py` — 4/4 pass (replay
      supersedes; no-replay unchanged; orphan skipped; 3-outcome-keeps-latest)

## Verification

python3 -m pytest tests/unit/test_orchestrator_outcome_dedup.py -q
test "$(bin/fw orchestrator status --outcomes 2>&1 | grep -c 'verdict PARSE-FAIL\s*2')" -eq 1

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

### 2026-05-06 — dedup collapsed more than expected
- **What changed:** Initial AC predicted 221 → 213 (the 8 T-1756 replays). Actual
  collapse was 221 → 191, because the substrate already had 22 dispatches with multiple
  evaluator rows from previous re-runs (cron jobs, manual replays). The dedup is correct
  for both cases — latest-per-dispatch is the right semantic.
- **Plan impact:** None — the AC text was off by 22 (a guess at filing time), but the
  semantic was right. Adjusted AC text to match observed reality.
- **Triggered:** None. Worth noting for future capacity planning: cron re-runs
  produce duplicates that the rollup must dedupe, not just T-1756-style replays.

## Decisions

### 2026-05-06 — dedup at rollup time, not at substrate time
- **Chose:** Substrate stays append-only; the dedup happens in `_aggregate_outcomes_by_task_type`
- **Why:** The audit trail "we used to think X, then re-evaluated and got Y" is valuable
  history. Dropping replaced rows from the substrate destroys that. Rolling up the latest
  per dispatch_id at *display* time gives the honest summary while keeping the trail intact.
- **Rejected:** Mutate the substrate to mark superseded rows — would require in-place
  edits to a JSONL file, race conditions with concurrent writers, and breaks event-log
  semantics.

### 2026-05-06 — string-compare timestamps, not parse-and-compare
- **Chose:** `(o.get("ts") or "") > (prev.get("ts") or "")` — lexicographic compare
- **Why:** All ts values are ISO 8601 with timezone; lexicographic equals chronological
  for that format. No datetime imports, no parsing failures.
- **Rejected:** `datetime.fromisoformat()` — adds parsing cost and a potential failure
  mode (malformed timestamps would raise instead of sorting predictably).

## Recommendation

**Recommendation:** GO (auto-close)
**Rationale:** Closes T-1756 Evolution follow-up. PARSE-FAIL rate now reflects the
true post-recovery state (1.0% instead of 4.5%). Audit trail preserved.
**Evidence:**
- Before: `escalation-triage — 221 outcomes ... verdict PARSE-FAIL 10 (4.5%)`
- After: `escalation-triage — 191 outcomes ... verdict PARSE-FAIL 2 (1.0%)`
- Unit test: 4/4 pass in `tests/unit/test_orchestrator_outcome_dedup.py`
- Substrate unchanged: `.context/dispatch-outcomes.jsonl` row count is identical;
  the dedup happens in the aggregator, not on disk

## Updates

### 2026-05-05T22:38:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1757-fw-orchestrator-status-outcomes--dedupe-.md
- **Context:** Initial task creation

### 2026-05-05T22:39:17Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

## Reviewer Verdict (v1.5)

- **Scan ID:** R-476d02c3
- **Timestamp:** 2026-06-02T14:59:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-05T22:41:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
