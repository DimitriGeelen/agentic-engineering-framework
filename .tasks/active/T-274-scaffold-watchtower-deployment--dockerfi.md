---
id: T-274
name: "Scaffold Watchtower deployment — Dockerfile, compose, Traefik routes"
description: >
  Generate deployment files for Watchtower using swarm pattern. Customize Dockerfile for Flask+deps, configure docker-compose with health checks, create Traefik routes for watchtower.docker.ring20.geelenandcompany.com. Wire OLLAMA_HOST to GPU host. Depends on T-273 (needs /health endpoint). See docs/reports/T-272-deploy-watchtower-ring20.md.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [deployment, infrastructure, docker, traefik]
components: [bin/fw, Dockerfile, deploy/docker-compose.swarm.yml, deploy/traefik-routes.yml]
related_tasks: [T-272, T-273, T-277, T-077]
created: 2026-02-25T08:09:37Z
last_update: 2026-02-25T09:24:19Z
date_finished: 2026-02-25T09:24:19Z
---

# T-274: Scaffold Watchtower deployment — Dockerfile, compose, Traefik routes

## Context

Generate deployment files for Watchtower using the `swarm` pattern (not `gpu` — Ollama runs on GPU host as system service, not containerized). Watchtower connects to Ollama via `OLLAMA_HOST` env var pointed at 192.168.10.107.

**Research:** [docs/reports/T-272-deploy-watchtower-ring20.md](../../docs/reports/T-272-deploy-watchtower-ring20.md) (RQ-2: Ring20 Infrastructure)
**Parent inception:** T-272 | **Depends on:** T-273 (needs /health endpoint) | **Unblocks:** T-275, T-277

### Architecture Decision
- **Pattern:** `swarm` (not `gpu` split)
- **Why:** Ollama already runs on GPU host (.107). No need to containerize it.
- **Ports:** 5050 (prod), 5051 (dev) — next available in Ring20 allocation
- **FQDN:** `watchtower.docker.ring20.geelenandcompany.com`
- **Ollama connection:** `OLLAMA_HOST=http://192.168.10.107:11434` env var

### Files to create
- `Dockerfile` — Python 3.11-slim, pip install from requirements, gunicorn entrypoint
- `deploy/docker-compose.swarm.yml` — 2 replicas, health check via /health, OLLAMA_HOST env
- `deploy/traefik-routes.yml` — Prod + dev routing through Traefik HA pair
- `.onedev-buildspec.yml` — CI/CD pipeline (build, push, deploy to Swarm)
- `.dockerignore` — Exclude .git, .tasks, .context, docs, tests

## Acceptance Criteria

### Agent
- [x] `Dockerfile` builds successfully (`docker build -t watchtower-test .`)
- [x] `deploy/docker-compose.swarm.yml` parses (`docker compose -f deploy/docker-compose.swarm.yml config`)
- [x] `deploy/traefik-routes.yml` is valid YAML
- [x] `.onedev-buildspec.yml` follows Ring20 patterns (registry push verification, convergence wait)
- [x] `.dockerignore` excludes .git, .context, .tasks, docs, tests, __pycache__
- [x] Dockerfile uses gunicorn (not Flask dev server) as entrypoint
- [x] Health check in compose targets `/health` endpoint (from T-273)
- [x] OLLAMA_HOST env var configured in compose pointing to GPU host
- [x] Port allocation registered: 5050 (prod), 5051 (dev)
- [x] Traefik routes include retry middleware (3 attempts, 200ms interval)

### Human
- [ ] Docker image starts and serves http://localhost:5050/ correctly
- [ ] Q&A streaming works through Docker container (Ollama reachable from container)
- [ ] Traefik routes accessible from LAN

## Verification

# Dockerfile exists and has gunicorn
grep -q "gunicorn" Dockerfile

# Docker compose is valid YAML
python3 -c "import yaml; yaml.safe_load(open('deploy/docker-compose.swarm.yml'))"

# Traefik routes valid YAML
python3 -c "import yaml; yaml.safe_load(open('deploy/traefik-routes.yml'))"

# Buildspec exists and has required structure
grep -q "version: 37" .onedev-buildspec.yml && grep -q "Build and Deploy Production" .onedev-buildspec.yml

# OLLAMA_HOST configured
grep -q "OLLAMA_HOST" deploy/docker-compose.swarm.yml

# Health check targets /health
grep -q "/health" deploy/docker-compose.swarm.yml

# Port 5050 in compose
grep -q "5050" deploy/docker-compose.swarm.yml

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

### 2026-02-25T08:09:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-274-scaffold-watchtower-deployment--dockerfi.md
- **Context:** Initial task creation

### 2026-02-25T09:16:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25T09:24:19Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-02-25T09:24:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
