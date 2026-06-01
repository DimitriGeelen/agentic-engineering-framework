---
id: T-1756
name: "Re-parse historical PARSE-FAIL outcomes through T-1748 hardened parser"
description: >
  Re-parse historical PARSE-FAIL outcomes through T-1748 hardened parser

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tools/reparse-historical-parsefails.py]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-05T22:32:50Z
last_update: 2026-05-05T22:37:38Z
date_finished: 2026-05-05T22:37:38Z
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

(The bug-class detector matched on the word "FAIL" in the title — this task is forensic
data recovery, not a bug fix. Filling RCA anyway because the *underlying parser failure*
that produced the 10 PARSE-FAILs is a real bug class worth recording.)

**Symptom:** Pre-T-1748 escalation-scan-v0.5 emitted 10 PARSE-FAIL outcomes in a single
6-minute batch on 2026-05-05 16:29-16:35 UTC. Headline rate showed 4.7% PARSE-FAIL —
which by AC contract was supposed to be ≤5%, so it didn't trip alerts but did decay
the data.

**Root cause:** Original `parse_verdict_envelope` strict-fenced-YAML-only — when the
LLM emitted YAML where the rationale value contained an unquoted colon (`rationale: This
is a fix: a clear bug`), `yaml.safe_load` aborted on the second colon and the whole
envelope was discarded. Fixed in T-1748 with a regex fallback that extracts the verdict
word independently of YAML validity.

**Why structurally allowed:** AC contract said "tolerate ≤5% PARSE-FAIL" — making 4.7%
a "passing" rate. No alert fires because the gate is permissive. T-1748 hardened the
parser; T-1756 closes the loop on already-emitted PARSE-FAILs.

**Prevention:**
- T-1748: regex fallback in parse_verdict_envelope (already shipped).
- T-1756: `tools/reparse-historical-parsefails.py` (this task) — back-propagation when
  parser hardens.
- Future: tightening the AC threshold to 1% PARSE-FAIL would surface parser regressions
  earlier (not in scope here; flagging for inception).

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

## Reviewer Verdict (v1.4)

- **Scan ID:** R-c3a021e6
- **Timestamp:** 2026-05-05T22:37:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-05T22:37:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
