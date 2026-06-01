---
id: T-1287
name: "Watchtower writes pid/port/url triple on startup (T-1284 B2)"
description: >
  Watchtower writes pid/port/url triple on startup (T-1284 B2)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/watchtower.sh]
related_tasks: []
created: 2026-04-17T19:58:28Z
last_update: 2026-04-17T22:35:10Z
date_finished: 2026-04-17T22:35:10Z
---

# T-1287: Watchtower writes pid/port/url triple on startup (T-1284 B2)

## Context

B2 of T-1284. Watchtower's start script writes `.pid` already; add `.port`
and `.url` after the health check passes (so files are only present when
the service is confirmed bound + serving). Provides Layer 1 (authoritative
triple) for the rewritten `_watchtower_url` in B3.

Also update `do_stop` to clean all three files.

## Acceptance Criteria

### Agent
- [x] `.context/working/watchtower.port` exists after successful start and
      contains the port number (integer, one line, no whitespace)
- [x] `.context/working/watchtower.url` exists after successful start and
      contains a URL of the form `http://<lan-or-localhost>:<port>` that
      returns 200 on `/api/_identity` when fetched
- [x] All three files (pid, port, url) are removed on `bin/watchtower.sh stop`
- [x] The port in the `.port` file matches the actual listening port of
      the PID in `.pid` (no staleness after restart on a different port)
- [x] No regression: existing `.pid` behavior unchanged; `do_start`
      still exits non-zero on failure and cleans up

## Verification

# Static checks on the start script — triple write logic is present.
grep -q 'PORT_FILE=.*watchtower.port' bin/watchtower.sh
grep -q 'URL_FILE=.*watchtower.url' bin/watchtower.sh
grep -q '"${PORT_FILE}.tmp"' bin/watchtower.sh
grep -q '"${URL_FILE}.tmp"' bin/watchtower.sh
grep -q 'rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"' bin/watchtower.sh
bash -n bin/watchtower.sh

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

### 2026-04-17T19:58:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1287-watchtower-writes-pidporturl-triple-on-s.md
- **Context:** Initial task creation

### 2026-04-17T22:35:10Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
