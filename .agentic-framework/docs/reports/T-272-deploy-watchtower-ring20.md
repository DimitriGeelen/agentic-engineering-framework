# T-272: Deploy Watchtower + Q&A to Ring20 Production

## Research Artifact

**Status:** Research Complete — Awaiting Go/No-Go
**Created:** 2026-02-25
**Research files:** `/tmp/fw-agent-rq{1-webapp,3-production,4-quality,5-skills}.md` + RQ-2 inline

## Problem Statement

The Watchtower web app (Flask, localhost:3000) needs to move from dev-mode to Ring20 production infrastructure. The Q&A features depend on Ollama GPU inference (Qwen3-14B, nomic-embed-text-v2-moe). The framework currently has no deployment quality gates — `fw deploy` is a thin passthrough to ring20-deployer with no pre-deploy audit, no post-deploy verification, and no deployment state tracking.

## Research Questions & Findings

### RQ-1: Current Web App Architecture

**Stack:** Flask 3.0+, 12 blueprints, 50+ routes, 32 Jinja2 templates, HTMX-driven UX.

| Component | Technology | Location | Production-Ready? |
|-----------|-----------|----------|-------------------|
| Web server | Flask dev server | `web/app.py` | NO — single-threaded, no WSGI |
| Search | tantivy (BM25) + sqlite-vec (vector) | `/tmp/` (ephemeral) | PARTIAL — auto-rebuilds but lost on reboot |
| LLM | Ollama (qwen3:14b + dolphin-llama3:8b) | localhost:11434 | YES — but needs network routing in prod |
| Embeddings | nomic-embed-text-v2-moe via Ollama | localhost:11434 | YES — same as LLM |
| Feedback DB | SQLite | `.context/working/qa_feedback.db` | YES — persistent |
| Static files | Flask serving (pico.css, htmx, cytoscape, etc.) | `web/static/` | NO — needs reverse proxy |
| CSRF | Session-based token | `web/app.py` | YES |
| Auth | None | — | NO — open to network |

**Key dependencies:** flask, pyyaml, ruamel.yaml, markdown2, bleach, ollama, sqlite-vec, tantivy

### RQ-2: Ring20 Infrastructure

**Deployment patterns available:**

| Pattern | Where it runs | Use case |
|---------|---------------|----------|
| `swarm` | Docker Swarm (.201 manager, .202/.203 workers) | CPU web apps |
| `gpu` | Split: Swarm (app) + GPU host .107 (inference) | ML apps with GPU inference |

**Infrastructure constants:**
- Registry: 192.168.10.201:5000
- Swarm manager: 192.168.10.201
- GPU host: 192.168.10.107
- Traefik HA: .51 + .53 (VIP .52)
- Domain: `docker.ring20.geelenandcompany.com`
- CI/CD: OneDev with buildspec YAML
- Next available ports: 5050/5051

**Scaffold generates:** Dockerfile, docker-compose.swarm.yml, .onedev-buildspec.yml, deploy/traefik-routes.yml, .dockerignore. GPU pattern adds Dockerfile.inference.

**Critical learnings encoded in templates:** L-BUILD-01 (isolated build container), L-CICD-05 (push verification), L-CICD-21 (host-networked helper), L-SWM-06 (host mode), L-SWM-08 (stop-first), L-TRF-02 (sync both nodes).

### RQ-3: Production Readiness Gaps

| Category | Gap Severity | Current State | Required |
|----------|-------------|---------------|----------|
| WSGI server | **HIGH** | Flask dev server (single-threaded) | gunicorn with 4+ workers |
| Concurrency | **HIGH** | SSE streams block all requests | Worker pool + Ollama timeout |
| Auth | **HIGH** | CSRF only, no user auth | Minimum: API key or basic auth |
| Health endpoint | **MEDIUM** | No `/health` — only root route check | Dedicated endpoint with dep checks |
| Error handling | **MEDIUM** | No 500 handler, stack traces leak | 500 handler + Ollama circuit breaker |
| Logging | **MEDIUM** | Plain text, no rotation | Structured JSON, rotation |
| Config | **MEDIUM** | Hardcoded model names, paths | Environment-based config module |
| Static files | **LOW** | Flask serving | Traefik/nginx in prod |
| Embedding DB | **MEDIUM** | `/tmp/` (ephemeral) | Persistent path in container volume |

### RQ-4: Deployment Quality Gates

**Three-phase gate model proposed:**

```
PRE-DEPLOY                    DEPLOY                       POST-DEPLOY
============                  ======                       ===========
G-D01: Audit pass             G-D05: Image push verify     G-D08: Health endpoint
G-D02: Clean git              G-D06: Convergence wait      G-D09: Smoke test
G-D03: Task traceability      G-D07: Auto-rollback         G-D10: Monitoring window
G-D04: Tests pass                                          G-D11: Rollback trigger
```

**Key finding:** `fw deploy` is a raw `exec` passthrough — no framework gates at all. Deployment is classified as Tier 0 in 011-EnforcementConfig.md but the `exec` bypasses all hooks. Swarm pattern has NO rollback (GPU pattern does).

**Recommendation:** Replace passthrough with gated flow. Add `deployment` section to audit.sh. Log deployments to `.context/deployments/`.

### RQ-5: Framework Skill Integration

**Current state:** No `/deploy`, `/deploy-check`, or `/rollback` skills exist. Deployment learnings are hardcoded in Jinja2 templates, not captured in learnings.yaml.

**Recommended skills (Option 2 — Medium Integration):**
1. `/deploy-check` — Pre-deployment validation (task gate, health, registry)
2. `/deploy-scaffold` — Framework wrapper around ring20-deployer scaffold
3. `/rollback` — Explicit deployment recovery with history

**Deployment state artifact:** `.context/deployments/{app-name}.yaml` with version history, health status, rollback records.

## Architecture Decision

**Pattern: `swarm` with remote Ollama (not `gpu` split)**

Rationale: Ollama already runs on the GPU host (192.168.10.107) as a system service. Watchtower is a CPU-only Flask app that calls Ollama via HTTP API. No need to containerize Ollama — just configure `OLLAMA_HOST` environment variable to point at the GPU host.

This gives us:
- Simpler deployment (single Dockerfile, no inference container)
- Shared Ollama across multiple apps (sprechloop already uses it)
- Standard swarm pattern with Traefik routing
- Health endpoint checks Ollama reachability as external dependency

Rejected: GPU split pattern — would require containerizing Ollama (already running), managing GPU allocation, duplicate model storage.

## Task Decomposition

See `.tasks/active/T-273` through `T-278` for implementation tasks.

| Task | Name | Type | Depends On | Deliverable |
|------|------|------|-----------|-------------|
| T-273 | Production readiness — WSGI, health, config, errors | build | — | web/wsgi.py, /health, web/config.py, error handlers |
| T-274 | Scaffold deployment — Dockerfile, compose, routes | build | T-273 | Dockerfile, docker-compose, traefik-routes |
| T-275 | Pre-deploy quality gate — audit section + gated fw deploy | build | T-274 | audit.sh deployment section, fw deploy enhancement |
| T-276 | Deploy skills — /deploy-check, /rollback | build | T-275 | .claude/commands/deploy-check.md, rollback.md |
| T-277 | First deployment — Watchtower to Ring20 | build | T-274, T-275 | Live at watchtower.docker.ring20.geelenandcompany.com |
| T-278 | Harvest deployment learnings | refactor | T-277 | learnings.yaml entries, template-to-learning extraction |

## Dialogue Log

1. **User:** "please evaluate if we can run fw deploy" — Discovered deployer exists, functional, ports available
2. **User:** "run agent deep analysis, write up research, plan tasks with rich content and linkage, quality control at each point, feedback learning" — Triggered this inception with 5 parallel research agents
3. **Key insight from research:** `fw deploy` is a raw exec passthrough that bypasses all framework governance (Tier 0, task gate, audit). This is the biggest gap — deploying is the highest-stakes operation but has the least enforcement.
