---
id: T-281
name: "Deploy Watchtower to LXC — dev and prod services"
description: >
  Clone framework repo from OneDev into LXC: /opt/watchtower-dev (master) and /opt/watchtower-prod (tagged release). Create two systemd services: watchtower-dev on :5051, watchtower on :5050. Configure env vars (OLLAMA_HOST, FW_SECRET_KEY, FW_PORT). Install Python deps via pip. Verify both services start and respond on /health. Depends on T-280 (LXC provisioned). See T-279 research. Parent: T-279.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [deployment, lxc, systemd]
components: []
related_tasks: []
created: 2026-02-25T17:48:21Z
last_update: 2026-02-25T18:35:39Z
date_finished: 2026-02-25T18:35:39Z
---

# T-281: Deploy Watchtower to LXC — dev and prod services

## Context

Deploy the framework to LXC 170 with two git checkouts and systemd services. See `docs/deployment-runbook.md` and `docs/reports/T-279-watchtower-deployment-model.md`.

## Acceptance Criteria

### Agent
- [x] Git repo cloned to /opt/watchtower-dev (master branch)
- [x] Git repo cloned to /opt/watchtower-prod (master for now, tagged release later)
- [x] Python venv created and deps installed in both checkouts
- [x] systemd service `watchtower-dev` configured on :5051
- [x] systemd service `watchtower` configured on :5050
- [x] Both services running and responding on /health
- [x] Environment vars set (OLLAMA_HOST, FW_SECRET_KEY, FW_PORT)

### Human
- [ ] Dashboard loads correctly in browser via direct IP

## Verification

ssh root@192.168.10.170 'systemctl is-active watchtower'
ssh root@192.168.10.170 'systemctl is-active watchtower-dev'
curl -sf http://192.168.10.170:5050/health
curl -sf http://192.168.10.170:5051/health

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

### 2026-02-25T17:48:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-281-deploy-watchtower-to-lxc--dev-and-prod-s.md
- **Context:** Initial task creation

### 2026-02-25 — deployed [claude-code]
- **Action:** Deployed Watchtower to LXC 170 (192.168.10.170)
- **Steps:**
  - Cloned framework repo from OneDev to /opt/watchtower-dev and /opt/watchtower-prod
  - Created Python 3.13 venvs with web/requirements.txt deps
  - Created systemd services: watchtower (prod :5050) and watchtower-dev (dev :5051)
  - Configured .env with OLLAMA_HOST=192.168.10.107:11434, secret keys, model config
  - Both services running and responding on /health (app:ok, ollama:ok)

### 2026-02-25T18:28:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25T18:35:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
