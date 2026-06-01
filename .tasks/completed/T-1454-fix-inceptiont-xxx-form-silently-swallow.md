---
id: T-1454
name: "Fix /inception/T-XXX form silently swallows decide errors (OBS-017, T-1452 same fix family)"
description: >
  Fix /inception/T-XXX form silently swallows decide errors (OBS-017, T-1452 same fix family)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-25T12:13:13Z
last_update: 2026-04-25T13:10:22Z
date_finished: 2026-04-25T12:16:30Z
---

# T-1454: Fix /inception/T-XXX form silently swallows decide errors (OBS-017, T-1452 same fix family)

## Context

OBS-017: Watchtower `/inception/T-XXX` form (plain POST, not htmx) at `web/templates/inception_detail.html:348` silently redirects on BOTH success and failure paths. The `record_decision` handler at `web/blueprints/inception.py:476-523` only surfaces errors when `HX-Request` header is present (line 511 branch). Plain-browser POST hits the failure case at line 503 (logs the error) but then falls through to `redirect(url_for(...))` at line 523 — user sees the same page with no indication of failure. Discovered T-1452 session: user clicked GO 3× because the regex-based AC auto-tick rejected the AC, but UI showed nothing. Same fix family as T-1452 (silent server-side failure on standalone/non-htmx UI).

## Acceptance Criteria

### Agent
- [x] On non-htmx decide failure, `record_decision` redirects with `?error=...` query param so user sees what happened (web/blueprints/inception.py:520-523)
- [x] `inception_detail.html` renders a visible red error banner above the decide form when `request.args.get('error')` is set, with the error text + common-cause hint
- [x] Successful path is unchanged — clean redirect, no banner (verified in existing `test_inception_decide_e2e_records_decision[go|no-go|defer]` passing)
- [x] Pytest: 2 new tests cover failure path (`test_inception_decide_failure_redirects_with_error_param` + `test_inception_decide_failure_htmx_returns_500`) — monkeypatch `run_fw_command` to fail, assert redirect Location includes `error=` for plain form; assert htmx path returns 500 unchanged
- [x] No regression — `tests/web/test_inception_decide_e2e.py` 8/8 pass; `tests/playwright/test_inception*.py + test_api_inception.py` 30/30 pass

### Human
- [x] [REVIEW] On `/inception/T-XXX`, attempt a decision that will fail (e.g. on a task with auto-tick mismatch like T-1452 had) and confirm an error banner appears
  **Steps:**
  1. Open `$(bin/fw watchtower url)/inception/T-1452` (decision already recorded — superseding decision path)
  2. Pick GO + provide rationale + submit
  3. If it succeeds without an error: try one of the other pending inception tasks and induce a failure (rationale length, etc.)
  **Expected:** Error path produces a red banner with the error text; success path silently redirects as before
  **If not:** Capture browser network tab + paste error response into task body

## Verification

grep -q "error=" web/blueprints/inception.py
grep -q "request.args.get(\"error\"\|request.args.get('error'" web/templates/inception_detail.html
PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework python3 -m pytest tests/web/test_inception_decide_e2e.py -q
PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework python3 -m pytest tests/playwright/test_inception.py tests/playwright/test_inception_page.py tests/playwright/test_api_inception.py -q

## Recommendation

**Recommendation:** Close.

**Rationale:** Same fix family as T-1452 — silent server-side errors with no UI surfacing. Two-line route change + 9-line template banner closes the loop. Tests cover both paths (plain redirect-with-error + htmx 500). Pre-existing `## Updates` triplicate problem on T-1452 was the symptom; this prevents the next victim.

**Evidence:**
- web/blueprints/inception.py:520-523 — non-htmx failure path now redirects with `?error=`
- web/templates/inception_detail.html:340-348 — red banner above decide form when `error` query param present
- 2 new pytest cases pass; 6 existing pass — no regression
- 30 playwright inception tests pass — no regression
- Manual curl test: `GET /inception/T-1452?error=Required+AC+unchecked` renders "Decision NOT recorded" banner with the error text

## Decisions

### 2026-04-25 — Query param over Flask flash()
- **Chose:** Pass error to redirect target via `?error=...` query string
- **Why:** Flask `flash()` requires `secret_key` config + session integration that isn't currently used elsewhere in the app. Query param is stateless, idempotent, and inspectable by the human (URL-bar reveals what failed).
- **Rejected:** flash() — too much new infrastructure for one banner. Convert form to htmx — changes UX (no full page reload) and may break expectations for users on flaky connections who rely on hard reload.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-25T12:13:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1454-fix-inceptiont-xxx-form-silently-swallow.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-1d736a6f
- **Timestamp:** 2026-04-25T12:16:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#5 (Agent)** — No regression — `tests/web/test_inception_decide_e2e.py` 8/8 pass; `tests/playwright/test_inception*.py + test_api_inception.py` 30/30 pass
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/web/test_inception_decide_e2e.py in: No regression — `tests/web/test_inception_decide_e2e.py` 8/8 pass; `tests/playwright/test_inception*.py + test_api_inception.py` 30/30 pass`

### 2026-04-25T12:16:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
