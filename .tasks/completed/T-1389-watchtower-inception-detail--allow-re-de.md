---
id: T-1389
name: "Watchtower inception detail — allow re-decide after decision recorded (T-1388
  B2)"
description: >
  Watchtower inception detail — allow re-decide after decision recorded (T-1388 B2)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/playwright/test_inception.py, 
      web/templates/inception_detail.html]
related_tasks: []
created: 2026-04-22T22:05:46Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-22T22:16:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1389: Watchtower inception detail — allow re-decide after decision recorded (T-1388 B2)

## Context

B2 from T-1388 inception (GO, S-broad scope). Closes G-057. Fixes F1: `/inception/T-XXX` UI is one-shot — no revoke/re-decide affordance after decision recorded.

Backend (`lib/inception.sh do_inception_decide`) is already idempotent thanks to T-1262 — it replaces the canonical `## Decision` block on re-invoke and appends a new entry to `## Updates`. Only the **template** (`web/templates/inception_detail.html:306-326`) hides the form after decision. Fix is template-only.

## Acceptance Criteria

### Agent
- [x] `/inception/T-XXX` shows "Record Superseding Decision" form when task has a recorded GO/NO-GO/DEFER decision (verified via Playwright + live screenshot evidence)
- [x] `/inception/T-XXX` still shows "Record Decision" form when task is pending (no regression)
- [x] Superseding form has correct `action="/inception/{task_id}/decide"` + radio buttons for GO/NO-GO/DEFER + context note explaining replacement semantics
- [x] Canonical `## Decision` block idempotency already guaranteed by T-1262 backend logic (`lib/inception.sh:343-378`) — no template change risks regressing this
- [x] Playwright test in `tests/playwright/test_inception.py::TestRedecideAffordance` (3 tests) guards the re-decide affordance; sanity-inverse verified (reverting fix fails 2/3 tests)

### Human
- [x] No human AC needed — fully agent-verifiable via Playwright

## Verification

# Template: conditional should use task._location == 'active' (not dec == 'pending')
grep -q "task._location == 'active'" web/templates/inception_detail.html
# Removed the pending-only guard on the form block
! grep -q "elif dec == 'pending' and task._location == 'active'" web/templates/inception_detail.html
# Playwright test exists
test -f tests/playwright/test_inception.py
# Playwright regression passes
cd /opt/999-Agentic-Engineering-Framework && fw test playwright -- tests/playwright/test_inception.py -v 2>&1 | tail -5 | grep -E "passed|PASSED"

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

### 2026-04-22T22:05:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1389-watchtower-inception-detail--allow-re-de.md
- **Context:** Initial task creation

### 2026-04-22T22:16:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d8b626df
- **Timestamp:** 2026-06-02T14:57:08Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — Canonical `## Decision` block idempotency already guaranteed by T-1262 backend logic (`lib/inception.sh:343-378`) — no template change risks regressing this
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/inception.sh in: Canonical `## Decision` block idempotency already guaranteed by T-1262 backend logic (`lib/inception.sh:343-378`) — no template change risks regressin`
