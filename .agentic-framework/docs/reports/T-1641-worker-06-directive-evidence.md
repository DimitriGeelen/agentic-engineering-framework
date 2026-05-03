# T-1641 W06 — Constitutional Directive Evidence Audit

**Scope:** T-1061 directive claims (137-176) — Code? Test? Operational? Probes: /opt/termlink + `/var/lib/termlink/` + `/tmp/tl-hub-*`.

## Summary

The arc shipped **mechanism, not behaviour**. Every claim has code and unit tests; operational evidence is thin to absent. Bypass registry has never promoted a real command — only ephemeral `/tmp/tl-hub-*` test fixtures with `success_count=1` for `termlink.ping`; the production hub has no `bypass-registry.json`. Circuit breaker is wired into `orchestrator.route`, but `orchestrator.route` fired **0×** in 71,275 production RPC events — breaker never opened. Governance frame 0x8 protocol + 316-line subscriber + 7 tests exist, but `run_with_governance` has **zero non-test callers** — no CLI flag, no session main path. "Complete audit trail" is real (`rpc-audit.jsonl` 3.7 MB / 71K events) but records only `method+peer`, and since `orchestrator.route` is unused the audit is vacuously complete over an empty set.

## Per-claim evidence

| Directive | Claim | Code? | Test? | Operational? |
|---|---|---|---|---|
| Antifragility | Bypass promotes after 5 successes (143) | `bypass.rs:37,165` `PROMOTION_THRESHOLD=5` | 17 unit tests | **No.** Production hub has no bypass file; all live in `/tmp/tl-hub-*` test dirs, max success=1, never crosses threshold. |
| Antifragility | Circuit breaker prevents cascade (144) | `circuit_breaker.rs` (425 ln) wired at `router.rs:1366,1378` | 17 unit tests | **No.** `orchestrator.route` count = 0 in 71K audit events → breaker never exercised on real specialists. |
| Antifragility | Session continuity across crashes (145) | `/var/lib/termlink/sessions/*.sock.data` persists | indirect (T-179) | Partial — persists but not T-1061-specific. |
| Reliability | MCP structural enforcement (153) | `task_id` param exists; no `.tasks/active/` check | param tests | Unverified (W03/W08). |
| Reliability | Complete audit trail via hub (154) | `rpc_audit.rs` (674 ln) at `server.rs:597` | 24 tests | Partial. 3.7 MB / 71,275 lines exists. **But** logs only `{ts, method, peer_addr}` — not route/breaker/governance decisions. `orchestrator.route`=0 → "every route decision" is vacuous. |
| Reliability | Dual-channel separation (155) | control + data planes | protocol tests | Yes. |
| Usability | WezTerm task-aware chrome (162) | none | none | **Never started.** |
| Usability | Dispatch as multi-agent UX (166) | `fw termlink dispatch` | level9-dispatch-collect.sh | Yes — 21 active workers in `termlink list` now. |
| Portability | Agent-agnostic via MCP (173) | `termlink-mcp`, 40+ tools | yes | Partial — only Claude Code observed. |
| Portability | Multi-LLM routing (175) | `resolve_model` + opus→sonnet→haiku in `circuit_breaker.rs:113,164`; wired into `tools.rs:859,3044,3061` (dispatch) | `model_resolve_fallback_*` tests | **None.** No model-failover event in operational data; no audit field for it. |
| (Layer 3) | Governance frame 0x8 (122) | `protocol/data.rs:17`, `protocol/governance.rs`, `session/governance_subscriber.rs` (316 ln), `data_server.rs:60 run_with_governance` | 7 unit tests | **No.** `run_with_governance` has **0 non-test callers**. Frame never emitted in real use. |

## Top 3 aspirational claims

1. **Bypass registry as antifragile learning** — implemented & tested but never promoted in real operation. `find /var/lib/termlink -name "bypass*"` → empty. Currently a unit-test property only.
2. **Governance frame 0x8 on the wire** — frame type, payload struct, subscriber, tests exist; **no production caller wires `run_with_governance`**. Shipped-as-dead-code.
3. **Complete audit trail via hub** — log is real and large but (a) captures only `method+peer`, not route/breaker/governance decisions, (b) `orchestrator.route`=0 → audit covers an empty set for the headline claim.

Adjacent partial: **circuit breaker** is wired but never exercised on the route path (no routes ⇒ no failures ⇒ no opens).

## Follow-ups (`from-T-1641`)

1. **Bypass promotion smoke** — drive `orchestrator.route` 5× against a tagged specialist; confirm a *persistent* bypass path (not `/tmp`); add to `tests/e2e/arc-suite.sh`.
2. **Wire `run_with_governance`** — `termlink spawn --governance-config <file>`, ship a default pattern, smoke test asserting a 0x8 frame on the wire.
3. **Audit schema extension** — for `orchestrator.route`: add `outcome`, `bypass_hit`, `cache_hit`, `breaker_state`, `chosen_specialist`, `model_resolved`. Only then is "complete audit trail" verifiable.
4. **Model-failover smoke** — fault-inject opus, confirm `resolve_model` falls to sonnet, capture audit evidence.
5. **Drift-defense audit** (handoff to W10) — monthly job asserting `orchestrator.route` > 0, ≥1 bypass entry, ≥1 Governance frame; if any drops to 0, file in `concerns.yaml`.

Closes the gap between *mechanism* and *behaviour* — what T-1641 was filed to measure.
