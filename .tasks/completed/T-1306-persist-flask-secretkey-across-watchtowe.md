---
id: T-1306
name: "Persist Flask secret_key across Watchtower restarts (absorb termlink pattern)"
description: >
  Implement _resolve_secret_key() helper in web/app.py: env var wins, else load from
  PROJECT_ROOT/.context/working/.fw-secret-key (chmod 600), else generate and persist.
  Add gitignore entry. Regression test proves stability across two create_app() invocations.
  Sibling to T-1302 inception.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-18T19:42:05Z
last_update: '2026-08-16T22:24:28Z'
date_finished: 2026-04-18T19:44:31Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:28Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1306: Persist Flask secret_key across Watchtower restarts (absorb termlink pattern)

## Context

Sibling to inception T-1302 (pickup P-029 from termlink). Upstream fix at termlink@0373828e.

Current `web/app.py:47-55` generates a new Flask `secret_key` on every startup when `FW_SECRET_KEY` is unset — invalidates all browser sessions and breaks CSRF. Fix: add a three-source resolver (env → file → generate-and-persist) that stores the generated key at `PROJECT_ROOT/.context/working/.fw-secret-key` with mode 0600.

## Acceptance Criteria

### Agent
- [x] `_resolve_secret_key(project_root)` helper added to `web/app.py` with three-source resolution (env → file → generate+persist)
- [x] `create_app()` calls the helper instead of the inline block (lines 47-55 replaced)
- [x] Persisted key file is chmod 0600 at write time
- [x] Log message reports source label (`env` / `file` / `generated`), never the key material
- [x] `.context/working/.fw-secret-key` added to `.gitignore`
- [x] New pytest in `tests/web/test_secret_key.py` verifies key stability across two `create_app()` invocations
- [x] `fw test web` passes (existing pytests still green)

## Verification

grep -q "_resolve_secret_key" web/app.py
grep -q "\.fw-secret-key" web/app.py
grep -q "\.fw-secret-key" .gitignore
python3 -c "from web.app import create_app; a=create_app(); b=create_app(); assert a.secret_key == b.secret_key, 'key unstable'"
python3 -m pytest tests/web/test_secret_key.py -q

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

### 2026-04-18T19:42:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1306-persist-flask-secretkey-across-watchtowe.md
- **Context:** Initial task creation

### 2026-04-18T19:42:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T19:44:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-23f747b0
- **Timestamp:** 2026-06-02T14:56:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
