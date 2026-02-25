---
id: T-280
name: "Provision Watchtower LXC on Proxmox"
description: >
  Create LXC container on proxmox2 for Watchtower. IP: 192.168.10.170, hostname: watchtower. Create DHCP reservation for .170 on the router/DHCP server. Install Python 3.12, git, curl, pip, gunicorn, sqlite-vec deps. Configure static IP, DNS. Enable Proxmox HA for auto-restart on node failure. See T-279 research: docs/reports/T-279-watchtower-deployment-model.md. Parent: T-279.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [deployment, infrastructure, lxc]
components: []
related_tasks: []
created: 2026-02-25T17:48:11Z
last_update: 2026-02-25T18:28:17Z
date_finished: 2026-02-25T18:28:17Z
---

# T-280: Provision Watchtower LXC on Proxmox

## Context

Provision LXC container on proxmox2 for Watchtower deployment. See T-279 research: `docs/reports/T-279-watchtower-deployment-model.md`.

## Acceptance Criteria

### Agent
- [x] LXC container created on proxmox2 (VMID 170, hostname: watchtower)
- [x] Debian 13 template (Python 3.13 built-in)
- [x] Static IP 192.168.10.170/24 configured
- [x] SSH access working from dev machine (root@192.168.10.170)
- [x] Python 3.13, git, curl, pip installed
- [x] Proxmox HA enabled for auto-restart on node failure
- [x] Container set to start on boot (onboot=1)

## Verification

ping -c 1 -W 3 192.168.10.170
ssh -o ConnectTimeout=5 -o BatchMode=yes root@192.168.10.170 'python3 --version'
ssh -o ConnectTimeout=5 -o BatchMode=yes root@192.168.10.170 'git --version'

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

### 2026-02-25T17:48:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-280-provision-watchtower-lxc-on-proxmox.md
- **Context:** Initial task creation

### 2026-02-25T17:50:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25 — provisioned [claude-code]
- **Action:** Created LXC 170 on proxmox2 via Proxmox API
- **Details:** Debian 13.1, Python 3.13.5, 1024MB RAM, 2 cores, 10GB disk
- **IP:** 192.168.10.170/24, gateway 192.168.10.1, DNS 192.168.10.20/21
- **HA:** Enabled via Proxmox cluster HA (auto-restart on node failure)
- **Packages:** git 2.47.3, curl 8.14.1, pip 25.1.1, python3-venv, sqlite3, build-essential

### 2026-02-25T18:28:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
