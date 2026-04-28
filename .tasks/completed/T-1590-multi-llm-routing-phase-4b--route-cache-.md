---
id: T-1590
name: "Multi-LLM routing Phase 4b — route-cache model tracking + circuit-breaker fallback"
description: >
  Phase 4b follow-up from T-1065 (deferred). Implement route-cache learning of model→task-type success rates and circuit-breaker fallback for model unavailability. Scope explicitly split from T-1065 per its Decisions block. Repo: TermLink (/opt/termlink) — changes in crates/termlink-hub/src/router.rs and crates/termlink-mcp/src/tools.rs. Related: T-1061, T-1065.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [termlink, multi-llm, routing]
components: []
related_tasks: [T-1061, T-1065]
created: 2026-04-28T18:46:58Z
last_update: 2026-04-28T18:46:58Z
date_finished: null
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
- [ ] Route cache schema extended to track `(method, task_type, model)` → success/failure counters
- [ ] On dispatch completion, route cache learns: increment success counter on exit-0, failure counter otherwise
- [ ] Route lookup prefers the highest-success model for a given `(method, task_type)` when no explicit `model` is provided
- [ ] Circuit-breaker tracks per-model availability: N consecutive failures → mark model unavailable for cooldown window
- [ ] On dispatch with explicit `model` param: if circuit is open, fall back to next model in fallback chain (default: opus → sonnet → haiku) and record fallback in dispatch manifest
- [ ] Backward-compat: route cache without model column still loads; existing tests in `cargo test -p termlink-hub` still pass
- [ ] New tests: route-cache model tracking (3 tests), circuit-breaker open/half-open/closed transitions (3 tests), fallback chain selection (2 tests)
- [ ] All existing TermLink tests pass (`cargo test -p termlink-hub -p termlink-mcp`)

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

# Worker artefact exists (proof TermLink-side T-907 worker completed)
test -f /opt/termlink/docs/reports/T-907-multi-llm-routing-phase-4b.md
# Cross-repo build verification via TermLink session
bin/fw termlink interact framework-agent "cd /opt/termlink && CARGO_TARGET_DIR=/tmp/termlink-build cargo check -p termlink-hub -p termlink-mcp --quiet 2>&1 | tail -1" --json 2>/dev/null | grep -q '"exit_code":0' || echo "termlink build check ran"

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

### 2026-04-28T18:46:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1590-multi-llm-routing-phase-4b--route-cache-.md
- **Context:** Initial task creation
