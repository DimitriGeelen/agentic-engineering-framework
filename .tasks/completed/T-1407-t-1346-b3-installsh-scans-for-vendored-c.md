---
id: T-1407
name: "T-1346-B3 install.sh scans for vendored consumer projects before linking shim"
description: >
  Build B3 from T-1346 GO decomposition: install.sh enumerates vendored consumer projects (FW_CONSUMER_SCAN_DIRS, default /opt) before linking the global shim, so users see which existing installs may be affected if the legacy symlink path is taken. T-1356 (B1) already closes the leak structurally (vendored beats global), so B3 is informational/observability — print discovered vendored consumers + active mode after install. Acceptance: (1) install.sh prints 'Vendored framework copies detected:' section listing scanned consumers; (2) suppression via --no-scan flag for CI; (3) bats covers found-zero, found-some, --no-scan.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-23T18:50:05Z
last_update: 2026-04-23T18:52:44Z
date_finished: 2026-04-23T18:52:44Z
---

# T-1407: T-1346-B3 install.sh scans for vendored consumer projects before linking shim

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `install.sh` adds `scan_vendored_consumers()` function that scans `${FW_CONSUMER_SCAN_DIRS:-/opt}` for `.agentic-framework/FRAMEWORK.md`
- [x] On install, prints `Vendored framework copies detected:` followed by the list (or `(none)` if zero), unless `--no-scan` is passed
- [x] Bats `tests/unit/install_scan.bats` covers: zero consumers, some consumers, --no-scan suppression
- [x] Existing install paths (legacy fallback + shim) continue to work; no regression in install flow exit code

## Verification

bats tests/unit/install_scan.bats
bash -n install.sh
grep -q "scan_vendored_consumers" install.sh

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

### 2026-04-23T18:50:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1407-t-1346-b3-installsh-scans-for-vendored-c.md
- **Context:** Initial task creation

### 2026-04-23T18:52:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
