---
id: T-284
name: "Decommission Swarm watchtower stack"
description: >
  After LXC deployment verified and Traefik remapped: remove Swarm watchtower stack (docker stack rm watchtower), clean up registry images, update ring20-deployer ports.yaml to reflect LXC deployment. Keep Docker deployment files (Dockerfile, compose, buildspec) in repo history but mark as superseded. Depends on T-282 (Traefik remapped and verified). See T-279 research. Parent: T-279.

status: work-completed
workflow_type: decommission
owner: human
horizon: now
tags: [deployment, decommission, swarm]
components: []
related_tasks: []
created: 2026-02-25T17:48:42Z
last_update: 2026-02-25T19:04:43Z
date_finished: 2026-02-25T19:04:43Z
---

# T-284: Decommission Swarm watchtower stack

## Context

Remove the Swarm watchtower stack now that LXC deployment is verified and Traefik remapped. Keep Docker files in repo for reference.

## Acceptance Criteria

### Agent
- [x] Swarm watchtower stack removed (`docker stack rm watchtower`)
- [x] LXC still serving traffic after Swarm removal (both FQDNs healthy)
- [x] ring20-deployer ports.yaml updated with LXC host
- [x] Dockerfile marked as superseded (T-284)
- [x] docker-compose.swarm.yml marked as superseded (T-284)

## Verification

# Swarm stack gone
bash -c 'DOCKER_HOST=tcp://192.168.10.201:2375 docker stack ls 2>/dev/null | grep -v watchtower > /dev/null'
# LXC still serving
curl -sf https://watchtower.docker.ring20.geelenandcompany.com/health
curl -sf https://watchtower-dev.docker.ring20.geelenandcompany.com/health
# Docker files marked superseded
grep -q "SUPERSEDED" deploy/docker-compose.swarm.yml
grep -q "SUPERSEDED" Dockerfile

## Updates

### 2026-02-25T17:48:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-284-decommission-swarm-watchtower-stack.md
- **Context:** Initial task creation

### 2026-02-25T18:59:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25 — decommissioned [claude-code]
- **Action:** Removed Swarm watchtower stack via `DOCKER_HOST=tcp://192.168.10.201:2375 docker stack rm watchtower`
- **Removed:** watchtower_app service (2 replicas) + watchtower_default network
- **Registry:** Images (latest, 20260225-121925) left in place (registry delete not enabled)
- **Marked superseded:** Dockerfile, deploy/docker-compose.swarm.yml
- **Updated:** ring20-deployer ports.yaml with LXC host annotation
- **Verified:** Both FQDNs still healthy after Swarm removal

### 2026-02-25T19:04:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
