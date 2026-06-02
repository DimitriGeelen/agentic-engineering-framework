---
id: T-1310
name: "Python-side PROJECT_ROOT discovery for Watchtower (walk up for .framework.yaml)"
description: >
  Add _discover_project_root() walking up from CWD for .framework.yaml, and _resolve_project_root() returning (path, source_label). PROJECT_ROOT = env > discovered > FRAMEWORK_ROOT. Log source at import. Sibling to T-1303 inception (pickup from termlink T-1123).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-18T20:02:09Z
last_update: 2026-04-18T20:05:18Z
date_finished: 2026-04-18T20:05:18Z
---

# T-1310: Python-side PROJECT_ROOT discovery for Watchtower (walk up for .framework.yaml)

## Context

Sibling to inception T-1303 (pickup P-030 from termlink T-1123). Python-side fallback must match `paths.sh` behaviour.

## Acceptance Criteria

### Agent
- [x] `_discover_project_root(start)` helper walks up from `start` looking for `.framework.yaml`, returns Path or None
- [x] `_resolve_project_root()` helper returns `(path, source_label)` where source ∈ {`env`, `discovered`, `framework`}
- [x] Module-level `PROJECT_ROOT` derived from `_resolve_project_root()` at import
- [x] One log line at import reports the source label (DEBUG unless source != `env`)
- [x] Env-var path unchanged (env still wins)
- [x] Regression tests cover env-wins, discovery-from-child-dir, fallback-to-framework
- [x] `fw test web` still passes

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

grep -q "_discover_project_root" web/shared.py
grep -q "_resolve_project_root" web/shared.py
python3 -m pytest tests/web/test_project_root_discovery.py -q
python3 -m pytest tests/web/ -q

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

### 2026-04-18T20:02:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1309-python-side-projectroot-discovery-for-wa.md
- **Context:** Initial task creation

### 2026-04-18T20:02:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T20:05:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f6a9cd46
- **Timestamp:** 2026-06-02T14:56:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
