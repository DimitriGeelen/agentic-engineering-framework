---
id: T-279
name: "Watchtower deployment model — framework dashboard vs multi-project SaaS"
description: >
  Inception: Watchtower deployment model — framework dashboard vs multi-project SaaS

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-02-25T14:55:34Z
last_update: 2026-02-25T17:47:59Z
date_finished: 2026-02-25T17:47:59Z
---

# T-279: Watchtower deployment model — framework dashboard vs multi-project SaaS

## Problem Statement

Production Watchtower shows empty "new project" page. Docker container has no access to framework data (.tasks/, .context/, .fabric/). Docker's ephemeral/stateless/replicated model conflicts with Watchtower's filesystem-dependent design (18+ write endpoints, git integration, fw CLI).

**For whom:** Framework developer (human + AI agents) needing remote dashboard access.
**Why now:** Production deployed but unusable — shows 0 tasks instead of 278.

## Assumptions

- A1: User wants Watchtower to show THIS framework's live data (**CONFIRMED**)
- A2: Data should be live/fresh, not stale snapshots (**CONFIRMED**)
- A3: Dev and prod environments needed with explicit promotion (**CONFIRMED**)
- A4: Multi-project is future — framework-first for now (**CONFIRMED**)
- A5: Resilience needed — data must survive machine death (**CONFIRMED**)

## Exploration Plan

1. RQ-1..RQ-5: Parallel research into framework purpose, Watchtower architecture, deployment model, multi-project intent, design history
2. Docker review: Two agents reviewed Docker bake-data approach — found 2 CRITICAL, 2 HIGH issues
3. Pivot: User suggested VM/LXC on Proxmox
4. RQ-6..RQ-7: Parallel research into Proxmox infrastructure, Ring20 services mapping
5. Decision: LXC eliminates all Docker critical issues

## Technical Constraints

- Ring20 Proxmox cluster: 4 nodes (.180-.195), IPs .140-.145 available
- Traefik HA on .51/.53 with VIP .52 — file provider routes to any IP
- Ollama GPU host on .107:11434 — shared across services
- DNS wildcard: *.docker.ring20.geelenandcompany.com → Traefik VIP
- LXC sufficient: Python 3.12, git, gunicorn, sqlite — no full VM needed

## Scope Fence

**IN scope:** Deployment model decision for Watchtower (Docker vs LXC vs VM)
**OUT of scope:** Multi-project Watchtower, cross-project Q&A, Watchtower feature changes

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- LXC eliminates Docker critical issues (write data loss, replica divergence, vector DB timeout)
- Proxmox infrastructure supports the deployment (IPs, HA, Traefik routing)
- Resource cost is acceptable (single LXC vs 2 Swarm replicas)

**NO-GO if:**
- Proxmox cannot host LXC with required dependencies
- Traefik cannot route to non-Swarm services
- No available IP space or Proxmox resources

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

### 2026-02-25 — Deployment model: LXC on Proxmox (not Docker Swarm)
- **Chose:** Single LXC container with two systemd services (dev on :5051, prod on :5050)
- **Why:** Docker's ephemeral/stateless/replicated model creates 2 CRITICAL issues (write data loss + replica divergence, vector DB timeout). LXC provides persistent filesystem, native git, and direct Ollama access — all critical for Watchtower's "command center" vision.
- **Rejected:** Docker with read-only mode (reduces to static viewer), Docker with NFS (complexity), two LXCs (overkill), full VM (overkill)

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-25T17:46:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** LXC on Proxmox eliminates all Docker critical issues (write data loss, replica divergence, vector DB timeout, stale data, git degradation) while preserving Watchtower command center vision. Single LXC with two systemd services (dev+prod) is simpler, cheaper, and better aligned with Watchtower filesystem-dependent architecture.

### 2026-02-25T17:46:33Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-02-25T17:46:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** LXC on Proxmox eliminates all Docker critical issues (write data loss, replica divergence, vector DB timeout, stale data, git degradation) while preserving Watchtower command center vision. Single LXC with two systemd services (dev+prod) is simpler, cheaper, and better aligned with Watchtower filesystem-dependent architecture.

### 2026-02-25T17:46:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** LXC on Proxmox eliminates all Docker critical issues. Single LXC with two systemd services for dev+prod.

### 2026-02-25T17:47:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
