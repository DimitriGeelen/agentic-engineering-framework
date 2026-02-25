---
id: T-272
name: "Deploy Watchtower + Q&A to Ring20 production"
description: >
  Inception: Deploy Watchtower + Q&A to Ring20 production

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [deployment, inception, ring20, production]
components: [web/app.py, bin/fw, agents/audit/audit.sh]
related_tasks: [T-273, T-274, T-275, T-276, T-277, T-278, T-254, T-077]
created: 2026-02-25T07:59:26Z
last_update: 2026-02-25T07:59:26Z
date_finished: null
---

# T-272: Deploy Watchtower + Q&A to Ring20 production

## Problem Statement

Watchtower + Q&A web app runs as a Flask dev server on localhost:3000. It needs to be deployed to Ring20 production infrastructure so it's accessible via `watchtower.docker.ring20.geelenandcompany.com`. Additionally, `fw deploy` currently bypasses all framework governance — the highest-stakes operation has the least enforcement.

## Assumptions

1. Ollama on GPU host (192.168.10.107) is reachable from Swarm worker nodes
2. Swarm pattern (not GPU split) is sufficient — Watchtower is CPU-only, Ollama is external
3. Port 5050/5051 available in Ring20 allocation
4. OneDev CI/CD can build and deploy to Swarm
5. Single Dockerfile sufficient (no separate inference container)

## Exploration Plan

5 parallel research agents investigated:
- **RQ-1:** Web app architecture (12 blueprints, 50+ routes, Ollama/SQLite/tantivy deps)
- **RQ-2:** Ring20 infrastructure (swarm vs gpu patterns, Traefik, CI/CD)
- **RQ-3:** Production readiness gaps (WSGI, health, auth, config, errors)
- **RQ-4:** Deployment quality gates (pre/during/post-deploy, audit integration)
- **RQ-5:** Framework skill integration (/deploy-check, /rollback, learnings harvest)

**Full research:** [docs/reports/T-272-deploy-watchtower-ring20.md](../../docs/reports/T-272-deploy-watchtower-ring20.md)

## Technical Constraints

- **Network:** Swarm workers (.201-.203) must reach GPU host (.107:11434) for Ollama
- **Traefik:** HA pair (.51 + .53) with VIP .52 — routes must sync to BOTH nodes (L-TRF-02)
- **Swarm:** Host mode required (L-SWM-06), stop-first update order (L-SWM-08)
- **Registry:** 192.168.10.201:5000 — push verification required (L-CICD-05)
- **Build:** Isolated build container on CT 400 (L-BUILD-01)
- **GPU host:** Already runs Ollama for sprechloop — shared resource, not dedicated

## Scope Fence

**IN scope:**
- Production readiness (WSGI, health, config, errors) — T-273
- Deployment scaffold (Dockerfile, compose, routes) — T-274
- Pre-deploy quality gate (audit section, gated fw deploy) — T-275
- Deploy skills (/deploy-check, /rollback) — T-276
- First deployment execution — T-277
- Learning harvest — T-278

**OUT of scope:**
- User authentication (future task — CSRF is sufficient for internal tool)
- Prometheus metrics (future task)
- Rate limiting on /search/ask (future task)
- Multi-environment config (dev/staging/prod) — only prod + dev for now
- CDN for static assets (Traefik serves them fine for internal use)

## Acceptance Criteria

- [x] Problem statement validated (research complete)
- [x] Assumptions documented (5 assumptions above)
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Swarm pattern works for Watchtower (research confirms: YES)
- Ollama reachable from Swarm nodes (assumption — testable with ping from worker)
- Framework governance gaps addressable in 6 tasks (research confirms: YES)

**NO-GO if:**
- GPU split required (would need containerized Ollama — much more complex)
- Network isolation prevents Swarm-to-GPU-host communication
- OneDev CI/CD incompatible with framework repo structure

## Verification

# Research artifact exists
test -f docs/reports/T-272-deploy-watchtower-ring20.md

# All 6 child tasks created
for t in T-273 T-274 T-275 T-276 T-277 T-278; do ls .tasks/active/${t}-*.md; done

## Decisions

### 2026-02-25 — Deployment pattern
- **Chose:** `swarm` pattern with remote Ollama (not `gpu` split)
- **Why:** Ollama already runs on GPU host as system service. Watchtower is CPU-only Flask app. No benefit to containerizing Ollama.
- **Rejected:** GPU split pattern (would containerize Ollama, manage GPU allocation, duplicate model storage)

### 2026-02-25 — Quality gate approach
- **Chose:** Combined audit section + gated fw deploy (Option C from RQ-4)
- **Why:** Reuses existing audit infrastructure, consistent reporting, single `fw audit --section deployment` callable from both audit and deploy
- **Rejected:** Inline gates in fw deploy only (duplicates audit logic), separate pre-deploy script (misses audit integration)

## Decision

Pending human go/no-go. Research recommends GO — all constraints resolvable, 6 tasks scoped and linked.

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
