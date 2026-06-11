---
id: T-1654
name: "Fix framework dispatch tag drift — agents/termlink/termlink.sh emits task=
  instead of canonical task:"
description: >
  agents/termlink/termlink.sh:86 emits --tags task=$task; canonical per T-1649 / tests/fixtures/termlink-list-schema.json
  is task:$task. Witness: 20 live sessions on this hub carry task=NUM (non-canonical);
  1 carries role= (also non-canonical, separate fix). Audit (agents/audit/orchestrator-mcp-scan.sh)
  explicitly knows task= → task: in KNOWN_DRIFT_MAP — framework produces the drift
  its own audit detects. One-line fix + regression test on the spawn primitive.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [orchestrator, arc-c, drift, termlink, framework-self-fix]
components: [agents/termlink/termlink.sh]
related_tasks: [T-1644, T-1649, T-1641]
arc_id: orchestrator-rethink
created: 2026-05-01T16:27:50Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-01T16:38:14Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 2
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=2 
      (components:substrate-edit); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1654: Fix framework dispatch tag drift — agents/termlink/termlink.sh emits task= instead of canonical task:

## Context

Framework's own dispatch primitive `agents/termlink/termlink.sh` produces non-canonical tag drift that its own audit (`agents/audit/orchestrator-mcp-scan.sh` per T-1649) explicitly catches. Live witness on this hub (2026-05-01): 20 sessions tagged `task=NUM` instead of canonical `task:NUM`. KNOWN_DRIFT_MAP at line 107 already maps `task=` → `task:`. One-line fix at `agents/termlink/termlink.sh:86`.

## Acceptance Criteria

### Agent
- [x] `agents/termlink/termlink.sh` emits canonical `task:$task` (colon, not equals) for spawn tag
- [x] No other framework code uses `task=` as a tag prefix (audit grep clean)
- [x] Regression test: `tests/unit/test_termlink_dispatch_tag_format.py` asserts `task:` is the produced prefix
- [x] Audit `orchestrator-mcp-scan.sh` against synthetic session list with canonical `task:` prefix → no warnings on that prefix
- [x] Targeted pytest passes: `python3 -m pytest tests/unit/test_termlink_dispatch_tag_format.py -q` (4/4)

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

grep -q 'task:\$task' agents/termlink/termlink.sh
! grep -nE '^[[:space:]]*[^#]*"task=\$task"' agents/termlink/termlink.sh
python3 -m pytest tests/unit/test_termlink_dispatch_tag_format.py -q

## RCA

**Symptom:** Framework's audit (`agents/audit/orchestrator-mcp-scan.sh`, T-1649) reports tag-format drift on live sessions (`task=` × 20, `role=` × 1) — and its own dispatch primitive is one of the producers.

**Root cause:** `agents/termlink/termlink.sh:86` emits `--tags "task=$task"` (equals separator). The canonical convention defined later (T-1063 / T-1649 / `tests/fixtures/termlink-list-schema.json`) is `task:` (colon). The dispatch primitive predates the convention; the convention never traced back to fix the producer.

**Why structurally allowed:** No regression test on the dispatch primitive's tag output. T-1649 added DETECTION (audit) but not PREVENTION at the source. The validator was filed as a cross-repo proposal (U-003) — not in framework code. So between proposal-filed and proposal-landed, the framework's own producer kept drifting unobserved.

**Prevention:** Unit test on the spawn-tag construction (this task's regression test). Asserts the colon form for any future caller. Survives even if `agents/termlink/termlink.sh` is refactored — pins the contract at the framework boundary.

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

### 2026-05-01T16:27:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1654-fix-framework-dispatch-tag-drift--agents.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5b953fb5
- **Timestamp:** 2026-06-02T14:58:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T16:38:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
