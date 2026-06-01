---
id: T-1470
name: "Symptom A fix — Watchtower /inception/decide returns 200 with warning on auto-trigger failure (not 500)"
description: >
  Symptom A fix — Watchtower /inception/decide returns 200 with warning on auto-trigger failure (not 500)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/web/test_inception_decide_hardening.py, web/blueprints/inception.py]
related_tasks: []
created: 2026-04-25T19:28:15Z
last_update: 2026-04-25T19:31:27Z
date_finished: 2026-04-25T19:31:27Z
---

# T-1470: Symptom A fix — Watchtower /inception/decide returns 200 with warning on auto-trigger failure (not 500)

## Context

T-1444 inception GO, Symptom A branch.

`web/blueprints/inception.py:497-528` calls `fw inception decide` and returns 500/redirect-with-error whenever exit code is non-zero. But `fw inception decide` runs side-effects (status update, file move, episodic generation, review emit) AFTER the primary decision is recorded. If a side-effect fails, the exit code propagates non-zero even though the primary decision landed cleanly.

User-visible symptom on T-1455 GO (2026-04-25T07:22Z): clicked GO, decision recorded in task file, file moved to completed/ — then Watchtower returned red 500 toast. User clicked GO again. Confusion about whether the decision actually landed.

T-1469 fixed the data-source cause (malformed YAML from block-style components emit). This task hardens the endpoint so OTHER side-effect failures (network blip during emit_review, episodic gen edge case, etc.) don't 500 when the primary decision succeeded.

## Acceptance Criteria

### Agent
- [x] After `run_fw_command` returns, detect "primary decision landed" by reading task frontmatter: status == "work-completed" AND task file location reflects the decision (in .tasks/completed/ for go/no-go, status == "started-work" with Decision block for defer).
- [x] When primary landed but exit code non-zero: return HTTP 200 with `warning` field in payload (htmx fragment shows decision-recorded badge + dim warning text; non-htmx redirects with `?warning=` query param).
- [x] When primary did NOT land: keep existing 500/redirect-with-error behavior.
- [x] Pytest regression: simulate `run_fw_command` returning ok=False but task file showing work-completed — assert status_code == 200 and warning in response.
- [x] Pytest regression: simulate primary failure (task still started-work) — assert existing 500/redirect path still triggers.
- [x] No regression: existing inception decide tests pass (29/29).

### Human
<!-- None — internal endpoint hardening, no new UX surface beyond the warning string. -->

## Verification

# T-1470 pytest regression
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/web/test_inception_decide_hardening.py -q 2>&1 | tail -10
# Existing inception blueprint tests still pass
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/web/ -q -k inception 2>&1 | tail -10

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

### 2026-04-25T19:28:15Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1470-symptom-a-fix--watchtower-inceptiondecid.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-0ff847e0
- **Timestamp:** 2026-04-25T19:31:38Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-25T19:31:27Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
