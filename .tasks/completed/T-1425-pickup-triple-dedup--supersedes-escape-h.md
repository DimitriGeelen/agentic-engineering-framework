---
id: T-1425
name: "pickup triple-dedup + supersedes escape hatch (T-1420 B1+B2+B4)"
description: >
  T-1420 GO authorized triple dedup in lib/pickup.sh. Add second-pass dedup keyed
  on (source_project, source_task_id, type) after the hash check; route matches to
  auto-deferred/ with a breadcrumb. Honor supersedes: T-XXX in the envelope as an
  explicit bypass. Regression test covers triple-collision auto-defer path.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-24T13:08:37Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-24T13:12:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1425: pickup triple-dedup + supersedes escape hatch (T-1420 B1+B2+B4)

## Context

T-1420 GO authorized on 2026-04-24 (Watchtower): add a second-pass triple dedup `(source_project, source_task_id, type)` in `lib/pickup.sh` after the existing envelope-hash dedup. The hash dedup normalizes `(type | summary | source_project)` — misses retries of the same logical concern with drifted bytes (6 duplicate pairs this week). Triple dedup catches those while the hash stays as the fast path. `supersedes: T-XXX` in the envelope bypasses triple dedup (explicit intent — recovery lane for legitimate follow-ups). Route triple-collision matches to `.context/pickup/auto-deferred/` with a breadcrumb pointing at the blocking local task. G-059 in `.context/project/concerns.yaml` tracks the fix.

## Acceptance Criteria

### Agent
- [x] `pickup_dedup_triple_check` helper finds an existing active inception task with matching `source_task_id_in_origin` + `source_project_in_origin` (requires non-empty source_task_id — empty task_id falls through to hash-only per Spike A finding)
- [x] `pickup_process_one` calls triple check AFTER hash dedup AND after the G-046 self-completed check; on match, route to `auto-deferred/` with a `.breadcrumb` sibling pointing at the blocking local T-XXX
- [x] `supersedes: T-XXX` field in an envelope's top-level YAML bypasses the triple check (explicit override)
- [x] Regression test in `tests/unit/lib_pickup_triple_dedup.bats` covers: triple-collision auto-defer, supersedes bypass, empty-task_id fall-through, no-collision happy path — 7/7 pass; type-mismatch no-collision also covered
- [x] Vendored copy in `.agentic-framework/lib/pickup.sh` stays in sync with the framework copy

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

bash -n lib/pickup.sh
grep -q 'pickup_dedup_triple_check' lib/pickup.sh
grep -q 'supersedes:' lib/pickup.sh
bats tests/unit/lib_pickup_triple_dedup.bats
diff -q lib/pickup.sh .agentic-framework/lib/pickup.sh

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

### 2026-04-24T13:08:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1425-pickup-triple-dedup--supersedes-escape-h.md
- **Context:** Initial task creation

### 2026-04-24T13:12:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d66a1de6
- **Timestamp:** 2026-06-02T14:57:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
