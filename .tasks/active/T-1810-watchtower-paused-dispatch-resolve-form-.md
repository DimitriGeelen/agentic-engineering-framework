---
id: T-1810
name: "Watchtower paused-dispatch resolve form on /review/T-XXX — web parity for fw
  pause resolve"
description: >
  Watchtower paused-dispatch resolve form on /review/T-XXX — web parity for fw pause
  resolve

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [watchtower, ui]
components: [lib/dispatch_pause.py, tests/unit/test_review_paused_resolve.py, 
      web/blueprints/review.py, web/templates/review.html]
related_tasks: [T-1808, T-1809]
arc_id: dispatch-safety
created: 2026-05-13T17:41:04Z
last_update: '2026-08-16T22:24:00Z'
date_finished: 2026-05-13T17:47:22Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 0
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=0 (no-signal); D4=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:00Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 3
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=3 
      (body:component-silent-failure); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1810: Watchtower paused-dispatch resolve form on /review/T-XXX — web parity for fw pause resolve

## Context

Dispatch-safety arc slice 4 (T-1808) added the paused-dispatch panel to `/approvals` (cross-task view). Slice 5 (T-1809) added the CLI `fw pause resolve <id> --answer "..."`. This task adds **web parity** by:

1. Showing paused dispatches *for the task* on `/review/T-XXX` (filtered, in-context)
2. Inline form per row (textarea for operator's answer) that POSTs to a new endpoint
3. Endpoint calls `lib/pause_resolve.resolve_pause()` and redirects back to /review

Closes the headline-mechanic loop end-to-end via Watchtower: pause → see in /approvals OR /review/T-XXX → answer in browser → new dispatch fires → paused row deflates from queue (slice 4's `retry_of_dispatch_id` deflation already works).

## Acceptance Criteria

### Agent
- [x] `web/blueprints/tasks.py` review handler loads paused dispatches filtered by `task_id` (helper added to `lib/dispatch_pause.py` or filter inline)
- [x] `/review/T-XXX` renders a "Paused Dispatches" panel ONLY when there are paused rows for that task — empty state hidden when none
- [x] Each paused row shows: dispatch_id (short), age, severity badge, question, and an inline textarea + Submit button
- [x] New POST endpoint `/review/T-XXX/pause/<dispatch_id>/resolve` accepts `answer` form field, calls `pause_resolve.resolve_pause()`, redirects back to `/review/T-XXX`
- [x] Empty/whitespace answer → 400 with error message rendered on page (no silent failure)
- [x] Not-paused / already-resolved dispatch → endpoint returns 4xx with the `PauseResolveError` message (no 500)
- [x] Unit test: filter helper returns only rows for given task_id, drops retry-resolved rows
- [x] Integration test (Flask test client): GET /review/T-XXX shows panel when paused row exists; POST resolve creates new dispatch; second GET shows panel deflated
- [x] Tests pass: `python3 -m pytest tests/unit/test_review_paused_resolve.py -q`

### Human
- [ ] [REVIEW] Form renders cleanly inside review page rhythm
  **Steps:**
  1. Append a synthetic paused row to `.context/dispatches.jsonl` (or wait for a real one)
  2. Open http://192.168.10.107:3000/review/T-9999 (or whichever task_id you used)
  3. Verify the Paused panel renders inline, with severity color, age, and a usable textarea
  4. Submit a test answer and verify redirect + deflation
  **Expected:** Panel sits naturally between Recommendation and Verifications; submit triggers redirect; row disappears on reload
  **If not:** Note the visual issue or layout break

## Verification

python3 -m pytest tests/unit/test_review_paused_resolve.py -q
python3 -c "import ast; ast.parse(open('web/blueprints/tasks.py').read())"
python3 -c "import sys; sys.path.insert(0,'lib'); from dispatch_pause import list_paused_dispatches_for_task" 2>/dev/null || python3 -c "import sys; sys.path.insert(0,'lib'); from dispatch_pause import list_paused_dispatches"

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

### 2026-05-13 — CSRF handling

- **What changed:** First test pass returned 403 on all POSTs — the app's `csrf_protect` `before_request` rejects state-changing requests without `_csrf_token` form field or `X-CSRF-Token` header.
- **Plan impact:** Template needed `<input type="hidden" name="_csrf_token" value="{{ csrf_token() }}">`; tests needed a `session_transaction` seed + `_post` helper that injects the token.
- **Triggered:** No sub-tasks — CSRF is the standard pattern (every state-mutating form in Watchtower already does this). Test helper documents the pattern for future similar endpoints.

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

**Recommendation:** GO

**Rationale:** Web parity for `fw pause resolve` is the smallest follow-up to the dispatch-safety arc that closes the operator-facing loop entirely in Watchtower. Before this change, an operator who spotted a paused dispatch on `/approvals` (T-1808) had to switch contexts to a terminal and run `fw pause resolve <id> --answer "..."`. With this change, the answer happens in the same tab as the review. Slice-5 forward-compat baked into T-1808's filter helper (`retry_of_dispatch_id` deflation) means the row disappears automatically on the next page load — no extra UI state to manage.

The endpoint piggybacks on `lib/pause_resolve.resolve_pause()` (slice 5), so the failure modes (not-paused, already-resolved, unknown id, empty answer) are pinned by the existing test suite *plus* the new endpoint-level redirects-with-error tests. CSRF protection is enforced via the standard `{{ csrf_token() }}` hidden field pattern (no new auth surface).

**Evidence:**
- All 10 new tests pass: `python3 -m pytest tests/unit/test_review_paused_resolve.py -q` (4 filter, 2 GET render, 4 POST endpoint)
- Regression sweep clean: 86 tests pass across `test_review_paused_resolve.py + test_pause_resolve.py + test_dispatch_pause.py + test_workflow_schema_pause_lint.py + test_resolver.py`
- Live DOM verification on Watchtower (per T-1575): synthetic paused row + `curl -s /review/T-1810` shows heading "Paused Dispatches", severity badge "MED", truncated question text, `action="/review/T-1810/pause/demo-T1810-aabbccdd/resolve"`, and button text "Resolve & re-dispatch". Panel hides cleanly when no paused rows exist.
- Arc headline mechanic now demonstrable end-to-end via Watchtower: pause → see on `/approvals` AND `/review/T-XXX` → submit answer in browser → 303 redirect with `?resolved=<short_id>` flash → new dispatch fires with `retry_of_dispatch_id` → paused row deflates on next page load.

**Next steps (not in this task):**
1. Watchtower `/approvals` could grow the same inline form (currently CLI-only there too — but a less common entry point than `/review/T-XXX` which is the QR-target).
2. After real-world load: revisit T-1804 inception (cross-agent peer-consult substrate) — currently DEFER pending pause-rate evidence.

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

### 2026-05-13T17:41:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1810-watchtower-paused-dispatch-resolve-form-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-39006a91
- **Timestamp:** 2026-06-11T11:49:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_review_paused_resolve.py -q`
### 2026-05-13T17:47:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
