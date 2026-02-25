---
id: T-283
name: "Set up dev auto-update mechanism for Watchtower LXC"
description: >
  Configure automatic updates for watchtower-dev on the LXC: OneDev webhook on push to master triggers git pull + systemctl restart watchtower-dev on the LXC. Alternative: cron job every 5 minutes checking for new commits. Prod updates remain manual/explicit only. Depends on T-281 (services deployed). See T-279 research. Parent: T-279.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [deployment, automation, ci-cd]
components: []
related_tasks: []
created: 2026-02-25T17:48:38Z
last_update: 2026-02-25T18:54:15Z
date_finished: 2026-02-25T18:54:15Z
---

# T-283: Set up dev auto-update mechanism for Watchtower LXC

## Context

Automatic dev updates for watchtower-dev on LXC 170. See `docs/deployment-runbook.md`.

## Acceptance Criteria

### Agent
- [x] Update script at /opt/watchtower-dev-update.sh (fetch, diff, pull if changed, restart)
- [x] systemd timer running every 5 minutes
- [x] Script correctly detects "no changes" when repo is up-to-date
- [x] Script logs via journald (tag: watchtower-dev-update)
- [x] Prod remains manual-only (no auto-update for watchtower service)

## Verification

ssh root@192.168.10.170 'systemctl is-active watchtower-dev-update.timer'
ssh root@192.168.10.170 'test -x /opt/watchtower-dev-update.sh'
ssh root@192.168.10.170 'journalctl -t watchtower-dev-update --no-pager -n 1 | grep -q watchtower-dev-update'

## Decisions

### 2026-02-25 — update mechanism
- **Chose:** systemd timer (5-min polling) over OneDev webhook
- **Why:** Simpler (no webhook endpoint to configure/secure on LXC, no OneDev config needed), integrates with systemd logging, same effective latency for a dashboard
- **Rejected:** OneDev webhook (requires HTTP endpoint on LXC, auth setup, firewall rules)

## Updates

### 2026-02-25T17:48:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-283-set-up-dev-auto-update-mechanism-for-wat.md
- **Context:** Initial task creation

### 2026-02-25T18:51:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25 — implemented [claude-code]
- **Action:** Created update script + systemd timer on LXC 170
- **Script:** /opt/watchtower-dev-update.sh — git fetch, compare HEAD vs origin/master, pull + pip install + restart only if changed
- **Timer:** watchtower-dev-update.timer — runs every 5 min, logs via journald
- **Tested:** Script ran, detected no changes (correct), logged to journal

### 2026-02-25T18:54:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
