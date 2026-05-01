# T-1641 Worker 01 — Inception Coverage Gap

Cross-references T-1061 (TermLink Governance Substrate) promises against what each child phase task (T-1062–T-1066) actually shipped.

## Summary

T-1061 painted a 3-layer governance substrate (MCP + hub orchestrator + data plane) backed by 5 phases. The phases shipped the **scaffolding** of every layer — task-aware tags, opt-in MCP governance, task-type routing, model passthrough + success tracking, Governance frame 0x8 + opt-in subscriber. They did **not** ship: scope validation, concurrency limits, cost-aware model selection, default-on enforcement, deployed subscribers, or any framework-side wiring that makes the substrate active in daily operation. The most consequential gap is conceptual: T-1061's MCP governance promise was three checks (existence, scope, concurrency); only the first shipped. The second-most-consequential is policy: every routing rule (task_types, model fallback chain, bypass thresholds, governance default) was hard-coded by code authors without human consultation. The third is deployment: nothing attaches the data plane subscriber, nothing forces `TERMLINK_TASK_GOVERNANCE=1`, nothing in /opt/999 calls the new routing primitives.

## Per-Phase Coverage

| Phase | T-1061 Promise (quoted) | Shipped (from AC + Recommendation) | Gap |
|-------|------------------------|-------------------------------------|-----|
| **1 — WezTerm chrome (T-1062)** | "Multi-pane task governance UI", "Context fabric visualization", "Dispatch system as multi-agent UX" | Lua plugin (236 lines) querying `termlink list --json`, displays task ID/status in tab/status bar; README; fabric registered. **Never visually verified** (no Lua/WezTerm on anchor). | Multi-pane governance UI not built. Context-fabric viz not built. Dispatch-as-multi-agent-UX not built. Single-status-bar-readout only. |
| **2 — MCP governance (T-1063)** | "Before `termlink_exec`, check if a task exists. Before `termlink_spawn`, validate against task scope. Before `termlink_dispatch`, enforce concurrency limits." | Optional `task_id` parameter on 4 tools (exec/spawn/interact/dispatch); opt-in via `TERMLINK_TASK_GOVERNANCE=1`; propagates to session tags. 16 tests. | **Scope validation: NOT shipped** (no spawn-against-task-scope check). **Concurrency limits: NOT shipped.** Existence-only. Default OFF — framework doesn't set the env var, so G-011/G-015/G-017 unmoved in practice. |
| **3 — Orchestrator routing (T-1064)** | Extend `orchestrator.route` "with task-type-based routing **and model-aware specialist selection**" | `task_type` Option<String>, composite cache key `method::task_type`, bypass registry considers task_type, **preference-not-exclusion** sort. 3 tests. | **Model-aware specialist selection conflated and dropped** — Phase 3 shipped only the task-type prong; model selection got punted into Phase 4 as "passthrough" not "specialist selection". Agent's own review (T-1064 lines 54-55) flags ambiguity on whether `task_type` propagates to discovery filters. |
| **4 — Multi-LLM (T-1065)** | "Task-aware model selection... Route cache learns which models succeed for which task types... Circuit breaker provides automatic fallback... Routing routine tasks to Haiku could reduce costs 60-80%." | 4a (T-906): `model` param passthrough on `termlink_dispatch`. 4b (T-1590): `record_model_success/failure`, `best_model_for`, `ModelCircuitBreaker::resolve_model`, hard-coded `DEFAULT_MODEL_FALLBACK` (opus→sonnet→haiku). 5 tests. | **Cost-awareness NOT shipped** (acknowledged in T-1065 review: "cost is implicit in user choice"). The 60-80% cost-reduction value-prop is unrealized — system never auto-routes routine tasks to Haiku; it only fails over on circuit-open. Fallback chain is hard-coded const, not configurable, not consulted with human. |
| **5 — Data plane (T-1066)** | "Governance-aware data plane subscriber could: receive Output frames → parse for patterns → emit Governance frames... post-hoc, not blocking" | Frame type 0x8, opt-in subscriber via `broadcast::resubscribe`, bounded mpsc, regex pattern match, ANSI strip, 9 tests. | **Subscriber not attached anywhere by default** — AC #4 explicitly states "opt-in (not attached by default)". No patterns wired in framework. No throughput benchmark. ANSI strip duplicated (drift risk). Effectively dormant code. |

## Top 5 Coverage Gaps

1. **MCP governance is one-third of what was promised.** T-1061 §"Layer 1" listed three structured checks (existence, scope, concurrency); only existence-via-task_id-tag shipped. Scope ("validate against task scope") and concurrency ("enforce limits") are absent. The "G-011 ceases to exist at this layer" claim from T-1061 is doubly compromised: half the checks are missing, AND the half that shipped is opt-in.

2. **No end-to-end orchestration has been observed.** Across all 5 phases, no task records: a routed call dispatched to a task-typed specialist, a fallback-chain cycle on circuit-open, or a Governance frame emitted on the wire. T-1064/T-1065/T-1066 verification = `cargo check` + worker-report file existence. This is exactly the user's pushback (T-1641 line 25).

3. **Routing-rules policy was silently defaulted, never consulted.** The `DEFAULT_MODEL_FALLBACK` chain (opus→sonnet→haiku), `PROMOTION_THRESHOLD=5`, `task-type:<type>` tag convention, and `TERMLINK_TASK_GOVERNANCE` default-off were all code-author decisions. T-1061's design flagged these as policy ("which models for which task types", "concurrency limits"), but no consultation step exists in any phase task.

4. **The framework doesn't USE the substrate.** /opt/999 has zero call-sites that pass `task_id`, `task_type`, or `model` parameters — features sit in /opt/termlink, untouched by the framework that motivated them. The substrate is shipped but unloaded.

5. **Cost-aware routing — the headline value-prop — is unshipped.** T-1061 quantified the value at 60-80% cost reduction by routing routine tasks to Haiku. Phase 4b shipped success-rate tracking only; `best_model_for` returns the highest-success model regardless of cost. T-1637 captures this but is on `horizon:later`.

## Recommended Follow-Up Tasks

| # | Scope (1 line) | Tag |
|---|----------------|-----|
| F1 | Live E2E orchestration smoke — spawn 2 task-typed specialists, route call, observe Governance frame, attach evidence | from-T-1641 |
| F2 | Human consultation arc on routing-rules policy (task_types, model fallback, governance default, concurrency limits, bypass thresholds) | from-T-1641 |
| F3 | MCP governance v2 — ship the missing two checks: scope validation on `termlink_spawn`, concurrency limits on `termlink_dispatch` | from-T-1641, from-T-1063 |
| F4 | Framework-side wiring — make /opt/999 actually call the substrate (set `TERMLINK_TASK_GOVERNANCE=1` by default in dispatch wrapper, propagate `task_type` from focus.yaml, propagate `task_id` automatically) | from-T-1641 |
| F5 | Data plane subscriber default deployment — bundle baseline pattern set, attach subscriber automatically when MCP governance is on | from-T-1641, from-T-1066 |
| F6 | Phase 1b — multi-pane task governance UI + context-fabric viz (the unscoped half of T-1062's promise) | from-T-1641, from-T-1062 |
| F7 | Drift defenses — MCP task_id-enforcement test, fallback-chain regression test, Governance-frame smoke test (otherwise rot is silent) | from-T-1641 |
| F8 | Cost-weighted `best_model_for` — promote T-1637 from later → now once F2 confirms cost-aware routing is desired | from-T-1641, from-T-1065 |

