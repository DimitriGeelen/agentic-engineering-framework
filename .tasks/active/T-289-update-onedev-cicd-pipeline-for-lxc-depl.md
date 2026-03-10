---
id: T-289
name: "Update OneDev CI/CD pipeline for LXC deployment model"
description: >
  Update OneDev CI/CD pipeline for LXC deployment model

status: work-completed
workflow_type: build
owner: human
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-03-03T11:49:53Z
last_update: 2026-03-10T22:04:13Z
date_finished: 2026-03-03T11:54:26Z
---

# T-289: Update OneDev CI/CD pipeline for LXC deployment model

## Context

Rewrite `.onedev-buildspec.yml` from stale Swarm/Docker pipeline to LXC model. Dev already auto-updates via systemd timer (T-283). Prod deploys via SSH git checkout + restart. Swarm decommissioned in T-284. See `docs/deployment-runbook.md`.

## Acceptance Criteria

### Agent
- [x] `.onedev-buildspec.yml` updated for LXC deployment (no Docker/Swarm references)
- [x] Prod job: SSH to LXC, git fetch + checkout tag, pip install, restart watchtower
- [x] Prod trigger: `v*` tag creation
- [x] Health check verification after deploy with automatic rollback on failure
- [x] Buildspec YAML parses correctly (version: 37 preserved)
- [x] Dev not in pipeline (handled by systemd timer, T-283)

### Human
- [ ] [RUBBER-STAMP] Add OneDev server SSH key to LXC authorized_keys
  **Steps:**
  1. SSH into OneDev server and copy its public key: `cat ~/.ssh/id_rsa.pub`
  2. SSH into LXC 170: `ssh root@192.168.10.170`
  3. Append the key to `~/.ssh/authorized_keys`
  4. Test from OneDev server: `ssh root@192.168.10.170 echo ok`
  **Expected:** `ok` printed without password prompt
  **If not:** Check `sshd_config` for `PubkeyAuthentication yes` and restart sshd

- [ ] [REVIEW] Trigger a test run from OneDev to verify pipeline executes
  **Steps:**
  1. Open OneDev web UI, navigate to agentic-engineering-framework project
  2. Create a test tag (`v0.x.x-test`) or push a trivial commit with a `v*` tag
  3. Watch the build log for SSH deploy steps to LXC 170
  **Expected:** Build completes green, deploy connects to LXC, restarts watchtower
  **If not:** Check build log for SSH errors; verify the key from step 1 was added

## Verification

# YAML parses with OneDev custom tags
python3 -c "import yaml; L=type('L',(yaml.SafeLoader,),{}); L.add_multi_constructor('!',lambda l,t,n:l.construct_mapping(n) if isinstance(n,yaml.MappingNode) else l.construct_scalar(n)); yaml.load(open('.onedev-buildspec.yml'),Loader=L)"
grep -q "192.168.10.170" .onedev-buildspec.yml
# No Swarm references remain
! grep -q "docker stack" .onedev-buildspec.yml
grep -q "systemctl restart watchtower" .onedev-buildspec.yml

## Decisions

### 2026-03-03 — Dev pipeline scope
- **Chose:** Prod-only pipeline (v* tag trigger). Dev handled by existing systemd timer (T-283)
- **Why:** Dev already auto-updates every 5 min via timer; adding CI for dev is redundant and adds SSH key complexity
- **Rejected:** Both prod + dev in pipeline (redundant with timer), remove pipeline entirely (loses automated prod deploy)

## Updates

### 2026-03-03T11:49:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-289-update-onedev-cicd-pipeline-for-lxc-depl.md
- **Context:** Initial task creation

### 2026-03-03T11:54:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-03-10T22:04:13Z — status-update [task-update-agent]
- **Change:** horizon: now → next
