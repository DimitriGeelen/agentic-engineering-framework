# T-1061 Orchestrator Arc — Integration Assessment

**Date:** 2026-05-01
**Author:** Claude Code session (framework anchor, /opt/999-Agentic-Engineering-Framework)
**Scope:** Verify that the five phases of T-1061 (T-1062, T-1063, T-1064, T-1065, T-1066) compose end-to-end before handing the four open parents to human review.
**Verification host:** termlink-agent session at /opt/termlink (TermLink 0.9.1640).

## Summary

The arc composes. T-1063 / T-1064 / T-1065 are wired together inside `termlink_dispatch` as a single pipeline (gate → route → resolve model → record outcome → persist). T-1062 is a pure read-side consumer of session metadata and aligns naturally because T-1063's task_id surfaces as a session tag. T-1066's governance subscriber is opt-in and intentionally outside the MCP composition; that is a design decision recorded in the AC, not an integration gap.

Cross-repo build + test verification on /opt/termlink: clean.

| Check | Result |
|-------|--------|
| `cargo check -p termlink-{hub,mcp,session,protocol}` | Exit 0 (cached, 0.11s) |
| `cargo test --lib` on those four crates | Exit 0 (all pass; visible counts: 100, 316) |
| Worker artefacts (T-903, T-905, T-906, T-907) | All present in `/opt/termlink/docs/reports/` |

## How the layers compose

The integration lives in `crates/termlink-mcp/src/tools.rs::termlink_dispatch` (lines 2780–3080 as of the verification snapshot).

### Pipeline through the four code paths

```
termlink_dispatch (MCP entry)
  ├─ [T-1063]  check_task_governance(task_id, "termlink_dispatch")     line 2780
  │            → returns Err if TERMLINK_TASK_GOVERNANCE=1 and task_id missing
  │            → task_id then propagates to session tags as task:T-XXX  line 2824
  │
  ├─ [T-1064]  task_type = p.task_type.clone()                          line 2811
  │            → flows into resolve_dispatch_model
  │            → after collection, model+task_type recorded together    line 3043
  │
  ├─ [T-1065]  resolve_dispatch_model(requested, task_type, &cache)     line 2815
  │            → explicit model      → breaker.resolve_model + chain
  │            → no model + task_type → cache.best_model_for(task_type)
  │            → neither              → (None, false), no learning
  │
  ├─ spawn workers with TERMLINK_MODEL=effective_model
  │
  └─ Outcome attribution (closes the learning loop):
       success/failure derived from payload "ok" field
       → route_cache.record_model_success/failure(m, tt)                 line 3043+
       → ModelCircuitBreaker.record_success/failure(m)
       → route_cache.save() (best-effort, errors swallowed)

Result JSON surfaces: model_requested, model_used, fallback_used, task_type
```

### Composition observations

1. **T-1063 → T-1064 → T-1065 is one pipeline.** All three touch the same `DispatchParams` struct; the gate/route/resolve sequence is co-located in `termlink_dispatch`. This is the integration point — there is no parallel path.
2. **task_id propagation works two ways.** Mandatory entry gate (T-1063), then re-emitted as a session tag for observability. T-1062 (WezTerm) reads those tags via `termlink list --json` — that is the consumer side of the same string. No additional wiring needed.
3. **The cache key is composite (`method::task_type`).** Adequate now; a future `RoutingKey` newtype is captured as **T-1636** (horizon: later) so the string-concat approach does not become entrenched.
4. **Model fallback is structural.** `DEFAULT_MODEL_FALLBACK` const + breaker resolve. Cost is **not** part of the weighting — captured as **T-1637** (horizon: later).
5. **T-1066 is intentionally out-of-band.** The governance subscriber attaches via `broadcast::Receiver::resubscribe()` on the session's Output channel; it does not gate dispatch. That is the documented design: post-hoc detection, opt-in, not "deterministic." Composition is by **observation**, not by **control flow** — and that is what the AC asks for.

## Phase-by-phase status

| Phase | Task | Status | Evidence |
|-------|------|--------|----------|
| 1 — WezTerm chrome | T-1062 | Agent ACs done, awaiting Human [REVIEW] | `plugins/wezterm/termlink-chrome.lua` + README; consumer of `termlink list --json` only — zero TermLink-side change |
| 2 — MCP governance | T-1063 | **Completed** | `check_task_governance` wired into 4 MCP tools; reachable from any MCP-capable agent |
| 3 — Orchestrator routing | T-1064 | Agent ACs done, awaiting Human [REVIEW] | `task_type` field; tag convention `task-type:<type>`; 155 hub tests pass; backward-compat test pinned |
| 4 — Multi-LLM | T-1065 | Agent ACs done (scope-split closed by T-1590), awaiting Human [REVIEW] | `model` param + `resolve_dispatch_model` + `DEFAULT_MODEL_FALLBACK` chain + `best_model_for(task_type)` learning |
| 5 — Data plane gov | T-1066 | Agent ACs done, awaiting Human [REVIEW] | Frame type 0x8 added; `governance_subscriber.rs` non-blocking via broadcast.resubscribe + bounded mpsc + try_send |
| 6 — PTY pre-hook | — | **Rejected** in T-1061 inception (deadlock risk) | n/a |

## Captured follow-ups (this session, horizon: later)

These were buried in "Agent supplementary review" notes inside the parent ACs and would be lost when those parents close. Hoisted to standalone tasks.

- **T-1636** (refactor) — Composite cache key → `RoutingKey` newtype before more dimensions land. Origin: T-1064 review.
- **T-1637** (build) — Cost-aware learning in `RouteCache` (weight by cost-per-call). Origin: T-1065 review.
- **T-1638** (refactor) — Extract `strip_ansi_codes` from `handler.rs` and `governance_subscriber.rs` to a shared module. Origin: T-1066 review.
- **T-1639** (test) — Throughput benchmark for governance subscriber to harden the non-blocking claim. Origin: T-1066 review.

All four are cross-repo (lives in `/opt/termlink`), to dispatch via `fw termlink dispatch --project /opt/termlink` when the human picks them up.

## Recommendation

**The arc is integration-clean and ready for human review.** All four open parents (T-1062, T-1064, T-1065, T-1066) are GO. No new gaps surfaced during cross-repo build/test verification. The four follow-ups captured today are future work, not ship-blockers.

Reviewing in this order will surface the architecture most efficiently:

1. **T-1063** (already completed — context only) — read the MCP governance contract.
2. **T-1064** — task_type routing in the orchestrator chain.
3. **T-1065** — multi-LLM model selection layered on top.
4. **T-1066** — data plane subscriber as an *observation* layer, separate from the MCP pipeline.
5. **T-1062** — WezTerm chrome as a read-side consumer of all of the above.

Watchtower review URLs are surfaced in `LATEST.md` and via `fw task review T-XXXX`.

## Verification commands re-runnable from this anchor

```bash
# Build (cached, fast):
termlink interact termlink-agent "CARGO_TARGET_DIR=/tmp/tl-build cargo check \
  -p termlink-hub -p termlink-mcp -p termlink-session -p termlink-protocol \
  --message-format short" --json --timeout 300

# Tests:
termlink interact termlink-agent "CARGO_TARGET_DIR=/tmp/tl-build cargo test \
  -p termlink-hub -p termlink-mcp -p termlink-session -p termlink-protocol \
  --lib --quiet" --json --timeout 600
```

Both ran clean during this session.
