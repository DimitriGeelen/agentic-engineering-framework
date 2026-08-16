---
id: T-1590
name: "Multi-LLM routing Phase 4b — route-cache model tracking + circuit-breaker fallback"
description: >
  Phase 4b follow-up from T-1065 (deferred). Implement route-cache learning of model→task-type
  success rates and circuit-breaker fallback for model unavailability. Scope explicitly
  split from T-1065 per its Decisions block. Repo: TermLink (/opt/termlink) — changes
  in crates/termlink-hub/src/router.rs and crates/termlink-mcp/src/tools.rs. Related:
  T-1061, T-1065.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [termlink, multi-llm, routing]
components: []
related_tasks: [T-1061, T-1065]
created: 2026-04-28T18:46:58Z
last_update: '2026-08-16T22:24:37Z'
date_finished: 2026-04-28T18:57:26Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=1 (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1590: Multi-LLM routing Phase 4b — route-cache model tracking + circuit-breaker fallback

## Context

Phase 4b follow-up from T-1065 (DEFER). T-1065 shipped model passthrough (MCP `model` param + CLI flag + manifest recording). The two unchecked Agent ACs in T-1065 — route-cache model→task-type success-rate tracking, and circuit-breaker fallback for model unavailability — were explicitly scope-split per T-1065's `## Decisions` block ("Model passthrough first, routing intelligence later"). This task implements that intelligence.

**Repo:** TermLink (`/opt/termlink`) — changes in `crates/termlink-hub/src/router.rs` (route cache schema) + `crates/termlink-mcp/src/tools.rs` (circuit-breaker integration in dispatch).
**Depends on:** T-1065 (model passthrough must exist — done).
**Dispatch:** Execute in TermLink project via `fw termlink dispatch --project /opt/termlink`.

Research: `docs/reports/T-1061-termlink-governance-substrate.md`; T-1065 worker report at `/opt/termlink/docs/reports/T-906-model-param-dispatch.md`.

## Acceptance Criteria

### Agent
- [x] Route cache schema extended to track `(method, task_type, model)` → success/failure counters — `RouteCache::record_model_success/failure` + `ModelStats` (T-906 primitive, wired in via Phase 4b)
- [x] On dispatch completion, route cache learns: increment success counter on exit-0, failure counter otherwise — wired in `termlink_dispatch` outcome attribution (event with `payload.ok != false` = success)
- [x] Route lookup prefers the highest-success model for a given `(method, task_type)` when no explicit `model` is provided — `resolve_dispatch_model` consults `best_model_for(task_type)`
- [x] Circuit-breaker tracks per-model availability: N consecutive failures → mark model unavailable for cooldown window — `ModelCircuitBreaker` (T-903 primitive) records failures, transitions closed→open after threshold
- [x] On dispatch with explicit `model` param: if circuit is open, fall back to next model in fallback chain (default: opus → sonnet → haiku) and record fallback in dispatch manifest — `resolve_model` walks `DEFAULT_MODEL_FALLBACK`; result surfaces `model_requested`/`model_used`/`fallback_used` in dispatch JSON
- [x] Backward-compat: route cache without model column still loads; existing tests in `cargo test -p termlink-hub` still pass — `task_type: Option<String>`, `#[serde(default)]` on `model_stats`; 278 hub tests pass
- [x] New tests: 5 added in `termlink-mcp` (`dispatch_params_with_task_type`, `dispatch_params_default_task_type_none`, `resolve_dispatch_model_passthrough_when_breaker_closed`, `resolve_dispatch_model_uses_best_for_task_type`, `resolve_dispatch_model_no_inputs_returns_none`); pre-existing model-tracking + circuit-breaker tests verified passing (≥6 model tracking, ≥8 breaker transitions, ≥6 fallback chain)
- [x] All existing TermLink tests pass — 480 total (278 hub + 103 mcp unit + 99 mcp integration), 0 fail, cargo exit 0

## Verification

# Worker artefact exists (proof TermLink-side worker delivered)
test -f /opt/termlink/docs/reports/T-907-multi-llm-routing-phase-4b.md
# Cross-repo build verification via TermLink session — must show "Finished" marker (real check, no || fallback)
termlink interact framework-agent "cd /opt/termlink && CARGO_TARGET_DIR=/tmp/termlink-build cargo check -p termlink-hub -p termlink-mcp 2>&1 | tail -1" --json 2>/dev/null | grep -q '"marker_found": true'
termlink interact framework-agent "cd /opt/termlink && CARGO_TARGET_DIR=/tmp/termlink-build cargo check -p termlink-hub -p termlink-mcp 2>&1 | tail -1" --json 2>/dev/null | grep -q "Finished \`dev\`"

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

## Recommendation

**Recommendation:** GO

**Rationale:** All 8 Agent ACs verified satisfied via TermLink-side worker (T-907 dispatch, exit 0, 480/0/0 tests). Phase 4b is the wiring step — T-906 already shipped `RouteCache::record_model_*` and `best_model_for`; T-903 already shipped `ModelCircuitBreaker::resolve_model` + `DEFAULT_MODEL_FALLBACK`. This task wired those primitives into `termlink_dispatch`: model resolver, route-cache learning on dispatch completion, breaker integration, manifest surfacing of `model_requested`/`model_used`/`fallback_used`/`task_type`. Backward-compat preserved (`Option<String>` task_type, `#[serde(default)]` on model_stats). 5 new MCP-side tests, all 480 termlink-hub + termlink-mcp tests pass. No human ACs required (agent-owned task, no UI surface). Closes the T-1065 scope split.

**Evidence:**
- Worker report: `/opt/termlink/docs/reports/T-907-multi-llm-routing-phase-4b.md` (119 lines)
- Worker exit code: 0
- Tests: 480 pass, 0 fail (278 termlink-hub + 103 termlink-mcp unit + 99 mcp_integration)
- Files modified: `crates/termlink-mcp/src/tools.rs` (new `resolve_dispatch_model` helper, `task_type` param on `DispatchParams`, outcome attribution in `termlink_dispatch`)
- Verification commands pass: artefact exists, `cargo check -p termlink-hub -p termlink-mcp` returns "Finished `dev`" via TermLink interact
- Closes scope split from T-1065 `## Decisions` ("Model passthrough first, routing intelligence later") — Phase 4 arc complete

## Decisions

### 2026-04-28 — Wire vs re-implement
- **Chose:** Wire-only — reuse T-906 (route-cache `ModelStats` + `record_model_*` + `best_model_for`) and T-903 (`ModelCircuitBreaker` + `resolve_model` + `DEFAULT_MODEL_FALLBACK`) primitives.
- **Why:** Phase 4a/T-906/T-903 already delivered all the storage and logic primitives needed for Phase 4b. Re-implementing would duplicate code and risk schema drift. The gap was that nothing called these primitives from the `termlink_dispatch` tool — pure wiring.
- **Rejected:** Adding new schema (would have required migration) or new breaker abstraction (T-903's existing one already handles per-model state).

### 2026-04-28 — Manifest surfacing path
- **Chose:** Surface `model_requested`/`model_used`/`fallback_used`/`task_type` in the dispatch result JSON the orchestrator consumes per-call.
- **Why:** `dispatch-manifest.json` is owned by the `--isolate` worktree path in `termlink-cli`. The MCP dispatch path returns JSON directly — that's the manifest the orchestrator actually reads.
- **Rejected:** Mutating `dispatch-manifest.json` from MCP — would couple two independent dispatch paths.

## Updates

### 2026-04-28T18:46:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1590-multi-llm-routing-phase-4b--route-cache-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-78551513
- **Timestamp:** 2026-06-02T14:58:30Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `termlink interact framework-agent "cd /opt/termlink && CARGO_TARGET_DIR=/tmp/termlink-build cargo check -p termlink-hub -p termlink-mcp 2>&1 | tail -1" --json 2>/dev/null | grep -q '"marker_found": tr`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `termlink interact framework-agent "cd /opt/termlink && CARGO_TARGET_DIR=/tmp/termlink-build cargo check -p termlink-hub -p termlink-mcp 2>&1 | tail -1" --json 2>/dev/null | grep -q "Finished \`dev\`"`
### 2026-04-28T18:57:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
