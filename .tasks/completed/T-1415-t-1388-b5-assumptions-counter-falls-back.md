---
id: T-1415
name: "T-1388 B5: Assumptions counter falls back to task body when not registered"
description: >
  T-1388 B5: Assumptions counter falls back to task body when not registered

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T07:45:52Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-24T08:02:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=0 (no-signal); F-RECALL=0 
      (no-signal); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1415: T-1388 B5: Assumptions counter falls back to task body when not registered

## Context

T-1388 build decomposition, unit B5 (F2 fix). The /approvals page shows
"Assumptions: X/Y validated" from the global assumptions ledger
(`fw assumption add`-registered entries only). Most inception tasks list
assumptions inline in the task body (`A1:`, `A2:` bullets under
`## Assumptions`) without registering them, so the badge reads "0" while the
body clearly shows several. Example: T-1388 has 4 inline assumptions and 0
registered → /approvals shows "0 assumptions" → F2 inconsistency.

Fix: when no registered assumptions are linked to a task, fall back to
counting the inline bullets under `## Assumptions`. Template shows
`(from body)` marker to keep the provenance visible.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/approvals.py` exposes body-assumption fallback in `assumption_counts` dict (adds `source: "ledger"|"body"` key)
- [x] Regex `^- A\d+:` recognises the conventional inline-assumption format
- [x] `_approvals_content.html` renders the source hint when source=body
- [x] New Playwright test in `tests/playwright/test_inception.py` asserts body-sourced count renders for a decided inception with inline-only assumptions
- [x] Existing TestRedecideAffordance + TestRecommendationDecisionDedupe still pass (5/5)

## Verification

# 1. Module imports cleanly (both existing + new helper)
python3 -c "from web.blueprints.approvals import _load_pending_go_decisions, _count_body_assumptions"
# 2. Body-count helper recognises inline format on real T-1388 body (4 assumptions)
python3 -c "from web.blueprints.approvals import _count_body_assumptions; import pathlib; body = pathlib.Path('.tasks/active/T-1388-watchtower-inceptiont-xxx-page-is-one-sh.md').read_text().split('---',2)[2]; n = _count_body_assumptions(body); assert n == 4, f'expected 4 got {n}'"
# 3. Template renders (no jinja syntax error)
python3 -c "from jinja2 import Environment, FileSystemLoader; env = Environment(loader=FileSystemLoader('web/templates')); env.get_template('_approvals_content.html')"
# 4. New Playwright regression class passes (4 tests)
python3 -m pytest tests/playwright/test_inception.py::TestBodyAssumptionFallback -q 2>&1 | grep -qE "4 passed"

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

### 2026-04-24T07:45:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1415-t-1388-b5-assumptions-counter-falls-back.md
- **Context:** Initial task creation

### 2026-04-24T08:02:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-237fda7d
- **Timestamp:** 2026-06-02T14:57:19Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 8
     - evidence: `python3 -m pytest tests/playwright/test_inception.py::TestBodyAssumptionFallback -q 2>&1 | grep -qE "4 passed"`
