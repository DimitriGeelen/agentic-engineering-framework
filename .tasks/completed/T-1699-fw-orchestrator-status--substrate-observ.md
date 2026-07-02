---
id: T-1699
name: "fw orchestrator status — substrate observability (dispatch counts + enrichment
  ratio)"
description: >
  fw orchestrator status — substrate observability (dispatch counts + enrichment ratio)

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw, lib/resolver.py, tests/unit/test_resolver.py]
related_tasks: []
created: 2026-05-03T13:11:47Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-03T13:14:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
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

# T-1699: fw orchestrator status — substrate observability (dispatch counts + enrichment ratio)

## Context

T-1696 (Resolver) + T-1697 (Outcome) + T-1698 (hook fix) shipped the v1
dispatch substrate end-to-end. There's no operator-facing summary of how
much data the substrate has captured — operators only see individual rows
via `fw resolver explain` / `fw outcome read`.

Add `fw orchestrator status` that reports:
- Total dispatches in `dispatches.jsonl`
- Total outcome events in `dispatch-outcomes.jsonl`
- Enrichment ratio (% of dispatches with at least one outcome event)
- Top 5 task_types by dispatch volume
- Worker_kind breakdown (Task / TermLink / pi)
- Last N dispatches with their outcome status

Rationale: this is the first thing an operator wants when checking the
substrate is alive. Currently `fw orchestrator` only has the `improve`
v2 stub; v1 deserves a status verb too.

## Acceptance Criteria

### Agent
- [x] `fw orchestrator status` exits 0 and prints a multi-section summary
- [x] `fw orchestrator status --json` emits structured JSON
- [x] Output includes: dispatch_total, outcome_total, enrichment_ratio, by_task_type, by_worker_kind, recent (last 5)
- [x] Empty state: when neither file exists, prints "no dispatches captured yet" and exits 0 (not an error — fresh project)
- [x] CLAUDE.md Quick Reference updated to mention `fw orchestrator status`
- [x] No regression: bin/fw doctor exit 0
- [x] `fw orchestrator --help` lists `status` alongside `improve`

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

bin/fw orchestrator status >/dev/null
bin/fw orchestrator status --json | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'dispatch_total' in d and 'enrichment_ratio' in d"
bin/fw orchestrator --help | grep -q status
grep -q "orchestrator status" CLAUDE.md
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

### 2026-05-03T13:11:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1699-fw-orchestrator-status--substrate-observ.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-498bd96f
- **Timestamp:** 2026-06-02T14:59:12Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 1
     - evidence: `bin/fw orchestrator status >/dev/null`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `bin/fw orchestrator --help | grep -q status`
### 2026-05-03T13:14:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
