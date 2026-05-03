# T-1641 W08 — Routing-Rule Policy Questions

## Summary

Every routing parameter shipped in the orchestrator arc (T-1062–T-1066) is a hardcoded constant in /opt/termlink Rust source, set by the implementing agent with no commit-message rationale, no design-doc cite, and no human consultation entry in any decisions.yaml. Ten distinct policy parameters were silently defaulted: model fallback chain, bypass promotion threshold, circuit breaker threshold and cooldown, route cache TTL and confidence threshold, task-type taxonomy (free-string), tag prefix convention, concurrency caps, and success/failure attribution. The user's pushback ("nor have i been consulted for routing rules etc") is structurally accurate — the orchestrator encodes ~10 unilateral policy calls. None are configurable at runtime; all require a code change + redeploy to alter. Recommendation: file an inception (`from-T-1641`, type=inception) titled "routing-policy consultation" to surface these as explicit human decisions before any consumer wires routing on.

## Policy Table

| # | Parameter | Current default | Set-by | Question for human |
|---|-----------|-----------------|--------|--------------------|
| 1 | task_type taxonomy | **Free-string**, no validation; doc-comment lists `build/test/audit/review` (router.rs:1074) | Code author (T-1064) — no canonical list anywhere | Should task_type be a closed enum (build/test/audit/review/inception/specification/design/refactor/decommission, mirroring framework workflow_types), or remain open? |
| 2 | DEFAULT_MODEL_FALLBACK | `["opus", "sonnet", "haiku"]` (circuit_breaker.rs:114) | Code author — no decision record | Is opus→sonnet→haiku the correct default fallback order? Should it be cost-aware (haiku-first for cheap work) or quality-first (current)? |
| 3 | PROMOTION_THRESHOLD (bypass) | `5` successful runs, 0 failures (bypass.rs:37) | Code author (T-1063) — no rationale in commit | Why 5? Is 5 enough evidence to skip orchestration thereafter? Should it differ per command class? |
| 4 | PROMOTION_THRESHOLD (template cache) | `5` (template_cache.rs:17) | Code author — duplicates bypass value | Same threshold as bypass coincidence or intentional? Should they diverge? |
| 5 | FAILURE_THRESHOLD (circuit) | `3` consecutive failures opens circuit (circuit_breaker.rs:6) | Code author — no rationale | 3 strikes — too tight (flaps on transient blips) or too loose? |
| 6 | COOLDOWN (circuit) | `60s` half-open (circuit_breaker.rs:9) | Code author | Is 60s the right backoff for upstream model outages? Linear vs exponential? |
| 7 | DEFAULT_TTL_HOURS (route cache) | `168` (= 7 days) (route_cache.rs:104) | Code author | 7-day staleness for routing decisions — appropriate, or should it shorten as fleet churn rises? |
| 8 | CONFIDENCE_THRESHOLD (cache hit) | `0.8` (route_cache.rs:101) | Code author | Why 0.8? What does "confidence" mean operationally and who calibrated it? |
| 9 | task-type tag prefix | `task-type:<type>` (router.rs:1308) | Code author | Was the `task-type:` prefix vs e.g. `tt:`/`workflow:`/role-based reviewed? Locks tag namespace forever. |
| 10 | Discovery candidate filter | tags ∧ roles ∧ caps ∧ name; task-type tag is **preference (stable sort), not filter** (router.rs:1305-1310) | Code author (T-1064) | Should an unmatched task_type be a hard miss (fail closed) or a soft preference (current — falls back to any specialist)? |
| 11 | Cost weighting | **None** — no $ or token cost considered in routing | T-1637 explicitly deferred (`horizon: later`) | Confirmed deferral, or should at least a token-budget guard exist before routing? |
| 12 | Concurrency cap | `max_parallel.unwrap_or(10)` in dispatch (tools.rs:4343,4669); **no hub-side cap** | Code author — chose 10 silently | Is 10 parallel dispatches the right ceiling? Why not 5 (matches sub-agent dispatch protocol)? |
| 13 | Success/failure attribution | `RunOutcome::CommandFailure` blocks promotion; `InfraFailure` invisible (bypass.rs:130-158) | Code author (T-1063) | Who decides what counts as InfraFailure vs CommandFailure? Is the boundary stable across commands? |

## Top 5 Questions to Surface to Human

1. **Task-type taxonomy:** closed enum or free-string? (Affects every dispatch caller — silent typo today routes to nobody.)
2. **Model fallback order:** opus→sonnet→haiku quality-first vs haiku-first cost-aware (or per-task-type chains)?
3. **Bypass promotion threshold (5):** is this evidence-of-stability bar acceptable, or should it scale with command blast radius?
4. **Circuit breaker (3 fail / 60s cool):** are these production-realistic for transient model outages, or should we monitor real failure distributions before fixing values?
5. **Discovery filter strictness:** when no specialist matches `task-type:X`, should orchestrator fail closed (typed routing only) or fall back to any candidate (current)?

## Recommended Follow-up Tasks

**INCEPTION (file under `from-T-1641`, workflow_type=inception):**

- **"Routing-policy consultation — orchestrator hardcoded defaults"**
  - Scope: surface the 13 parameters in the table above as explicit human decisions; capture rationale in `.context/project/decisions.yaml`; produce a `routing-policy.yaml` (or per-param `fw config` keys) that makes them runtime-configurable instead of constants.
  - Out of scope: implementing the configurable values (separate build task per cluster).
  - GO criteria: human signs off on each of the top-5 questions; remainder may be deferred with explicit `decision: defer` records.

**Companion observation (no task yet):** none of these constants are reachable via `fw config` — even after consultation, changing any policy requires a Rust edit + cargo build + reinstall. A second downstream task should consider whether the configurable surface lives in a TermLink config file, a hub.toml, or framework `fw config` keys plumbed via env.