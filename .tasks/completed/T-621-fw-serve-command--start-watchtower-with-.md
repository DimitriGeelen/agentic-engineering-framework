---
id: T-621
name: "fw serve — add UFW firewall check to watchtower.sh startup"
description: >
  bin/watchtower.sh (T-250) already handles port check, PID management, health check,
  LAN IP reporting.
  Missing: UFW firewall check. When starting on a non-default port, LAN clients can't
  connect because
  UFW policy is DROP. Add auto-detect and auto-open (with user notification) to do_start().

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: [bin/watchtower.sh]
related_tasks: []
created: 2026-03-25T21:59:43Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-25T23:00:16Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
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
---

# T-621: fw serve command — start Watchtower with port, firewall, and LAN access checks

## Context

`bin/watchtower.sh` (T-250) handles port check, PID management, health check, LAN IP.
Missing: UFW firewall auto-open. User started Watchtower on :8050, couldn't reach from Mac — UFW DROP policy blocked it.

## Acceptance Criteria

### Agent
- [x] `bin/watchtower.sh` checks UFW status after successful start
- [x] If UFW is active and port is not allowed, opens it with `ufw allow PORT/tcp`
- [x] Logs firewall action to user (opened/already-open/ufw-inactive)
- [x] Works when UFW is not installed (graceful skip)
- [x] `fw serve --port 8050` starts server AND opens firewall in one command

### Human
- [x] [RUBBER-STAMP] Run `fw serve --port 8050` from Mac via SSH, verify reachable
  **Steps:**
  1. `ssh root@192.168.10.107 "cd /opt/999-Agentic-Engineering-Framework && bin/fw serve stop && bin/fw serve --port 8050"`
  2. Open `http://192.168.10.107:8050` in browser
  **Expected:** Watchtower loads, firewall was auto-opened
  **If not:** Check `ufw status | grep 8050` on the server

## Verification

grep -q 'ufw' bin/watchtower.sh
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

### 2026-03-25T21:59:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-621-fw-serve-command--start-watchtower-with-.md
- **Context:** Initial task creation

### 2026-03-25T23:00:16Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:18Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f63a69d2
- **Timestamp:** 2026-06-02T15:03:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
