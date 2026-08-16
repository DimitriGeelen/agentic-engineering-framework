---
id: T-1400
name: "T-1268 B3: Watchtower /pending page — table of pending-updates entries with
  resolve action"
description: >
  T-1268 B3: Watchtower /pending page — table of pending-updates entries with resolve
  action

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/blueprints/__init__.py, web/blueprints/pending.py, 
      web/templates/pending.html]
related_tasks: []
created: 2026-04-23T14:11:07Z
last_update: '2026-08-16T22:24:31Z'
date_finished: 2026-04-23T14:15:22Z
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
  - ts: '2026-08-16T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1400: T-1268 B3: Watchtower /pending page — table of pending-updates entries with resolve action

## Context

T-1268 B3 — final B-unit inside the framework repo. B1 (registry), B2
(doctor surfacing), B4 (reminder) all ship; B3 adds the Watchtower UI so
humans can view + resolve pending entries with a click instead of CLI.

Scope is deliberately minimal: one page with a table of pending entries,
one resolve button per row. No filters, no inline editing, no charts.
Follow the blueprint pattern at `web/blueprints/cron.py`.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/pending.py` exists with `/pending` GET route and `/api/v1/pending/<id>/resolve` POST endpoint
- [x] `web/templates/pending.html` renders the entries table (id, task, host, reason, command, created, resolve button)
- [x] Blueprint registered in `web/blueprints/__init__.py`
- [x] `/pending` returns HTTP 200 (via running Watchtower)
- [x] Page content contains expected heading "Pending Updates"
- [x] When zero pending entries: page renders with "no pending entries" placeholder (no server error)
- [x] When an entry exists: page content includes that entry's id
- [x] Resolve API flips status to `resolved` in the YAML (end-to-end test)
- [x] Playwright test `tests/playwright/test_pending_page.py` covers load + single-entry render + resolve-click + status flip (4/4 pass)
- [x] `python3 -m py_compile web/blueprints/pending.py` succeeds

## Verification

python3 -m py_compile web/blueprints/pending.py
python3 -m py_compile web/blueprints/__init__.py
test -f web/templates/pending.html
grep -q "pending_bp" web/blueprints/__init__.py
# Live Watchtower check (page loads, heading present)
_t=$(mktemp); curl -sf "$(bin/fw watchtower url)/pending" >"$_t" 2>&1; _r=$?; grep -q "Pending Updates" "$_t"; _g=$?; rm -f "$_t"; [ "$_r" -eq 0 ] && [ "$_g" -eq 0 ]
# Playwright test suite for /pending
_t=$(mktemp); pytest tests/playwright/test_pending_page.py -q >"$_t" 2>&1; _r=$?; tail -5 "$_t"; rm -f "$_t"; [ "$_r" -eq 0 ]

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

### 2026-04-23T14:11:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1400-t-1268-b3-watchtower-pending-page--table.md
- **Context:** Initial task creation

### 2026-04-23T14:15:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bae5f7b4
- **Timestamp:** 2026-06-02T14:57:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`
