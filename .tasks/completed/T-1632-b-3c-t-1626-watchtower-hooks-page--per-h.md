---
id: T-1632
name: "B-3c (T-1626): Watchtower /hooks page — per-hook fire/fail rates"
description: >
  New Watchtower blueprint /hooks reads .hook-counter + .hook-failure-counter (T-1628
  telemetry) and displays per-hook table: fires, failures, ratio. Pinned by Playwright
  DOM-content assertion (T-1575 visual verification rule).

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [from-T-1626, B-3c, watchtower, ui]
components: [agents/context/post-compact-resume.sh, bin/fw, 
      lib/doctor-hook-exercise.py, tests/playwright/test_hooks_page.py, 
      tests/unit/doctor_hook_exercise.bats, 
      tests/unit/session_start_hook_warning.bats, web/blueprints/hooks.py, 
      web/blueprints/__init__.py, web/shared.py, web/templates/hooks.html]
related_tasks: [T-1626, T-1628, T-1629]
created: 2026-05-01T07:22:38Z
last_update: '2026-08-16T22:24:39Z'
date_finished: 2026-05-01T09:57:39Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:54Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1632: B-3c (T-1626): Watchtower /hooks page — per-hook fire/fail rates

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Context

Surfaces the T-1628 telemetry (and T-1631 threshold-rule state) on a Watchtower page so an operator can see at a glance which hooks are firing, which are failing, and which are over threshold — without grepping `.context/working/`. Closes the visible-evidence half of the T-1626 immune-system loop. Threshold logic delegated to `lib/hook-threshold.py` via subprocess so the rule lives in exactly one place.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/hooks.py` reads `.hook-counter` and `.hook-failure-counter`, sums duplicate keys defensively, invokes `lib/hook-threshold.py --all` for over-threshold flags, and renders a per-hook table sorted (failing-first, then by descending failures, then name)
- [x] `web/templates/hooks.html` renders the table with: hook name, fires, failures, ratio %, status badge (FAIL / ok); summary metrics (total hooks, total fires, total failures, failing count, overall ratio); threshold-config display
- [x] Blueprint registered in `web/blueprints/__init__.py` and added to the `Govern` nav group in `web/shared.py`
- [x] `tests/playwright/test_hooks_page.py` asserts the page returns 200 and contains the expected DOM elements (page heading, summary card, table headers, at least one row when telemetry exists) — per T-1575 visual verification rule
- [x] Page renders without 500 when telemetry files don't exist (degraded-empty case — covered by `test_either_table_or_empty_state`)

### Human
- [x] [REVIEW] Page is readable and useful at a glance
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw serve --port 3000` (in another terminal)
      2. Open `http://localhost:3000/hooks` in a browser
      3. Skim: can you tell within 5 seconds which hooks (if any) are unhealthy?
      **Expected:** failing hooks rise to the top with a visible badge; total counts immediately surface scale
      **If not:** note what got buried or what was hard to scan

## Verification

python3 -c "from web.blueprints.hooks import bp; print('imports ok')"
python3 -m py_compile web/blueprints/hooks.py
PYTHONDONTWRITEBYTECODE=1 FW_TEST_PORT=3000 python3 -m pytest tests/playwright/test_hooks_page.py -q

## Recommendation

**Recommendation:** GO

**Rationale:** /hooks page closes the visible-evidence half of the T-1626 immune-system loop. Operator can now see at a glance which hooks are firing, which are failing, and which are over threshold — without grepping `.context/working/`. Threshold logic is delegated to `lib/hook-threshold.py` (T-1631) so the rule has a single source of truth across audit + register + UI. Sort order surfaces failing hooks at the top.

**Evidence:**
- Live page returns 200: `curl -sf http://localhost:3000/hooks` succeeds, contains `Hook Telemetry`, `Hooks Tracked`, `Total Fires`, `hooks-summary`, `hooks-table`
- 6/6 Playwright tests pass — `test_page_returns_200`, `test_page_has_main_heading`, `test_summary_card_block_present`, `test_either_table_or_empty_state`, `test_threshold_info_displays_config`, `test_table_columns_when_present`
- Empty-state path covered (page renders without 500 when no telemetry exists)
- Blueprint registered in `web/blueprints/__init__.py:38`; nav entry added to Govern group in `web/shared.py:101`
- Fabric cards: `web-blueprints-hooks.yaml`, `web-templates-hooks.yaml`, `tests-playwright-test_hooks_page.yaml`

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

### 2026-05-01T07:22:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1632-b-3c-t-1626-watchtower-hooks-page--per-h.md
- **Context:** Initial task creation

### 2026-05-01T09:52:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-51edb261
- **Timestamp:** 2026-06-02T14:58:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent)** — `web/blueprints/hooks.py` reads `.hook-counter` and `.hook-failure-counter`, sums duplicate keys defensively, invokes `lib/hook-threshold.py --all` for over-threshold flags, and renders a per-hook tab
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/hook-threshold.py in: `web/blueprints/hooks.py` reads `.hook-counter` and `.hook-failure-counter`, sums duplicate keys defensively, invokes `lib/hook-threshold.py --all` fo`
- **AC#2 (Agent)** — `web/templates/hooks.html` renders the table with: hook name, fires, failures, ratio %, status badge (FAIL / ok); summary metrics (total hooks, total fires, total failures, failing count, overall rati
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/hooks.html in: `web/templates/hooks.html` renders the table with: hook name, fires, failures, ratio %, status badge (FAIL / ok); summary metrics (total hooks, total `
- **AC#3 (Agent)** — Blueprint registered in `web/blueprints/__init__.py` and added to the `Govern` nav group in `web/shared.py`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/__init__.py in: Blueprint registered in `web/blueprints/__init__.py` and added to the `Govern` nav group in `web/shared.py``
### 2026-05-01T09:57:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
