---
id: T-1589
name: "T-1068 invariant: preserve started-work when shipping evidence present (skip
  auto-demote)"
description: >
  T-1068 invariant: preserve started-work when shipping evidence present (skip auto-demote)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-28T17:36:56Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-04-28T18:06:13Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1589: T-1068 invariant: preserve started-work when shipping evidence present (skip auto-demote)

## Context

T-1068's auto-demote (`agents/task-create/update-task.sh:778-787`) demotes a `started-work` task to `captured` whenever horizon is moved to `next`/`later`. The intent: shelving a task means you stopped working on it. The bug: tasks that have already shipped (all Agent ACs checked + `## Recommendation` block written) get demoted too — masking shipped work from the review queue. Found 7 stuck tasks during this session's backlog sweep (T-1064/1065/1066 + T-334/T-464/T-544/T-967). Each had agent-side completion evidence in the body but appeared as `captured` in the queue.

Fix: skip the auto-demote when shipping evidence is present. The task is past started-work — it's awaiting human review, not shelved.

## Acceptance Criteria

### Agent
- [x] `agents/task-create/update-task.sh` T-1068 auto-demote block (lines 778-787) skips the demotion when (a) `## Recommendation:` line exists in the task body AND (b) zero unchecked `- [ ]` ACs remain under `### Agent` section
- [x] When skipped, prints a CYAN status line crediting T-1589 ("preserved at started-work — shipping evidence")
- [x] When NOT skipped (no shipping evidence), behaviour unchanged — same demotion, same message
- [x] Bats regression test: shipping-evidence task moved to horizon=next preserves started-work
- [x] Bats regression test: empty-body task moved to horizon=next still demotes to captured
- [x] Existing T-1068 tests continue to pass — 19/19 pass in `tests/unit/update_task.bats`

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

bash -n agents/task-create/update-task.sh
bats tests/unit/update_task.bats >/tmp/T-1589-bats.log 2>&1
! grep -qE "^not ok" /tmp/T-1589-bats.log

## RCA

**Symptom:** During this session's backlog sweep, 7 tasks (T-1064/1065/1066 + T-334/T-464/T-544/T-967) were found at `status: captured` despite having all Agent ACs checked + a `## Recommendation` block. They were invisible to the review queue (`/approvals`, `fw review-queue`) and to the handover's "Awaiting Human Review" list.

**Root cause:** T-1068's horizon-update auto-demote in `agents/task-create/update-task.sh:778-787` demotes any `started-work` task to `captured` when its horizon is moved to `next`/`later`, regardless of whether the agent has already shipped (Agent ACs checked + Recommendation written). Tasks legitimately moved to "shelve for later" hit the same path as tasks moved to "park for human review later".

**Why structurally allowed:** T-1068's "shelving means you stopped" assumption holds for in-progress tasks but not for shipped-pending-review tasks. No structural distinction between the two states existed. The status field collapsed to "captured" for both, and the body content (which carries the shipping evidence) wasn't consulted.

**Prevention:** T-1589 inverts the assumption when shipping evidence is present. Bats tests pin both branches (preserve vs demote). Future auto-demote regressions caught immediately. Origin learning captured during T-1542 sweep.

## Decisions

### 2026-04-28 — Detection signal: Recommendation + zero unchecked Agent ACs
- **Chose:** Use the presence of `**Recommendation:**` (case-sensitive marker line) AND zero `- [ ]` lines in the `### Agent ... ### Human|## ` block range as the shipping-evidence test.
- **Why:** These two signals together prove the agent finished its side: `## Recommendation` is the structural "I'm done, here's my call" marker (mandated by CLAUDE.md presenting-work-for-review rules); zero unchecked Agent ACs proves all agent work passed. Either alone is too weak (Recommendation might exist as DEFER on a task with unchecked ACs; zero unchecked ACs might be a fresh task with no recommendation written yet).
- **Rejected:** Use `partial-complete` status as the trigger — but tasks at `started-work + horizon=next` aren't in partial-complete state, they're in shipped-but-unreviewed state. Different concept.
- **Rejected:** Auto-promote to `partial-complete` instead of preserving `started-work` — that would change established status semantics; preserving is the minimal-blast-radius fix.

### 2026-04-28 — grep -c exit-code handling
- **Chose:** `_var=$(... | grep -c PATTERN) || _var=0` to handle grep's non-zero exit on zero matches.
- **Why:** Initial implementation used `grep -c ... || echo 0` which produced `"0\n0"` (grep printed 0 + echo printed 0), making equality checks fail.
- **Rejected:** `grep -c | head -1` — works but obscure.

## Updates

### 2026-04-28T17:36:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1589-t-1068-invariant-preserve-started-work-w.md
- **Context:** Initial task creation

### 2026-04-28 — fix shipped + bats coverage
- **Action:** Added shipping-evidence guard in `agents/task-create/update-task.sh:786-800`. 4 new bats tests in `tests/unit/update_task.bats` (preserved-on-next, preserved-on-later, no-rec-still-demotes, partial-still-demotes). 19/19 update_task tests pass.
- **Output:** `agents/task-create/update-task.sh` (+12 lines), `tests/unit/update_task.bats` (+74 lines)

## Recommendation

**Recommendation:** GO

**Rationale:** The 7-task drift sweep proves the bug is real and recurring. Fix is structural, minimal blast radius (12-line guard inside the existing T-1068 demote block), and pinned by 4 bats tests covering both branches (preserve when shipped, demote otherwise). Existing 12 tests still pass. Future auto-demote regression on shipped tasks now catches immediately. RCA captured for the bug-class gate.

**Evidence:**
- `agents/task-create/update-task.sh:786-800`: shipping-evidence guard fires only when `_has_rec >= 1` AND `_agent_unchecked == 0`
- `tests/unit/update_task.bats` lines 134-208: 4 new tests covering positive (next + later) and negative (no rec, partial) cases
- `bats tests/unit/update_task.bats --tap` → 19/19 pass (12 existing + 4 new T-1589 + 3 unrelated)
- L-318-class learning captured: "Captured-but-done drift" pattern documented for future detection

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4c03d0a8
- **Timestamp:** 2026-06-02T14:58:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-28T18:06:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
