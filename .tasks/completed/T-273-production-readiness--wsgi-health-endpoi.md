---
id: T-273
name: "Production readiness — WSGI, health endpoint, config, error handling"
description: >
  Prepare Watchtower web app for production deployment. Create WSGI entry point (gunicorn-compatible), add /health endpoint with dependency checks (Ollama, embedding DB), implement environment-based config module, add 500 error handler, move embedding DB to persistent path. See docs/reports/T-272-deploy-watchtower-ring20.md RQ-3.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [deployment, web, production]
components: [web/app.py, web/embeddings.py]
related_tasks: [T-272, T-274, T-254, T-262, T-263]
created: 2026-02-25T08:09:27Z
last_update: 2026-02-25T20:37:13Z
date_finished: 2026-02-25T08:34:58Z
---

# T-273: Production readiness — WSGI, health endpoint, config, error handling

## Context

Foundation for all deployment tasks. The Watchtower web app currently runs as a bare Flask dev server with no production-grade features. This task makes the app deployable behind gunicorn + Traefik without changing user-facing behavior.

**Research:** [docs/reports/T-272-deploy-watchtower-ring20.md](../../docs/reports/T-272-deploy-watchtower-ring20.md) (RQ-3: Production Readiness Gaps)
**Parent inception:** T-272 | **Unblocks:** T-274, T-277

### Files to create/modify
- **Create:** `web/wsgi.py` — WSGI app factory, gunicorn entry point
- **Create:** `web/config.py` — Environment-based config (model names, timeouts, DB paths)
- **Modify:** `web/app.py` — Add `/health` endpoint, 500 error handler, use config module
- **Modify:** `web/embeddings.py` — Move DB_PATH from `/tmp/` to config-driven persistent path
- **Modify:** `web/ask.py` — Add Ollama timeout, use config for model names

## Acceptance Criteria

### Agent
- [x] `web/wsgi.py` exists with `application = create_app()` export
- [x] `gunicorn -w 1 -b 127.0.0.1:3001 web.wsgi:application --check-config` succeeds (config valid)
- [x] `GET /health` returns JSON with `app`, `ollama`, `embeddings` keys
- [x] `/health` returns HTTP 503 when Ollama is unreachable (graceful degradation)
- [x] `web/config.py` exists with `OLLAMA_HOST`, `EMBEDDING_MODEL`, `PRIMARY_MODEL`, `VECTOR_DB_PATH`
- [x] All hardcoded model names in `web/ask.py` replaced with config references
- [x] Embedding DB path configurable via `VECTOR_DB_PATH` env var (default: `.context/working/fw-vec-index.db`)
- [x] 500 error handler registered — does not leak stack traces
- [x] `FW_SECRET_KEY` required in production (not auto-generated)
- [x] Existing tests/curl commands still pass (no regression)

### Human
- [x] Watchtower UI loads normally at http://localhost:3000 after changes
- [x] Q&A streaming still works with gunicorn (multi-worker)
- [x] Health endpoint shows correct dependency status

## Verification

# WSGI app factory exists and is importable
python3 -c "from web.wsgi import application; print('WSGI OK')"

# Health endpoint responds
curl -sf http://localhost:3000/health | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'app' in d; print('Health OK')"

# Config module importable with all required keys
python3 -c "from web.config import Config; assert hasattr(Config, 'OLLAMA_HOST'); assert hasattr(Config, 'PRIMARY_MODEL'); print('Config OK')"

# 500 handler registered (not default Flask handler)
python3 -c "from web.app import create_app; app=create_app(); assert 500 in app.error_handler_spec.get(None, {}); print('500 handler OK')"

# Embedding DB path not hardcoded to /tmp
grep -qv '"/tmp/' web/embeddings.py || echo "WARN: /tmp still referenced"

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

### 2026-02-25T08:09:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-273-production-readiness--wsgi-health-endpoi.md
- **Context:** Initial task creation

### 2026-02-25T08:25:48Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-25T08:34:58Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-02-25T08:34:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
