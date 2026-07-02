---
id: T-1697
name: "v1 Outcome enrichment — default evaluator + back-prop hook + append-only dispatch-outcomes.jsonl"
description: >
  v1 Outcome enrichment — default evaluator + back-prop hook + append-only dispatch-outcomes.jsonl

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/task-create/update-task.sh, bin/fw, lib/outcome.py, 
      lib/resolver.py, tests/unit/test_outcome.py, tests/unit/test_resolver.py]
related_tasks: []
created: 2026-05-03T12:59:11Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-03T13:05:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=0 (no-signal); D4=2 
      (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1697: v1 Outcome enrichment — default evaluator + back-prop hook + append-only dispatch-outcomes.jsonl

## Context

Build follow-on to T-1690 (inception GO with design pivot). Ports the
T-1690 spike (`docs/reports/T-1690-spikes/eval_backprop_spike.py`) to
production but **changes storage**: spike used modify-in-place on
`dispatches.jsonl`, which exposed cross-row last-writer-wins under
concurrent enrichment (15/50 preserved at 10 threads). Shipped design
splits storage:

- `.context/dispatches.jsonl` — APPEND-ONLY for the dispatch row (T-1696
  already writes this; we don't modify it)
- `.context/dispatch-outcomes.jsonl` — NEW append-only file keyed by
  `dispatch_id` (one row per outcome event)
- v2 read-path joins them by dispatch_id

Eliminates last-writer-wins entirely AND keeps both files monotone
(simpler rotation + simpler rsync semantics + zero modify-in-place code).

Components shipped:
1. **Default evaluator** — parse `## Verification` + `### Agent` ACs from a
   task file, run the verification commands, count ticked vs total ACs,
   return `{verification_passed, ac_satisfied, ac_total, ac_checked, notes}`.
2. **Back-prop** — given `task_id` + outcome dict, look up matching
   dispatch_ids in `dispatches.jsonl`, append N rows to
   `dispatch-outcomes.jsonl` (one per dispatch_id).
3. **Hook** — `update-task.sh` calls `fw outcome backprop <task_id>` on
   `--status work-completed` (best-effort; failure logs but doesn't block).
4. **Read-path join** — `fw outcome read <dispatch_id>` reads both files.
5. **CLI** — `fw outcome evaluate|backprop|read|list`.

## Acceptance Criteria

### Agent
- [x] `lib/outcome.py` exists, parses cleanly with `python3 -c "import ast; ast.parse(open('lib/outcome.py').read())"`
- [x] `lib/outcome.sh` shim exists and is executable
- [x] `bin/fw outcome --help` exits 0 and lists evaluate, backprop, read, list subcommands
- [x] `bin/fw outcome evaluate T-1696 --json` returns JSON with verification_passed, ac_satisfied, ac_total, ac_checked
- [x] `bin/fw outcome backprop T-1696` appends N rows to `.context/dispatch-outcomes.jsonl` where N = count of T-1696 dispatch rows in dispatches.jsonl
- [x] Append-only invariant: backprop NEVER modifies `dispatches.jsonl` (verified via SHA256 unchanged after backprop)
- [x] Read-path join: `bin/fw outcome read <dispatch_id>` returns merged row when both files contain matching entries
- [x] No-match case: backprop on a task_id with no dispatches exits 0 and writes nothing
- [x] Hook latency: backprop with no matching dispatch completes in <200ms via CLI (`time bin/fw outcome backprop ...`). NOTE: Python cold-start dominates; in-process call is <10ms per spike. Hook fires once per task completion (cold path).
- [x] update-task.sh wires the hook on `--status work-completed`
- [x] Hook is best-effort: forcing the python script to fail does NOT block task completion
- [x] `.gitignore` excludes `.context/dispatch-outcomes.jsonl`
- [x] Concurrent back-prop is safe: 10 threads × distinct task_ids; total rows in dispatch-outcomes.jsonl == sum of expected enrichments (no overwrites because append-only)
- [x] Unit tests pass: parse_task_file, default_evaluator, backprop, read-path join, append-only invariant, concurrent stress
- [x] Component fabric registered: `bin/fw fabric deps lib/outcome.py` returns a card
- [x] No regression: `bin/fw doctor` passes

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

python3 -c "import ast; ast.parse(open('lib/outcome.py').read())"
test -x lib/outcome.sh
bin/fw outcome --help
python3 -m pytest tests/unit/test_outcome.py -q
bin/fw fabric deps lib/outcome.py
grep -q "dispatch-outcomes.jsonl" .gitignore
grep -q "outcome backprop" agents/task-create/update-task.sh
bin/fw doctor

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

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-05-03T12:59:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1697-v1-outcome-enrichment--default-evaluator.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5a0dc0a0
- **Timestamp:** 2026-06-02T14:59:11Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#5 (Agent)** — `bin/fw outcome backprop T-1696` appends N rows to `.context/dispatch-outcomes.jsonl` where N = count of T-1696 dispatch rows in dispatches.jsonl
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/dispatch-outcomes.jsonl in: `bin/fw outcome backprop T-1696` appends N rows to `.context/dispatch-outcomes.jsonl` where N = count of T-1696 dispatch rows in dispatches.jsonl`
- **AC#12 (Agent)** — `.gitignore` excludes `.context/dispatch-outcomes.jsonl`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/dispatch-outcomes.jsonl in: `.gitignore` excludes `.context/dispatch-outcomes.jsonl``
### 2026-05-03T13:05:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
