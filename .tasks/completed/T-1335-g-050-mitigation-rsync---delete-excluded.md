---
id: T-1335
name: "G-050 mitigation: rsync --delete-excluded so vendored upgrades purge pre-existing __pycache__/.pyc"
description: >
  G-050 mitigation: rsync --delete-excluded so vendored upgrades purge pre-existing __pycache__/.pyc

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-19T14:08:01Z
last_update: 2026-04-19T14:11:14Z
date_finished: 2026-04-19T14:11:14Z
---

# T-1335: G-050 mitigation: rsync --delete-excluded so vendored upgrades purge pre-existing __pycache__/.pyc

## Context

G-050 mitigation. `do_vendor` in `bin/fw` uses `rsync -a --delete` with `--exclude` patterns to skip __pycache__/*.pyc. Without `--delete-excluded`, any pre-existing pyc in the target tree survives upgrades. Fresh vendored installs are fine (nothing there to keep), but existing 050-style consumers carry pyc across upgrades. Single-flag fix.

## Acceptance Criteria

### Agent
- [x] `bin/fw` do_vendor rsync call includes `--delete-excluded` flag
- [x] Empirical test: seed a target dir with `.pyc` + `__pycache__/` in a subpath, run do_vendor equivalent rsync, verify pyc removed
- [x] `bin/fw --version` still works (no syntax regression)

## Verification

grep -q "rsync -a --delete --delete-excluded" bin/fw
bash -n bin/fw
bin/fw --version

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

### 2026-04-19T14:08:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1335-g-050-mitigation-rsync---delete-excluded.md
- **Context:** Initial task creation

### 2026-04-19T14:11:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f2367f80
- **Timestamp:** 2026-06-02T14:56:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
