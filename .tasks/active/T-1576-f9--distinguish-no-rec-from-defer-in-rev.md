---
id: T-1576
name: "F9 — Distinguish NO-REC from DEFER in review-queue and /approvals (build-task gap parallel to T-1570)"
description: >
  extract_recommendation_verdict returns '?' for both 'no ## Recommendation section' and 'section exists but verdict missing'. fw review-queue and /approvals render both as [?], blending 'agent owes a recommendation' with 'deferred verdict'. Surface as [NO-REC] (or similar) so agent knows to write one; human knows not to act yet. Parallel to T-1570 which fixed inception side.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-28T09:07:46Z
last_update: 2026-04-28T09:07:46Z
date_finished: null
---

# T-1576: F9 — Distinguish NO-REC from DEFER in review-queue and /approvals (build-task gap parallel to T-1570)

## Context

`bin/fw review-queue` and Watchtower `/approvals` blend two distinct states behind the same `[?]` verdict marker: (a) tasks where the agent never wrote a `## Recommendation` section at all (NO-REC — agent owes a recommendation, human cannot act), and (b) tasks where the section exists but the verdict line is missing/unparseable (truly unknown). Both render identically.

Concrete impact: 12 tasks in the current review-queue show `[?]` verdict — at least T-1062, T-801, T-802, T-803, T-967 etc. have no `## Recommendation` section. The human sees them in the queue but has nothing to act on; the agent doesn't see "write a recommendation" called out.

Parallel to T-1570 (F4) which surfaced the same gap on the inception side of `/approvals`. This is the build/partial-complete side.

## Acceptance Criteria

### Agent
- [x] `web/shared.py` exposes `extract_recommendation_state(body) -> str` returning `'GO'|'NO-GO'|'DEFER'|'NO-REC'|'?'` — discriminates "no section" from "verdict unparseable"
- [x] Existing `extract_recommendation_verdict` retained as compatibility shim (returns `?` for both NO-REC and unparseable, like before)
- [x] `bin/fw review-queue` uses `extract_recommendation_state`; renders `NO-REC` distinct from `?` (own color, sort priority right after `?`)
- [x] `agents/handover/handover.sh` "Awaiting Your Action" prefix uses state — surfaces `[NO-REC]` instead of `[?]` for tasks missing recommendation
- [x] `web/blueprints/approvals.py` `_load_pending_human_acs` exposes both `verdict` (compat) and `state`; template renders NO-REC badge distinctly
- [x] Unit test in `tests/unit/test_extract_recommendation.py` covers: empty body → NO-REC, no section → NO-REC, section with no verdict line → ?, full block → GO/NO-GO/DEFER
- [x] `bin/fw test unit -- tests/unit/test_extract_recommendation.py` passes
- [x] `bin/fw review-queue` output on current repo shows `NO-REC` rows for T-1062, T-801, etc. (was `?`)

### Human
- [ ] [REVIEW] /approvals "Awaiting Human ACs" cards visually distinguish NO-REC from DEFER/?
  **Steps:**
  1. Open the queue page (URL emitted by `bin/fw watchtower url`)/approvals
  2. Find a card whose verdict shows the new NO-REC indicator
  3. Confirm it reads "Agent owes a recommendation" / "Not ready for review" rather than "Verdict deferred"
  **Expected:** Clear distinction — NO-REC tasks look different from real DEFER decisions
  **If not:** Screenshot the card; note which marker is ambiguous

## Verification

bin/fw test unit -- tests/unit/test_extract_recommendation.py
bin/fw review-queue 2>&1 | grep -qE 'NO-REC' && echo "NO-REC rendered" || echo "NO-REC missing"

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

### 2026-04-28T09:07:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1576-f9--distinguish-no-rec-from-defer-in-rev.md
- **Context:** Initial task creation
