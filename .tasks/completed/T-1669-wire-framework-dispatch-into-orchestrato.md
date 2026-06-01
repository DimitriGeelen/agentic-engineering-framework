---
id: T-1669
name: "Wire framework dispatch into orchestrator route_cache (Step 1-4: read+write+surface+demo)"
description: >
  Wire framework dispatch into orchestrator route_cache (Step 1-4: read+write+surface+demo)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/termlink/termlink.sh, tests/unit/test_termlink_dispatch_task_type.py, web/blueprints/orchestrator.py, web/templates/orchestrator.html]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-02T06:28:34Z
last_update: 2026-05-02T07:28:57Z
date_finished: 2026-05-02T07:17:52Z
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
- [x] Step 1: `_resolve_dispatch_model_and_fallback` reads route-cache.json before env-var fallback
- [x] Step 1: when route_cache has a hit for task_type, uses it; meta.json records source: "route_cache"
- [x] Step 1: when no hit, falls back to env-var; meta.json records source: "env-per-type" or "env-default"
- [x] Step 1: tests pin all three resolution paths (cache-hit / env-fallback / no-resolution)
- [x] Step 2: cmd_dispatch records outcome (success/failure) into route-cache.json after worker exits
- [x] Step 2: file write is atomic (tmpfile + rename) and idempotent on concurrent dispatches
- [x] Step 2: tests pin success and failure recording
- [x] Step 3: web/blueprints/orchestrator.py reads route-cache.json, exposes per-task-type stats
- [x] Step 3: /orchestrator template renders learned-prefs panel above recent-dispatches
- [x] Step 3: tests pin the route renders prefs from a seeded cache
- [x] Step 4: demo directory contains ≥5 meta.json captures, ≥1 cache snapshot, ≥1 page screenshot
- [x] Step 4: cache snapshot shows non-empty model_stats with at least 2 task_types
- [x] Step 4: `fw arc close orchestrator-rethink --demo docs/reports/orchestrator-rethink-demo --decision "shipped"` is accepted by the gate built in T-1668

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

## Recommendation

**Recommendation:** GO

**Rationale:** All 13 Agent ACs verified. Steps 1-4 shipped sequentially
with check-ins. The headline_mechanic for the orchestrator-rethink arc
fires end-to-end: 3 real `claude -p` workers spawned via
`fw termlink dispatch` without `--model`, route_cache picked 3 different
models per task_type (haiku/sonnet/opus from cache stats), workers
completed exit 0, outcomes recorded back to the same cache atomically,
operator-visible /orchestrator panel reflects the shift. Demo dir
satisfies the §ACD/G-062 `--demo` gate built in T-1668.

**Evidence:**
- Step 1 commit: `3e2108c23` — read path
- Step 2 commit: `f29246d97` — write path with flock + atomic rename
- Step 3 commit: `9cb103cc7` — Watchtower surface
- Step 4 directory: `docs/reports/orchestrator-rethink-demo/` —
  5 meta.json captures, 4 cache snapshots, /orchestrator screenshot,
  resolver-trace.txt, README narrative
- Tests: 22 across `test_route_cache_resolve.py` (10) and
  `test_route_cache_record.py` (12); 9 in
  `test_orchestrator_learned_routing.py`. All pass.
- Live wire-evidence: `meta-01-{build,design,inception}-dispatch.json`
  show `resolution_source: route_cache` against the seeded cache. The
  cache delta from `cache-02` to `cache-03` proves the worker run.sh
  callback fires.
- Gate acceptance: `_arc_validate_demo_path docs/reports/orchestrator-rethink-demo/README.md
  orchestrator-rethink .context/arcs/orchestrator-rethink.yaml`
  returns rc=0.

After GO, the arc is closeable with:

```bash
bin/fw arc close orchestrator-rethink \
    --demo docs/reports/orchestrator-rethink-demo/README.md \
    --decision "shipped — headline mechanic verified live across 3 task_types"
```

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

## Reviewer Verdict (v1.4)

- **Scan ID:** R-79368a5f
- **Timestamp:** 2026-05-02T07:17:54Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#8 (Agent)** — Step 3: web/blueprints/orchestrator.py reads route-cache.json, exposes per-task-type stats
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/orchestrator.py in: Step 3: web/blueprints/orchestrator.py reads route-cache.json, exposes per-task-type stats`

### 2026-05-02T07:17:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-05-02T07:28:57Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
