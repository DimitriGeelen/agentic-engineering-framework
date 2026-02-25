---
id: T-277
name: "First deployment — Watchtower to Ring20 production"
description: >
  Execute first production deployment of Watchtower. Use fw deploy scaffold, validate with /deploy-check, push to registry, deploy via Swarm, verify health through Traefik FQDN. Document deployment runbook. Depends on T-274 (scaffold) and T-275 (quality gate). See docs/reports/T-272-deploy-watchtower-ring20.md.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [deployment, production, ring20]
components: [web/app.py]
related_tasks: [T-272, T-273, T-274, T-275, T-276]
created: 2026-02-25T08:09:53Z
last_update: 2026-02-25T20:37:13Z
date_finished: 2026-02-25T11:25:08Z
---

# T-277: First deployment — Watchtower to Ring20 production

## Context

The actual deployment execution — takes all the prep work from T-273 (production readiness), T-274 (scaffold), and T-275 (quality gates) and deploys Watchtower to Ring20. This is the "ship it" task. Includes writing a deployment runbook for future deployments.

**Research:** [docs/reports/T-272-deploy-watchtower-ring20.md](../../docs/reports/T-272-deploy-watchtower-ring20.md)
**Parent inception:** T-272 | **Depends on:** T-273, T-274, T-275

### Deployment Plan
1. Run `/deploy-check` (or manual equivalent if T-276 not done yet)
2. Tag release: `git tag v1.0.0`
3. OneDev CI/CD builds + pushes Docker image to registry
4. Swarm deploys 2 replicas
5. Traefik routes synced to both nodes
6. Verify health: `curl https://watchtower.docker.ring20.geelenandcompany.com/health`
7. Smoke test: dashboard loads, search works, Q&A streaming works
8. Log deployment record to `.context/deployments/`
9. Write runbook: `docs/deployment-runbook.md`

### Target
- **URL:** `https://watchtower.docker.ring20.geelenandcompany.com`
- **Ports:** 5050 (prod), 5051 (dev)
- **Ollama:** Connects to 192.168.10.107:11434

## Acceptance Criteria

### Agent
- [x] Docker image builds and pushes to registry (192.168.10.201:5000)
- [x] Swarm service running with 2 healthy replicas
- [x] Traefik routes synced to both nodes (.51 and .53)
- [x] Health endpoint responds: `curl -sf https://watchtower.docker.ring20.geelenandcompany.com/health`
- [x] Deployment record logged to `.context/deployments/`
- [x] `fw deploy status --app watchtower` shows healthy
- [x] Deployment runbook written: `docs/deployment-runbook.md`

### Human
- [x] Dashboard loads in browser via FQDN
- [x] Q&A streaming works through Traefik (Ollama reachable from Swarm)
- [x] All Watchtower pages render correctly (tasks, fabric, search, etc.)
- [x] Performance acceptable (page load < 2s, Q&A response starts < 5s)

## Verification

# Deployment status healthy
fw deploy status --app watchtower 2>&1 | grep -qi "Running"

# Health endpoint via FQDN
curl -sf --max-time 10 https://watchtower.docker.ring20.geelenandcompany.com/health

# Deployment record exists
ls .context/deployments/*.yaml 2>/dev/null | head -1

# Runbook exists
test -f docs/deployment-runbook.md

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

### 2026-02-25T08:09:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-277-first-deployment--watchtower-to-ring20-p.md
- **Context:** Initial task creation

### 2026-02-25T11:06:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25T11:24:58Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-02-25T11:25:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
