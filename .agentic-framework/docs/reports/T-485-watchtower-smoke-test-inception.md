# T-485: Watchtower Smoke Test Suite — Inception Research

**Status:** Research complete, awaiting GO/NO-GO
**Date:** 2026-03-14
**Trigger:** macOS field testing — errors on fresh project installs

## Problem Statement

Watchtower has 69 endpoints across 18 blueprints. There's no post-startup validation that pages actually work — a 200 on `/health` doesn't mean `/tasks` or `/fabric` render correctly. Fresh project installs on macOS exposed errors (Python 3.9 type hints, missing data) that only surface when you click through pages manually.

## Spike Findings

### Spike 1: Endpoint Map (69 endpoints)
- **26 template routes** (GET, render HTML pages)
- **28 form/API routes** (POST, return fragments or JSON)
- **10 REST API routes** (JSON)
- **2 streaming/SSE endpoints**
- **3 error handlers**

Key insight: 8 routes always work on empty projects (/, /health, /settings, /directives, /enforcement, /project, /search, /api/v1/). The rest depend on tasks, context files, or fabric data existing.

### Spike 2: Evergreen Strategy
Three options evaluated:
- **Option A: Runtime route discovery** — query Flask's `app.url_map`, test each route for 200. Zero maintenance. No content assertions. ~2 hours.
- **Option B: Route manifest YAML** — explicit route list with content markers. Manual maintenance. Deep validation. ~4 hours.
- **Option C: Hybrid** — auto-discovery for existence, manifest for content. Best coverage, most complexity. ~5 hours.

**Recommendation:** Option C (hybrid) — phased. Start with A (immediate, zero maintenance), layer B for critical routes.

### Spike 3: Integration Points
Four integration surfaces identified:
1. **`fw serve` post-startup** — extend existing health poll (watchtower.sh:169-203) to run smoke tests before reporting success
2. **`fw doctor`** — add "Watchtower endpoints" section (pattern: modular checks with OK/FAIL output)
3. **`fw audit` deployment section** — already checks `/health`; extend to all critical endpoints
4. **BATS tests in CI** — `tests/integration/watchtower_smoke.bats`

**Recommendation:** Primary = `fw doctor` section (dev-time feedback) + `fw audit` deployment gate. Secondary = BATS for CI.

## Existing Assets
- `web/test_app.py`: 60+ pytest tests, but routes are hardcoded in parametrize lists
- `/health` endpoint: Returns JSON with app/ollama/embeddings status
- Deployment audit already calls `curl /health`

## Proposed Architecture

### Phase 1: Runtime smoke test script (build task)
Create `web/smoke_test.py` that:
1. Imports the Flask app, iterates `app.url_map`
2. GETs every parameterless route, asserts 200
3. For critical routes (/, /tasks, /search, /fabric, /quality), checks content markers
4. Returns JSON: `{"passed": N, "failed": N, "errors": [...]}`

### Phase 2: Framework integration (build task)
1. `fw doctor` calls smoke test when Watchtower is running
2. `fw audit` deployment section runs smoke test as gate
3. `bin/watchtower.sh start --smoke` runs after health check passes

### Phase 3: Evergreen manifest (future)
1. Route manifest YAML for deep content assertions
2. Audit warns when manifest is stale (new routes not in manifest)
3. Fabric drift detection extended to route coverage

## Go/No-Go Criteria
- **GO if:** Phase 1 can be implemented in <4 hours, integrates with existing test_app.py patterns
- **NO-GO if:** Flask test client can't reliably test routes without a running server (requires subprocess management)

## Assumptions
- A1: Flask test client can exercise all routes without a live server (validated: test_app.py already does this)
- A2: Content markers from Spike 1 are stable enough for assertions (templates change infrequently)
- A3: `fw doctor` and `fw audit` are the right integration points (no new CLI commands needed)
