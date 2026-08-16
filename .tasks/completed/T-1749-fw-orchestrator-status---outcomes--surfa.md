---
id: T-1749
name: "fw orchestrator status --outcomes — surface per-task-type outcome quality"
description: >
  fw orchestrator status --outcomes — surface per-task-type outcome quality

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [observability, substrate]
components: [bin/fw, tests/unit/test_orchestrator_status_outcomes.py]
related_tasks: [T-1727, T-1748, T-1699]
arc_id: orchestrator-rethink
created: 2026-05-05T18:32:49Z
last_update: '2026-08-16T22:24:43Z'
date_finished: 2026-05-05T18:37:35Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:43Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1749: fw orchestrator status --outcomes — surface per-task-type outcome quality

## Context

`fw orchestrator status` (T-1699) currently shows raw dispatch + outcome counts but does NOT surface outcome quality. Validating T-1748 (PARSE-FAIL hardening) required hand-running `python3 -c "import yaml ..."` against `escalation-drift-LATEST-v0.5.yaml` — i.e. reading the v0.5 working file directly rather than the substrate's authoritative `dispatch-outcomes.jsonl`. Substrate observability is exactly the gap T-1687 is supposed to close: the orchestrator should answer "how is each task_type performing?" without operators reading raw JSONL.

**Scope:** add `--outcomes` flag to `fw orchestrator status` that aggregates per-task-type outcome quality:
- For evaluator=escalation-scan-v0.5: count by `verdict` (real_symptom_fix, false_positive, defer, PARSE-FAIL, ERROR).
- For default evaluator (verification + AC): count `verification_passed=true|false`, `ac_satisfied=true|false`.
- For other evaluators: best-effort verdict-field aggregation.

The existing summary remains the default; `--outcomes` is opt-in and non-breaking. Composes with `--json`.

**Out of scope:** changing the default output (would break scripts). Watchtower UI surface (separate concern). Cross-time-window aggregation / trend lines.

## Acceptance Criteria

### Agent
- [x] **A1.** `fw orchestrator status --outcomes` (without `--json`) prints a new "Outcome quality (by task_type)" section after the existing "By worker_kind" block. Each task_type lists its evaluator + counts of distinct outcome values. Verifiable: run command, inspect output structure.
- [x] **A2.** `fw orchestrator status --outcomes --json` includes a top-level `by_task_type_outcomes` dict with the same data. Verifiable: parse JSON, assert key exists with non-empty content (given live outcomes).
- [x] **A3.** Default `fw orchestrator status` output (without `--outcomes`) is byte-identical to before — no regression. Verifiable: golden-file diff or snapshot test.
- [x] **A4.** When NO outcomes exist for a task_type's dispatches (synthetic only / pre-enrichment), the new section is skipped or shows "(no outcomes yet)" — does not crash. Verifiable via unit test against fixture jsonl with a dispatch but no matching outcome.
- [x] **A5.** Verdict-style outcomes (escalation-scan-v0.5) and verification-style outcomes (default evaluator) are BOTH surfaced — the aggregator routes by outcome shape, not by hardcoded evaluator name. Verifiable: against live data, both `escalation-triage` (verdict) and any other `task_type` with verification_passed/ac_satisfied are visible.
- [x] **A6.** Regression test in `tests/unit/test_orchestrator_status_outcomes.py` runs the inline Python with synthesized fixtures (no live data dependency) and asserts the aggregation contract for both shapes plus the synthetic-skip case.

## Verification

# T-1749 — single-line commands only (L-356).
cd /opt/999-Agentic-Engineering-Framework && bash -n bin/fw
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_orchestrator_status_outcomes.py -q --no-header
cd /opt/999-Agentic-Engineering-Framework && bin/fw orchestrator status > /tmp/_t1749_default.out 2>&1
cd /opt/999-Agentic-Engineering-Framework && bin/fw orchestrator status --outcomes > /tmp/_t1749_outcomes.out 2>&1; grep -q -i "outcome quality" /tmp/_t1749_outcomes.out
cd /opt/999-Agentic-Engineering-Framework && bin/fw orchestrator status --outcomes --json > /tmp/_t1749_outcomes.json 2>&1; python3 -c "import json; d=json.load(open('/tmp/_t1749_outcomes.json')); assert 'by_task_type_outcomes' in d, list(d.keys())"

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

### 2026-05-05 — shape-routed aggregation, not evaluator-hardcoded
- **What changed:** Initial mental model assumed routing by `outcome.evaluator` field — `escalation-scan-v0.5` → verdict path, `default` → verification path. Realized at design time this would block future evaluators: a new evaluator emitting `verdict` would silently disappear unless its name was added to a hardcoded list. Routed by *shape* instead: any outcome with a `verdict` field gets verdict aggregation, any with `verification_passed`/`ac_satisfied` gets verification aggregation. Test (`test_outcomes_flag_routes_by_shape_not_evaluator`) pins the contract using a synthesized `future-evaluator` whose verdicts surface without any hardcoding.
- **Plan impact:** A5 phrased explicitly to require shape-based routing. Saves a future-task evaluator-registration burden.
- **Triggered:** None — caught at design time before implementation.

### 2026-05-05 — synthetic dispatches drop out of outcomes view automatically
- **What changed:** T-1712 already excludes synthetic T-stress-* dispatches from the headline metrics, but I initially thought I'd need a separate exclude in the outcomes path. The aggregator joins outcomes to the *non-synthetic* dispatches dict — if a dispatch is excluded as synthetic, its outcome has no matching task_type in the lookup and drops automatically. No new exclude needed.
- **Plan impact:** AC list unchanged but A4 test name expanded to cover synthetic-skip case explicitly so the join-side exclusion is pinned for future refactors.
- **Triggered:** None.

## Decisions

### 2026-05-05 — opt-in flag rather than always-on
- **Chose:** Make outcome aggregation opt-in via `--outcomes` flag.
- **Why:** Default `fw orchestrator status` output is consumed by handover/audit hooks and human eyeball checks; changing it would risk breaking downstream parsing. Opt-in keeps the default contract intact while making the new view trivially accessible (`--outcomes` is mnemonic).
- **Rejected:** Always-show. Cleaner UX but breaks output-stability contract — A3 would require careful migration of any consumer scripts. Not worth it for this enhancement.

## Recommendation

**Recommendation:** GO

**Rationale:** All 6 agent ACs pass. 8/8 unit tests green pinning the aggregation contract for both verdict and verification shapes, JSON exposure, default-output stability, empty-outcome graceful handling, and synthetic-dispatch exclusion. Live verification against current substrate state shows the new view immediately useful: `escalation-triage 213 outcomes, 4.7% PARSE-FAIL` is now visible at a glance instead of requiring `python3 -c "import yaml..."` against the working file. Closes the substrate observability gap that made T-1748 validation harder than it should have been.

**Bonus observation surfaced:** With T-1748's parser hardening + the 20-candidate live re-run, the live PARSE-FAIL ratio dropped from 5.9% (10/170) to 4.7% (10/213) — i.e. the absolute count is unchanged (the 10 PARSE-FAILs are pre-fix outcomes), but new outcomes added by my live test all parsed cleanly. After enough cron firings overwrite the old outcomes (or once the next backlog-window cycle ships), the rate should converge toward the post-fix baseline.

**Evidence:**
- `bin/fw:3271-3408` — `--outcomes` flag wiring + shape-routed aggregator + render block
- `tests/unit/test_orchestrator_status_outcomes.py` — 8/8 PASS (verdict + verification + shape-routing + JSON + default-stability + empty + synthetic-skip)
- Live output: `bin/fw orchestrator status --outcomes` surfaces 3 task_types (escalation-triage with 213 verdict outcomes, default with 4 verification outcomes, prompt-triage with 2 verification outcomes)

## Updates

### 2026-05-05T18:32:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1749-fw-orchestrator-status---outcomes--surfa.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7632ace1
- **Timestamp:** 2026-06-02T14:59:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-05T18:37:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
