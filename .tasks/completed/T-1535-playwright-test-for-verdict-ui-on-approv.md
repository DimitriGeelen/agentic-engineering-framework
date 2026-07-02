---
id: T-1535
name: "Playwright test for verdict UI on /approvals and landing page"
description: >
  Playwright test for verdict UI on /approvals and landing page

status: work-completed
workflow_type: test
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-27T10:50:20Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T10:51:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
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

# T-1535: Playwright test for verdict UI on /approvals and landing page

## Context

T-971 AC-Playwright pairing rule: when a UI feature ships with an Agent AC, also write a Playwright test. T-1531/T-1532/T-1533 shipped UI features (verdict badges, filter buttons, landing pills) with curl-based Agent ACs but no Playwright coverage. This task closes the gap.

## Acceptance Criteria

### Agent
- [x] `tests/playwright/test_verdict_ui.py` exists with tests covering: verdict badges render on /approvals cards, GO filter button appears with `data-filter="go"`, clicking GO filter hides DEFER cards, landing-page renders verdict-pill elements with `data-verdict-pill` attributes
- [x] Tests pass: `python3 -m pytest tests/playwright/test_verdict_ui.py -v` (assumes Watchtower test server starts via existing conftest fixture)
- [x] Tests use the existing `page` fixture from `tests/playwright/conftest.py` (TEST_URL pattern)

## Verification

test -f tests/playwright/test_verdict_ui.py
grep -q 'data-verdict' tests/playwright/test_verdict_ui.py
grep -q 'data-filter' tests/playwright/test_verdict_ui.py
python3 -m pytest tests/playwright/test_verdict_ui.py -v --tb=short

## Recommendation

**Recommendation:** GO

**Rationale:** Closes the AC-Playwright pairing gap (T-971) for the entire T-1530→T-1534 review-workflow arc. 9 tests across 3 test classes guard the badges, filter buttons, and landing-page pills. Tests use conditional assertions (only check for GO pill when GO cards exist) so they pass on a fresh project with no awaiting-review tasks AND on the current host with 22 of them — but fail-fast when the rendering breaks.

**Evidence:**
- `tests/playwright/test_verdict_ui.py` — 9 tests, all PASS in 11.5s
- Cross-page assertion: landing-page pills are checked against /approvals card data, so the two surfaces stay in agreement
- Tests assert specific data attributes (`data-verdict`, `data-filter`, `data-verdict-pill`) — these are the contract surface, not pixel rendering



## Updates

### 2026-04-27T10:50:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1535-playwright-test-for-verdict-ui-on-approv.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-dc5e49a2
- **Timestamp:** 2026-06-02T14:58:08Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Tests use the existing `page` fixture from `tests/playwright/conftest.py` (TEST_URL pattern)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/playwright/conftest.py in: Tests use the existing `page` fixture from `tests/playwright/conftest.py` (TEST_URL pattern)`
### 2026-04-27T10:51:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
