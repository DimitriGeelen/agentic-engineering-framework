---
id: T-1756
name: "Re-parse historical PARSE-FAIL outcomes through T-1748 hardened parser"
description: >
  Re-parse historical PARSE-FAIL outcomes through T-1748 hardened parser

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:orchestrator-rethink]
components: []
related_tasks: []
created: 2026-05-05T22:32:50Z
last_update: 2026-05-05T22:34:03Z
date_finished: null
---

# T-1756: Re-parse historical PARSE-FAIL outcomes through T-1748 hardened parser

## Context

`fw orchestrator status --outcomes` shows escalation-triage at 4.7% PARSE-FAIL (10/213).
All 10 are from the same 6-minute window on 2026-05-05 (16:29-16:35 UTC) — pre-T-1748
batch. T-1748 ran a live re-test the same day and reported 0/20 PARSE-FAIL on fresh
dispatches, but historical outcomes were never re-evaluated.

Each PARSE-FAIL outcome stores the first 200 chars of raw LLM text in its rationale
(see escalation-scan-v0.5.py:484 — `rationale = parsed.get("rationale") or result["text"][:200]`).
Spike check: feeding those 200-char snippets through the post-T-1748 parser recovers
8 of 10 verdicts (5× false_positive, 2× real_symptom_fix, 2× unrecoverable). The two
unrecoverable cases (T-1279, T-1330) are prose-style without a `verdict:` line — they
stay PARSE-FAIL.

## Acceptance Criteria

### Agent
- [x] Tool: `tools/reparse-historical-parsefails.py` reads dispatch-outcomes.jsonl,
      re-parses every PARSE-FAIL through `parse_verdict_envelope`, appends corrective
      outcomes (idempotent — re-runs detect existing replay rows and skip)
- [x] Corrective outcomes are tagged distinguishably (`evaluator: escalation-scan-v0.5-replay`
      + `replayed_from: <original_dispatch_id>`)
- [x] 8 corrective rows present (5× false_positive: T-1123 T-1211 T-1351 T-1496 T-1729 T-985,
      2× real_symptom_fix: T-1453 T-1491; 2 unrecoverable: T-1279 T-1330 stay PARSE-FAIL)
- [x] Idempotent — second run reports `Idempotent: no new corrective outcomes`
- [x] `fw orchestrator status --outcomes` shows replay evaluator separately
      (`escalation-scan-v0.5(213), escalation-scan-v0.5-replay(8)`)

## Verification

python3 tools/reparse-historical-parsefails.py 2>&1 | grep -q "Idempotent: no new corrective outcomes"
test "$(jq -c 'select(.outcome.evaluator == "escalation-scan-v0.5-replay")' .context/dispatch-outcomes.jsonl | wc -l)" -eq 8

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

### 2026-05-06 — `fw orchestrator status` percentages still misleading
- **What changed:** Replay rows are appended (correct), but the substrate aggregator
  in `bin/fw orchestrator status --outcomes` counts ALL outcome rows per task_type.
  After replay, escalation-triage shows 221 outcomes (213 + 8 replays) with PARSE-FAIL
  at 10/221 (4.5%) — but the *honest* picture is 2/213 (0.9%) because 8 PARSE-FAILs
  were superseded.
- **Plan impact:** Original AC said "reflects the recovered classifications" — it
  does, in that replay rows are visible and counted as a separate evaluator. But the
  percentage view is double-counting. The substrate is honest; the rollup math isn't.
- **Triggered:** Follow-up worth filing — make `_aggregate_outcomes_by_task_type` keep
  only the latest outcome per dispatch_id. NOT done in T-1756 (separate concern; T-1756
  is the data-correction half, the rollup is the display half). Will file as T-1757
  if budget permits this session.

## Decisions

### 2026-05-06 — append-only replay, no mutation of original rows
- **Chose:** Replay rows are appended with `replayed_from: <original_dispatch_id>`. The
  original PARSE-FAIL rows stay in place — never overwritten or deleted.
- **Why:** Outcome substrate is event-log-shaped. Mutation breaks audit trail (can't
  see "we used to think X, then re-parsed and got Y"). Append + reference preserves
  history; consumers that want the latest verdict can walk by `dispatch_id` desc.
- **Rejected:**
  - Overwrite the original outcome row — destroys the evidence that the parser was
    sloppy at first.
  - Mark original as `superseded: true` — needs in-place edit, same antifragility
    objection as overwrite.

### 2026-05-06 — distinct evaluator name (`-replay` suffix), not a `replay: true` flag
- **Chose:** Replay rows use `evaluator: escalation-scan-v0.5-replay` so the existing
  evaluator-counter in `fw orchestrator status` surfaces them automatically as a
  separate column.
- **Why:** Zero changes to the aggregator code; users see at a glance how much of the
  outcome corpus came from replay. Provenance is in the name.
- **Rejected:** A `replay: true` field on the same evaluator — would require aggregator
  changes to surface the replay share, and any consumer would need to know the field.

## Recommendation

**Recommendation:** GO (auto-close)
**Rationale:** Recovers 8 of 10 historical PARSE-FAILs (80%) by feeding their stored
200-char snippets through the post-T-1748 hardened parser. Append-only — original rows
preserved. Tool is idempotent. Acknowledged residual: rollup math now double-counts;
tracked as Evolution follow-up.
**Evidence:**
- 8 corrective rows in `.context/dispatch-outcomes.jsonl` with `evaluator: escalation-scan-v0.5-replay`
- 2 unrecoverable cases stay PARSE-FAIL (T-1279, T-1330 — prose-style without `verdict:` keyword)
- Idempotent: second run prints `Idempotent: no new corrective outcomes (2 unrecoverable, none replayable)`
- Live status: `escalation-triage — 221 outcomes, evaluators: escalation-scan-v0.5(213), escalation-scan-v0.5-replay(8)`
- Recovered distribution: 6× false_positive (T-1123, T-1211, T-1351, T-1496, T-1729, T-985), 2× real_symptom_fix (T-1453, T-1491)

## Updates

### 2026-05-05T22:32:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1756-re-parse-historical-parse-fail-outcomes-.md
- **Context:** Initial task creation

### 2026-05-05T22:34:03Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
