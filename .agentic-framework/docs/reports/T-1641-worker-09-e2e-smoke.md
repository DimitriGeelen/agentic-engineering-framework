# T-1641 / W09 — End-to-End Orchestration Smoke Test

**Worker:** W09 (live-evidence) · **Date:** 2026-05-01 · **Hub:** local `/var/lib/termlink/hub.sock` (PID 103255)

## Summary

The arc **does orchestrate**: `orchestrator.route` resolves selectors, prefers `task-type:<X>` tagged specialists, caches per `method::task_type`, falls back when the picked specialist dies, and tracks success/fail toward Tier-3 bypass promotion. Two friction points: (1) `orchestrator.route` is **not exposed on session sockets** — `termlink send <session> orchestrator.route` returns `-32601 Method not found`; you must speak JSON-RPC straight to `hub.sock` (`nc -U`) or via the MCP `dispatch` wrapper. (2) Selector `{roles:["test-specialist"]}` did **not** match sessions whose runtime `roles: []` even though tags carried `role:test-specialist` — silent split between session.roles and `role:` tags. Mechanics real; surface area undocumented for outside-MCP callers.

## Step-by-step transcript

| # | Command | Output (abridged) | Verdict |
|---|---------|-------------------|---------|
| 1 | `termlink list --json` | framework-agent + termlink-agent ready | ✅ baseline |
| 2a | `termlink send termlink-agent orchestrator.route ...` | `error: Method not found` | ⚠️ session sockets DON'T expose orchestrator.* |
| 2b | `termlink spawn spec-build --tags "task-type:build,role:test-specialist"` | `tl-7anazhyi ready` | ✅ |
| 2c | `termlink spawn spec-test --tags "task-type:test,role:test-specialist"` | `tl-emrjef6j ready` | ✅ |
| 3 | hub RPC: `task_type:"build"`, selector tag `role:test-specialist` | `routed_to: spec-build, candidates: 2` | ✅ matches T-1061 promise |
| 4 | same with `task_type:"test"` | `routed_to: spec-test, candidates: 2` | ✅ task-type bias works |
| 5 | same, NO `task_type` | `routed_to: spec-build, candidates: 2` (first match) | ✅ method-only fallback |
| 6 | `termlink signal spec-build SIGTERM`; re-route `task_type=build` | `routed_to: spec-test, candidates: 1` | ✅ failover; no error surfaced |
| 7a | `cat route-cache.json` | 3 entries: `query.capabilities` → spec-build; `::build` → spec-test (rewritten); `::test` → spec-test | ✅ cache keyed by `method::task_type` |
| 7b | `cat bypass-registry.json` | candidates with success/fail; promotion ≈ 5 successes | ✅ bypass machinery alive |
| 7c | re-route `task_type=test` | response: `"cached_route":true` | ✅ cache hit path proven |
| 7d | `orchestrator.bypass_status` | `promotion_candidates` w/ `remaining: 3-4` | ✅ Tier-3 promotion scoreboard exists |
| 8 | `signal spec-test SIGTERM; clean` | session removed | ✅ cleanup |

Selector with `roles:["test-specialist"]` (instead of `tags:["role:test-specialist"]`) returned `No sessions match the selector` — see surprise #2.

## Top 3 surprises

1. **`orchestrator.route` is hub-only RPC.** Session sockets reject it. The MCP `dispatch` tool wraps it; bare framework callers must `nc -U /var/lib/termlink/hub.sock`. The `termlink` CLI has no `hub send` verb — every consumer rolls its own JSON-RPC framing. Strong candidate for "what got lost": inception promised orchestration; only ergonomic surface is MCP.
2. **Selector role-vs-tag split.** `{tags:["role:X"]}` matches; `{roles:["X"]}` does not (`session.roles: []` even when spawned with `role:X` tag). Either the spawn flow doesn't promote `role:` tags to roles, or the matcher reads only session.tags. Concretizes W08's routing-rules concern: nobody documented which side is canonical.
3. **No breaker signal on the wire.** Killing spec-build → re-route silently picked spec-test with `candidates: 1`. The cache entry was *rewritten*, not invalidated; response payload has no `fallback_from`, `circuit_open`, or `route_health`. Degradation invisible to the requester. (The `bypass-registry.json` tracks fail_count, but the wire response doesn't.)

Bonus: caches + bypass registry live in `/var/lib/termlink/` — **per-host, not per-user, not per-project**. No tenant isolation on a shared host.

## Recommended follow-up tasks (tag: from-T-1641)

1. **`fw termlink route` / `termlink hub send` CLI verb** — wrap JSON-RPC framing so callers don't need `nc -U`. Without it the arc is MCP-only; portability claim only half-true.
2. **E2E smoke harness in /opt/termlink CI** — codify exactly this test (spawn 2, route 3 ways, kill one, re-route, assert cache) as an integration test gated on `cargo test --features integration`. Today: zero coverage of the live wire path.
3. **Selector role-source contract** — decide & document: does `{roles:[...]}` match `session.roles`, `tags:["role:X"]`, or both? Pick one, normalize spawn, fix matcher.
4. **Surface fallback/breaker state in response** — add `fallback_from`, `breaker_skipped`, or `route_health` to orchestrator.route responses so callers detect degraded routing without scraping audit logs.
5. **Per-tenant cache scoping** — investigate whether `route-cache.json` should be hub-scoped per project/user instead of global per host.

## Cleanup performed

`termlink signal spec-build SIGTERM` + `signal spec-test SIGTERM` + `termlink clean` → both removed. `termlink list` confirms no spec-* leftovers; only baseline + W01–W10 sibling sessions remain.

## Verdict

Arc is **behaviourally real**, not vapourware. T-1061's core promise — task-type-aware routing with cache + fallback — is observable on the wire. Gaps are around **discoverability, error-surfacing, and tenancy scoping** — not core mechanics. Consistent with T-1641's pushback: shipped code works; nobody has driven it from outside the test suite; routing-rule defaults (selector role semantics, cache scope, breaker thresholds) never consulted.
