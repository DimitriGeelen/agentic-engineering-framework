---
id: T-1712
name: "fw orchestrator status: filter T-stress-* synthetic data from enrichment metric"
description: >
  fw orchestrator status: filter T-stress-* synthetic data from enrichment metric

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [observability]
components: [bin/fw]
related_tasks: [T-1689, T-1696]
arc_id: orchestrator-rethink
created: 2026-05-04T06:39:54Z
last_update: '2026-08-16T22:24:42Z'
date_finished: 2026-05-04T06:43:24Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:42Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1712: fw orchestrator status: filter T-stress-* synthetic data from enrichment metric

## Context

`fw orchestrator status` reads `.context/dispatches.jsonl` and reports
`Enriched: N/M (X%)` as the headline observability metric. This file
currently holds 53 rows: 3 real arc-substrate dispatches (T-1696/T-1697/T-1698,
all enriched 100%) and 50 synthetic stress entries from earlier resolver
testing (`task_id: T-stress-N`, `task_type: null`, `worker_kind: null`,
no outcome telemetry possible). Headline reads "6%" — misleading.

The arc's headline mechanic is "user observes the routing decision live on
/orchestrator and watches per-task-type model preferences shift as the
route_cache learns." The status command is the observation surface for that
mechanic; a denominator inflated by synthetic test rows undermines the
mechanic's signal.

Fix: split the metric. Stress/synthetic rows (task_id matching `^T-stress-`)
are excluded from the enrichment headline; reported separately as
`Synthetic: N` so they're visible but don't pollute. Mirrors the spirit of
T-1710 (failure-mode discrimination — distinguish "as-designed signal" from
"actually broken"), at the metric level.

## Acceptance Criteria

### Agent
- [x] `fw orchestrator status` excludes `T-stress-*` task IDs from `Dispatches`
      and `Enriched` headlines; emits a separate `Synthetic: N` line if any.
      Empty when no synthetic rows present (no extra noise).
      **Verified:** bin/fw:3210-3232 implements `_is_synthetic` filter; live
      output: `Dispatches: 3` + `Synthetic: 50 (T-stress-* — excluded from headline)`.
      Test 5 pins the no-synthetic-no-line behaviour.
- [x] Counter buckets (`by_task_type`, `by_worker_kind`) also exclude stress
      rows so the "?" entries don't dominate the breakdown.
      **Verified:** live output shows `default 3` (no `?` row); test 3 pins
      the no-leak invariant.
- [x] `--json` output reflects the same split: `dispatch_total` and
      `enriched_dispatches` count real rows only; new `synthetic_total` field
      records the stress count.
      **Verified:** `--json` output: `{"dispatch_total":3, "synthetic_total":50,
      "enriched_dispatches":3, "enrichment_ratio":1.0,...}`.
- [x] `tests/unit/test_orchestrator_status_synthetic_filter.bats` pins the
      filter — given 3 real + 50 stress rows, headline reports 3 and
      synthetic 50.
      **Verified:** 7/7 tests pass. Tests cover: real/synthetic split,
      enrichment ratio computed against real only, by_task_type no-?-leak,
      stdout Synthetic line gating (presence + omission), all-synthetic
      edge case, empty-state preserved.
- [x] `bin/fw orchestrator status` continues to show 100% real-enrichment on
      this project (3/3 real dispatches, all enriched).
      **Verified:** headline reads `Enriched: 3/3 (100%)` — was 6% pre-fix.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n bin/fw
bin/fw orchestrator status --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['dispatch_total'] == 3, f'expected 3 real, got {d[\"dispatch_total\"]}'; assert d['synthetic_total'] == 50, f'expected 50 synthetic, got {d[\"synthetic_total\"]}'; assert d['enriched_dispatches'] == 3, f'expected 3 enriched, got {d[\"enriched_dispatches\"]}'; assert d['enrichment_ratio'] == 1.0, f'expected 100% enriched, got {d[\"enrichment_ratio\"]}'"
bin/fw orchestrator status | grep -E "Dispatches:.*3$"
bin/fw orchestrator status | grep -E "Synthetic:\s+50\s+\(T-stress"
bats tests/unit/test_orchestrator_status_synthetic_filter.bats

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

## Decisions

### 2026-05-04 — Filter on task_id pattern, not separate JSONL stream

- **Chose:** In-place filter in `fw orchestrator status` (Python) using
  `task_id.startswith("T-stress-")` as the synthetic-row predicate.
- **Why:** The substrate already records `task_id` per dispatch; routing
  stress rows to a separate JSONL file would require touching the
  resolver/dispatch write path, breaking the simple append-only contract.
  A read-side filter is non-disruptive — every consumer of dispatches.jsonl
  can apply the same predicate if they want, and the filter is one
  function. Synthetic rows still land in dispatches.jsonl for full
  forensic traceability.
- **Rejected:** Move stress rows to `.context/dispatches-stress.jsonl`.
  Larger blast radius (resolver + tests + docs); zero-value upside.
- **Rejected:** Add a `synthetic: true` flag at write time. Same blast
  radius, requires migration of existing rows.

## Recommendation

**Recommendation:** SHIP

**Rationale:**
The arc's headline mechanic is "user observes the routing decision live on
/orchestrator and watches per-task-type model preferences shift as the
route_cache learns." Pre-fix, the substrate observability metric reported
`Enriched: 3/53 (6%)` — a structurally misleading signal because 50 of
those rows are synthetic stress data with null task_type/worker_kind, no
outcome telemetry possible. Post-fix the metric reads `Enriched: 3/3
(100%)` with `Synthetic: 50` shown separately. The headline mechanic
now has accurate signal; synthetic rows are still visible (not hidden) so
forensic traceability is preserved.

**Evidence:**
- bin/fw:3210-3232 — `_is_synthetic` predicate + split into `dispatches`
  (real) and `synthetic` (stress) lists.
- 7/7 bats tests pass (tests/unit/test_orchestrator_status_synthetic_filter.bats).
- Live verification on this project: pre-fix 6%, post-fix 100%.
- Recent dispatches list also drops synthetic noise — was showing
  `T-stress-9` rows in last-5; now shows the 3 real T-1696/T-1697/T-1698
  arc-substrate dispatches.

**Risk acknowledged:**
- The filter relies on the `T-stress-` task_id convention. If future stress
  testing uses a different prefix, those rows leak back into the headline.
  Mitigation: documented in the inline comment + Decisions; if observed,
  generalise the predicate (e.g. read a list from config).
- No migration of existing rows — historical synthetic rows stay in
  dispatches.jsonl. Acceptable: append-only contract preserved, filter
  is read-side.

## Updates

### 2026-05-04T06:39:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1712-fw-orchestrator-status-filter-t-stress--.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2f4676cd
- **Timestamp:** 2026-06-02T14:59:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-04T06:43:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
