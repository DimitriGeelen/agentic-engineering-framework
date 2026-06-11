---
id: T-1664
name: "Framework dispatch path: populate model_used + fallback_used in meta.json —
  close Q1 substrate-half mirror of /opt/termlink T-1442"
description: >
  Framework dispatch path: populate model_used + fallback_used in meta.json — close
  Q1 substrate-half mirror of /opt/termlink T-1442

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/termlink/termlink.sh, 
      tests/unit/test_termlink_dispatch_task_type.py]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-01T21:36:07Z
last_update: '2026-06-11T22:23:55Z'
date_finished: 2026-05-01T21:39:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=1 
      (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1664: Framework dispatch path: populate model_used + fallback_used in meta.json — close Q1 substrate-half mirror of /opt/termlink T-1442

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `_resolve_dispatch_model_and_fallback` helper added in `agents/termlink/termlink.sh` returning `<model>|<fallback_used>` (mirrors /opt/termlink T-1442 semantics).
- [x] `cmd_dispatch` writes resolved `model_used` (string) and `fallback_used` (bool) into meta.json instead of nulls when resolution succeeds; both stay null when resolution returns empty.
- [x] Existing `_resolve_dispatch_model` remains for backward-compat (returns model only).
- [x] Test pin in `tests/unit/test_termlink_dispatch_task_type.py` covers the four resolution branches (explicit / per-type / default / none) producing the expected `(model_used, fallback_used)` pairs.
- [x] `python3 -m pytest tests/unit/test_termlink_dispatch_task_type.py -q` passes.
- [x] `bash -n agents/termlink/termlink.sh` clean.
- [x] Smoke dispatch: meta.json populated correctly for at least one resolution path (verified end-to-end).

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

bash -n agents/termlink/termlink.sh
grep -q '_resolve_dispatch_model_and_fallback' agents/termlink/termlink.sh
grep -q '\$model_used_json' agents/termlink/termlink.sh
python3 -m pytest tests/unit/test_termlink_dispatch_task_type.py -q

## Recommendation

**Recommendation:** GO

**Rationale:** The framework dispatch path (`bin/fw termlink dispatch`) now mirrors /opt/termlink T-1442's resolution semantics — `_resolve_dispatch_model_and_fallback` returns `<model>|<fallback_used>` and `cmd_dispatch` writes the resolved values into meta.json at dispatch time instead of always-null. Closes Q1 substrate-half on the framework path: dispatches that resolve a model now carry that fact in meta.json, the Watchtower /orchestrator "Recent dispatches" panel will render real values instead of n/a, and the audit detective can read the same evidence the human can.

**Evidence:**
- Smoke dispatch `t1664-smoke3` (FW_DISPATCH_MODEL_DEFAULT=sonnet, no --model): meta.json shows `model_used: "sonnet", fallback_used: true` ✓
- Smoke dispatch `t1664-explicit` (--model haiku): meta.json shows `model_used: "haiku", fallback_used: false` ✓
- 16/16 dispatch unit tests pass (5 new for `_resolve_dispatch_model_and_fallback` branches)
- `bash -n agents/termlink/termlink.sh` clean
- All four resolution branches pinned: explicit/per-type/default/none → `(model_used, fallback_used)` tuples match expected

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

### 2026-05-01T21:36:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1664-framework-dispatch-path-populate-modelus.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3ac5d3d2
- **Timestamp:** 2026-06-02T14:58:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_termlink_dispatch_task_type.py -q`
### 2026-05-01T21:39:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-02T05:17:14Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
