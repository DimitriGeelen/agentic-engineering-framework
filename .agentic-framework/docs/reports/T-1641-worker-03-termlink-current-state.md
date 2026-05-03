# T-1641 W03 — /opt/termlink Current State vs T-1061 Promises

**Probe basis:** live `termlink interact termlink-agent` against `/opt/termlink` (master branch). Citations are file:line in the TermLink repo.

## Summary

Code-complete in isolation, production wiring is a small fraction of T-1061's implication. Of 75 MCP tools, only **4** call `check_task_governance`; the other 71 (incl. mutators `termlink_inject`, `termlink_run`, `termlink_remote_exec`, `termlink_batch_exec`, `termlink_send`, `termlink_kv_set`) are ungated. `GovernanceSubscriber` (Layer 3) has **zero non-test callers** — `run_with_governance` is dead code. `task_type` is free-string, no enum. `best_model_for` has no min-sample guard (1/1 outranks 99/100). `DEFAULT_MODEL_FALLBACK = ["opus", "sonnet", "haiku"]`, hardcoded, no version pin, no human consultation. `PROMOTION_THRESHOLD = 5` hardcoded twice.

## Per-Claim Verification

| T-1061 Claim | Actual State | Cite | Verdict |
|---|---|---|---|
| Every cross-session MCP call is gated | 4/75 gate. `exec/spawn/interact/dispatch` only. `inject/run/remote_*/batch_*/send/kv_*` ungated. | tools.rs:1242, 1537, 1993, 2780 | **gap** (5%) |
| `task_type` enables specialist routing | Free-string. No enum/validation. Tag match `task-type:{tt}` then fall back to any candidate. | tools.rs:842; router.rs:1102, 1308–1309 | **gap** |
| Multi-LLM fallback chain | `DEFAULT_MODEL_FALLBACK = ["opus","sonnet","haiku"]`, hardcoded, no version pin | circuit_breaker.rs:114 | **policy missing** |
| Route cache learns best model per task type | `best_model_for`: highest success rate with `>0` samples; no min-sample guard, no recency. | route_cache.rs:244–259 | **gap** (naive) |
| Layer 3 governance subscriber attached | `run_with_governance` defined; only match in repo is its definition. No caller. | data_server.rs:60–72 | **missing** |
| Bypass promotes after `PROMOTION_THRESHOLD` | Const=5, hardcoded, duplicated in template_cache. | bypass.rs:37, 165; template_cache.rs:17 | **matches** (not configurable) |
| Persistence across restarts | `route-cache.json`, `bypass-registry.json` in `runtime_dir()`. Save: tools.rs:3058, router.rs:1419. Load: router.rs:1113, 1138. | route_cache.rs:294, 328; bypass.rs:103, 273 | **matches** (durability/versioning untested) |

## Top 5 Surprises

1. **71 MCP tools have no task_id gate.** `termlink_inject` (writes to PTY), `termlink_remote_exec` (runs commands on other machines), `termlink_batch_exec` (mass execution), `termlink_send`, `termlink_kv_set/del`, `termlink_signal`, `termlink_emit/broadcast` all bypass governance. The "structured governance substrate" lands on the 4 most common dispatch verbs and stops there.
2. **`run_with_governance` has no caller.** The Layer 3 mechanism T-1061 sold as the future-extension story is currently dead code. A session must opt in and nothing opts in. Governance frame (0x8) is theoretically defined and operationally never emitted.
3. **`task_type` is a free string.** No enum, no validator, no documented set. The framework's `workflow_type` (build/test/refactor/etc.) and TermLink's `task_type` are not connected. Misspell `"buld"` and routing silently falls back to any specialist.
4. **`best_model_for` is statistically broken at low N.** No floor on (successes+failures). First successful run on a model permanently outranks any model with even one failure until that model accumulates enough wins. Antifragility claim is undermined — the cache locks in lucky early routes.
5. **All thresholds are agent-defaulted, not human-consulted.** `PROMOTION_THRESHOLD=5`, fallback chain `[opus, sonnet, haiku]`, model-circuit-breaker thresholds — all hardcoded constants. None expose a config knob and none were on the human's review queue. Confirms T-1641's "policy unconsulted" diagnosis.

## Recommended Follow-Up Tasks (tag: `from-T-1641`)

1. **MCP governance coverage audit + extension** — classify the 71 ungated tools (read/mutator/cross-machine); gate every mutator. Scope: tools.rs structural.
2. **`task_type` canonical enum + validation** — typed enum aligned with framework `workflow_type`; reject unknowns at MCP boundary. Scope: schema change.
3. **`run_with_governance` wiring decision** — wire into `data_server::run` for all sessions (config-gated) OR delete the dead Layer 3 path and correct T-1061. Scope: design + wire.
4. **`best_model_for` min-sample guard** — add `MIN_SAMPLES` + Wilson lower-bound; consult human on threshold. Scope: ~30 lines + tests.
5. **Routing-policy config surface + human consultation** — extract `PROMOTION_THRESHOLD`, fallback chain, CB thresholds to config; raise policy questions via `fw task review`. Scope: config + review entry.
6. **CI guard against ungated-MCP-tool drift** — snapshot test of gated-tool list; CI fails when a new mutator skips `check_task_governance`. Scope: small test, high leverage.
