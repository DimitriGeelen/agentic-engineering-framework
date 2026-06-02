---
id: T-1308
name: "build_ambient reads focus.yaml::current_task for Watchtower ambient strip"
description: >
  web/shared.py::build_ambient currently picks the first active task alphabetically as focus_task. Change to read .context/working/focus.yaml::current_task first, falling back to existing logic only if null/missing. Sibling to T-1304 inception (pickup from termlink T-1127).

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-18T19:53:20Z
last_update: 2026-04-18T20:00:15Z
date_finished: 2026-04-18T20:00:15Z
---

# T-1308: build_ambient reads focus.yaml::current_task for Watchtower ambient strip

## Context

Sibling to inception T-1304 (pickup from termlink T-1127). Ambient strip on Watchtower must show the task the agent is actually working on, not the first-alphabetical active task.

## Acceptance Criteria

### Agent
- [x] `build_ambient()` reads `.context/working/focus.yaml::current_task` and uses it as `focus_task` when non-null
- [x] Falls back to first-active-task when focus is missing, malformed, or null
- [x] Regression test proves focus.yaml `current_task: T-XXX` wins over alphabetical first
- [x] Regression test proves graceful fallback when focus.yaml is missing
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

grep -q "focus.yaml" web/shared.py
python3 -m pytest tests/web/test_build_ambient.py -q
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

### 2026-04-18T19:53:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1308-buildambient-reads-focusyamlcurrenttask-.md
- **Context:** Initial task creation

### 2026-04-18T19:53:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-18T20:00:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c095e28b
- **Timestamp:** 2026-06-02T14:56:36Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — `build_ambient()` reads `.context/working/focus.yaml::current_task` and uses it as `focus_task` when non-null
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/working/focus.yaml in: `build_ambient()` reads `.context/working/focus.yaml::current_task` and uses it as `focus_task` when non-null`
