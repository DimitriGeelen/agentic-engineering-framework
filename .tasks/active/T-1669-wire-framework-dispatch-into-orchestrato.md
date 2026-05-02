---
id: T-1669
name: "Wire framework dispatch into orchestrator route_cache (Step 1-4: read+write+surface+demo)"
description: >
  Wire framework dispatch into orchestrator route_cache (Step 1-4: read+write+surface+demo)

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-02T06:28:34Z
last_update: 2026-05-02T06:28:34Z
date_finished: null
---

# T-1669: Wire framework dispatch into orchestrator route_cache (Step 1-4: read+write+surface+demo)

## Context

Wires the actual orchestration the orchestrator-rethink arc was named for.
Today the framework dispatch path (`agents/termlink/termlink.sh:_resolve_dispatch_model_and_fallback`)
does env-var lookup only; the route_cache learning that T-1064/T-1065
shipped in /opt/termlink is consulted by the MCP path but bypassed by the
framework. This task wires both paths into the same route_cache file
(`${TERMLINK_RUNTIME_DIR:-/var/lib/termlink}/route-cache.json`).

Steps (paced, with check-in between each):
- Step 1 — Read path: `_resolve_dispatch_model_and_fallback` queries route_cache
  via JSON file read, picks model with best success_rate per task_type,
  falls back to env-var on miss. Source recorded in meta.json.
- Step 2 — Write path: After worker exits in cmd_dispatch, increment
  model_stats[model:task_type].successes (exit 0) or .failures (exit ≠ 0).
- Step 3 — Watchtower /orchestrator surfaces learned per-task-type prefs.
- Step 4 — Demo: 5 dispatches across task_types, capture meta.json sequence
  + cache snapshots + page screenshots → docs/reports/orchestrator-rethink-demo/

Authority: T-1667 inception research + user authorisation 2026-05-02.

## Acceptance Criteria

### Agent
- [ ] Step 1: `_resolve_dispatch_model_and_fallback` reads route-cache.json before env-var fallback
- [ ] Step 1: when route_cache has a hit for task_type, uses it; meta.json records source: "route_cache"
- [ ] Step 1: when no hit, falls back to env-var; meta.json records source: "env-per-type" or "env-default"
- [ ] Step 1: tests pin all three resolution paths (cache-hit / env-fallback / no-resolution)
- [ ] Step 2: cmd_dispatch records outcome (success/failure) into route-cache.json after worker exits
- [ ] Step 2: file write is atomic (tmpfile + rename) and idempotent on concurrent dispatches
- [ ] Step 2: tests pin success and failure recording
- [ ] Step 3: web/blueprints/orchestrator.py reads route-cache.json, exposes per-task-type stats
- [ ] Step 3: /orchestrator template renders learned-prefs panel above recent-dispatches
- [ ] Step 3: tests pin the route renders prefs from a seeded cache
- [ ] Step 4: demo directory contains ≥5 meta.json captures, ≥1 cache snapshot, ≥1 page screenshot
- [ ] Step 4: cache snapshot shows non-empty model_stats with at least 2 task_types
- [ ] Step 4: `fw arc close orchestrator-rethink --demo docs/reports/orchestrator-rethink-demo --decision "shipped"` is accepted by the gate built in T-1668

### Human

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bash -n agents/termlink/termlink.sh
pytest tests/unit/test_route_cache_resolve.py tests/unit/test_route_cache_record.py -q
test -f docs/reports/orchestrator-rethink-demo/cache-final.json
test "$(ls docs/reports/orchestrator-rethink-demo/meta-*.json | wc -l)" -ge 5

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

### 2026-05-02T06:28:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1669-wire-framework-dispatch-into-orchestrato.md
- **Context:** Initial task creation
