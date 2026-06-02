---
id: T-493
name: "fw update command — CLI wrapper for framework self-update"
description: >
  Add 'fw update' subcommand to bin/fw that wraps install.sh logic: git fetch + reset --hard in framework install dir. Show before/after version and changelog. Add --check flag for dry-run. From T-434 inception GO (Option A).

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: [upgrade, cli]
components: [bin/fw, lib/upgrade.sh]
related_tasks: []
created: 2026-03-14T20:05:12Z
last_update: 2026-04-06T22:29:17Z
date_finished: 2026-03-14T20:14:40Z
---

# T-493: fw update command — CLI wrapper for framework self-update

## Context

From T-434 inception GO (Option A). Research: `docs/reports/T-434-upgrade-process-inception.md`.
Extends existing `install.sh` self-update logic into a proper CLI command with rollback.

## Acceptance Criteria

### Agent
- [x] `lib/update.sh` exists with `do_update()` function
- [x] `fw update` command routed in `bin/fw`
- [x] `fw update --check` shows available updates without applying
- [x] `fw update --rollback` restores previous version
- [x] `fw update --help` shows usage
- [x] Help text in `show_help()` includes `update` command
- [x] E2E test validates update flow (fetch, check, version comparison)
- [x] Run `fw update --check` and verify output (reclassified from Human RUBBER-STAMP per T-954)

### Human

## Verification

grep -q "do_update" lib/update.sh
grep -q "update)" bin/fw
./bin/fw update --help | grep -q "Check for updates"
test -f tests/e2e/upgrade-test.sh
bash tests/e2e/upgrade-test.sh
bin/fw help | grep -q "update"

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

### 2026-03-14T20:05:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-493-fw-update-command--cli-wrapper-for-frame.md
- **Context:** Initial task creation

### 2026-03-14T20:14:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:17Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-261365eb
- **Timestamp:** 2026-06-02T15:03:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `./bin/fw update --help | grep -q "Check for updates"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `bin/fw help | grep -q "update"`
