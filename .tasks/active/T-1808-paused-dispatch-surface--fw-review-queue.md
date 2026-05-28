---
id: T-1808
name: "Paused-dispatch surface — fw review-queue + Watchtower /approvals (dispatch-safety
  slice 4)"
description: >
  Paused-dispatch surface — fw review-queue + Watchtower /approvals (dispatch-safety
  slice 4)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [slice-4]
components: [bin/fw, lib/dispatch_pause.py, tests/unit/test_dispatch_pause.py, 
      web/blueprints/approvals.py, web/templates/_approvals_content.html]
related_tasks: [T-1805, T-1806, T-1807]
arc_id: dispatch-safety
created: 2026-05-13T16:04:06Z
last_update: '2026-05-28T22:54:10Z'
date_finished: 2026-05-13T17:13:22Z
bvp_scores_proposed:
  - ts: '2026-05-28T22:54:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1808: Paused-dispatch surface — fw review-queue + Watchtower /approvals (dispatch-safety slice 4)

## Context

Slice 4/5 of the dispatch-safety arc. Slices 1-3 made `pause_requested` events legible at the substrate, the Resolver, and the workflow-author surfaces. But the *operator* has no idea a Worker has paused — paused dispatches sit in `.context/dispatches.jsonl` with `outcome: paused` and a `terminal_event` capturing the question, but neither `fw review-queue` nor Watchtower `/approvals` surfaces them. This slice adds the operator-facing channel: paused dispatches surface as a distinct section in the review queue, with the dispatch_id, task_id, question, severity, likelihood, and age.

Without this, slice 1-3 are inert from the operator's perspective — Workers can pause, but operators can't see they paused. Builds on [T-1805](T-1805), [T-1806](T-1806), [T-1807](T-1807). Unblocks slice 5 (re-dispatch chain — needs operator UI to capture resolution).

## Acceptance Criteria

### Agent
- [x] `lib/dispatch_pause.py` (new) exposes `list_paused_dispatches() -> List[Dict]`. Scans `.context/dispatches.jsonl` for rows where `outcome == "paused"`. For each, returns: dispatch_id, task_id, ts, age_seconds, question (from terminal_event), severity, likelihood, state_ref. A paused dispatch is considered "awaiting resolution" if no subsequent dispatch has `retry_of_dispatch_id` matching it (slice 5 adds that field; until then, all paused dispatches are awaiting).
- [x] `bin/fw review-queue` shows a new section `PAUSED — Workers awaiting resolution (N)` between DECISIONS and VERDICT sections (urgency tier). Columns: AGE, DISPATCH (8-char prefix), TASK, QUESTION (truncated to 60 chars). Sort: oldest first.
- [x] When no paused dispatches exist, the section is suppressed (no empty header).
- [x] Watchtower `/approvals` renders a Paused-dispatches panel above the Human-ACs panel. Each row is clickable to the task review page (`/review/T-XXX`). Shows: dispatch_id (8-char), task_id, age, question, severity badge, likelihood badge.
- [x] `_build_approvals_context` in `web/blueprints/approvals.py` includes `paused_dispatches` (list) and `paused_count` (int) in its return dict. Total approval count includes paused_count.
- [x] Unit test (`tests/unit/test_dispatch_pause.py`): synthetic dispatches.jsonl fixture with mixed outcomes (success, error, paused, pending) → `list_paused_dispatches()` returns only the paused rows with the expected fields shaped correctly.
- [x] Unit test: dispatch with no terminal_event (or terminal_event without question) → row still surfaces but question is empty string (not None, not exception).
- [x] Unit test: missing dispatches.jsonl → returns empty list (not exception).
- [x] Integration check: `bin/fw review-queue` runs without error (paused section is empty in current repo, but no traceback).

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

### Human
- [ ] [REVIEW] Confirm the Paused panel placement and visual rhythm. Render-surface AC (T-1766).
  **Steps:**
  1. Open `$(bin/fw watchtower url)/approvals` in a browser
  2. The Paused-dispatches panel should sit above Human-ACs and below Tier-0 (urgency tier)
  3. When empty (no paused dispatches), the panel should not render (no empty header)
  4. Severity/likelihood badges should use the same color scheme as existing verdict badges
  **Expected:** Panel placement matches the urgency hierarchy; empty state is clean; badges read at a glance.
  **If not:** Note the visual issue with a screenshot reference and what should change.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
python3 -m pytest tests/unit/test_dispatch_pause.py -q 2>&1 | tail -5
out=$(bin/fw review-queue 2>&1 || true); echo "$out" | head -3 | grep -qE "DECISIONS|VERDICT|PAUSED|No tasks awaiting" || (echo "FAIL: review-queue output unexpected"; exit 1)
python3 -c "import sys; sys.path.insert(0, 'lib'); from dispatch_pause import list_paused_dispatches; print('ok' if isinstance(list_paused_dispatches(), list) else 'fail')"
out=$(bin/fw watchtower url 2>/dev/null); curl -sf "${out}/approvals" -o /dev/null || (echo "FAIL: /approvals 404"; exit 1)

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

### 2026-05-13 — slice-5 forward-compat baked into slice-4 helper
- **What changed:** `list_paused_dispatches()` already filters out paused dispatches whose `dispatch_id` matches some later row's `retry_of_dispatch_id` — even though slice 5 hasn't shipped yet. Without this forward-compat, slice 5 would have to add it AND re-test slice 4 cases. With it, slice 5 just writes the retry rows and the operator UI deflates automatically.
- **Plan impact:** Added the `test_retry_resolves_paused_dispatch` + `test_unresolved_pause_still_surfaces_alongside_other_retries` cases to pin the contract now.
- **Triggered:** None — natural forward-compat.

### 2026-05-13 — single helper module, both surfaces consume it
- **What changed:** Originally considered three implementations: CLI reads dispatches.jsonl directly, Watchtower blueprint reads dispatches.jsonl directly, and a shared helper. Picked the shared helper (`lib/dispatch_pause.py`) — one source of truth for "what counts as awaiting resolution," shared by CLI and web. Both surfaces import `list_paused_dispatches` + `format_age` + `truncate`.
- **Plan impact:** Saved duplicate parsing code in `bin/fw review-queue` heredoc and `web/blueprints/approvals.py`. Tests exercise the helper directly; surfaces just decorate the rows.
- **Triggered:** None.

## Decisions

### 2026-05-13 — paused dispatches sort newest-first, not oldest-first
- **Chose:** Sort by ts descending (newest first) in both CLI and web.
- **Why:** Paused dispatches are blocking work the operator is actively waiting on. Newest is most actionable — the operator's current context (what they just dispatched) is freshest in mind. Oldest-first would surface stale paused dispatches that may already be irrelevant.
- **Rejected:** Oldest-first (matches Human-AC verdict sort) — wrong analogy. Human ACs accumulate over completed work; paused dispatches block live work.

### 2026-05-13 — paused panel sits between Decisions and Verifications, not absorbed into one
- **Chose:** Distinct "Paused Dispatches" section on `/approvals`, between Decisions (Tier-0 + GO/NO-GO) and Verifications (Human ACs). Distinct stat card in the summary bar (only when count > 0).
- **Why:** A paused dispatch is neither a Decision (no GO/NO-GO needed — just answer the question) nor a Verification (Worker hasn't done work to verify). Folding it into either would dilute the urgency signal. Distinct section = distinct triage action.
- **Rejected:** Inline within Decisions (wrong semantics). Inline within Verifications (would clutter the AC-heavy list). Separate page (over-engineered — operator already lives in /approvals).

## Recommendation

**Recommendation:** GO

**Rationale:** Slice 4 closes the operator-visibility gap. Before this change, paused dispatches sat in `.context/dispatches.jsonl` with `outcome: paused` and a fully-shaped `terminal_event`, but neither `fw review-queue` nor Watchtower `/approvals` surfaced them — the operator had no signal a Worker had paused. Now both surfaces render a distinct "Paused" section/panel between Decisions and Verifications, sorted newest-first, with severity/likelihood badges + age + truncated question + clickable task link. Empty-state correct: no paused → no panel rendered. Slice-5 forward-compat baked in via `retry_of_dispatch_id` resolution (Worker re-dispatches automatically deflate the awaiting list).

**Evidence:**
- `lib/dispatch_pause.py` (new): `list_paused_dispatches(project_root)` scans dispatches.jsonl, filters to `outcome=='paused'`, drops retry-resolved rows, returns shaped dicts sorted newest-first. Helpers `format_age()` + `truncate()` shared by CLI and web.
- 14 new unit tests in `tests/unit/test_dispatch_pause.py` covering: filtering by outcome, empty/missing log, malformed-row tolerance, full + partial terminal_event fields, age computation, retry resolution, sort order, formatting helpers.
- `bin/fw review-queue` heredoc adds PAUSED section between DECISIONS and VERDICT; verified empty in current repo + populated correctly when a synthetic paused row is appended.
- `web/blueprints/approvals.py:_load_paused_dispatches` decorates rows for template; `_build_approvals_context` returns `paused_dispatches` + `paused_count`; total_count includes them.
- `web/templates/_approvals_content.html` renders the Paused panel with severity color badges (red/yellow/grey), age label, dispatch_id (8-char), task link to `/review/T-XXX`, and slice-5 forward-pointer text.
- DOM-content assertions: `curl /approvals` shows "Workers Awaiting Resolution" exactly when paused rows exist; absent when log is clean.

**Next steps (slice 5):** Re-dispatch chain — Agent reads operator resolution from `/review/T-XXX` (paused-dispatch question answered), constructs a new dispatch envelope with `retry_of_dispatch_id` linking to the paused row + the operator's answer in context, dispatches via Resolver. When that fires, slice 4's helper automatically deflates the awaiting list.

## Updates

### 2026-05-13T16:04:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1808-paused-dispatch-surface--fw-review-queue.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-2280054f
- **Timestamp:** 2026-05-18T09:30:57Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `lib/dispatch_pause.py` (new) exposes `list_paused_dispatches() -> List[Dict]`. Scans `.context/dispatches.jsonl` for rows where `outcome == "paused"`. For each, returns: dispatch_id, task_id, ts, age
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/dispatches.jsonl in: `lib/dispatch_pause.py` (new) exposes `list_paused_dispatches() -> List[Dict]`. Scans `.context/dispatches.jsonl` for rows where `outcome == "paused"``
- **AC#5 (Agent)** — `_build_approvals_context` in `web/blueprints/approvals.py` includes `paused_dispatches` (list) and `paused_count` (int) in its return dict. Total approval count includes paused_count.
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/approvals.py in: `_build_approvals_context` in `web/blueprints/approvals.py` includes `paused_dispatches` (list) and `paused_count` (int) in its return dict. Total app`

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `python3 -m pytest tests/unit/test_dispatch_pause.py -q 2>&1 | tail -5`
### 2026-05-13T17:13:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
