# T-1666 — fw config plumbing for routing-policy.yaml

**Workflow type at filing:** build (T-1642 GO breakdown)
**Reclassified:** inception (this artifact)
**Companion to:** T-1642 (Arc A — Orchestrator routing-policy consultation, work-completed 2026-05-01)
**Substrate-side dependency:** T-1642 B1/B2/B3 in `/opt/termlink` (NOT YET SHIPPED — see §3 below)

## 1. Original framing (from T-1642 GO recommendation)

T-1642's recommendation called for four follow-up build tasks:

| Task     | Cluster                                | Where           |
|----------|----------------------------------------|-----------------|
| B1       | task_type, fallback chain, both PROMOTION_THRESHOLDs, FAILURE_THRESHOLD | `/opt/termlink` |
| B2       | COOLDOWN, TTL, CONFIDENCE_THRESHOLD    | `/opt/termlink` |
| B3       | tag prefix, discovery filter, concurrency, attribution | `/opt/termlink` |
| **B4 (this task)** | `fw config` plumbing — read `routing-policy.yaml`, env-propagate, validate on startup | **framework** |

The substrate plan: `/opt/termlink/etc/routing-policy.yaml` ships with the
13 lifted constants. `fw config` reads them, validates, propagates to
TermLink hub via env vars per consumer project's `.framework.yaml`
overrides.

## 2. What changed since T-1642

Three observations from the now-shipped T-1669 (route_cache wiring) and
related arc work change the calculus:

1. **The framework only directly consumes 2 of the 13 constants:**
   - `DISPATCH_MODEL_DEFAULT` — already plumbed (lib/config.sh:167, T-1643/W3)
   - `ARC_COMPLETION_THRESHOLD` — already plumbed (lib/config.sh:168, T-1656)

2. **The other 11 are substrate-internal hub decisions:**

   | Constant                  | Used by                                              |
   |---------------------------|------------------------------------------------------|
   | PROMOTION_THRESHOLD (template) | `template_cache.rs` — TermLink hub internal     |
   | PROMOTION_THRESHOLD (bypass)   | `bypass.rs` — TermLink hub internal             |
   | FAILURE_THRESHOLD              | `circuit_breaker.rs` — TermLink hub internal    |
   | COOLDOWN                       | TermLink hub circuit-breaker recovery           |
   | DEFAULT_TTL_HOURS              | `route_cache.rs` — TermLink hub eviction        |
   | CONFIDENCE_THRESHOLD           | `route_cache.rs` — TermLink hub gating          |
   | task_type taxonomy             | TermLink hub validation                          |
   | tag prefix                     | TermLink hub session-tagging                    |
   | discovery filter               | TermLink hub specialist discovery               |
   | concurrency cap                | TermLink hub orchestrator                       |
   | attribution                    | TermLink hub audit                              |

   None of these are read by `bin/fw` or the framework's dispatch path.
   They are consumed inside `termlink-hub` Rust code at runtime.

3. **B1/B2/B3 have not shipped substrate-side as of 2026-05-02:**
   `/opt/termlink/etc/routing-policy.yaml` does not exist; recent
   `/opt/termlink` commits focus on T-1438 (chat-arc skill rollout) and
   T-1418/T-1296 (ring20-dashboard auth healing). No commits matching
   `T-1642`, `B1`, `B2`, `B3`, or `routing-policy` since GO.

## 3. Three implementation paths

### Path (a) — Wait for B1/B2/B3, then read `routing-policy.yaml`

Block until substrate ships the YAML; then implement:

```
fw config get PROMOTION_THRESHOLD_BYPASS
  → reads .framework.yaml → falls back to /opt/termlink/etc/routing-policy.yaml
```

**Pros:** strict alignment with T-1642's recommendation.

**Cons:** indefinite block. Substrate is busy on chat-arc work; B1/B2/B3
are not on a near-term milestone. Framework can't make forward progress
without it.

### Path (b) — Ship env-var pass-through now

Frame B4 as: framework registers all 13 keys in `lib/config.sh` with
documented defaults matching the substrate's hardcoded constants. When
`fw termlink dispatch` spawns a worker, the keys are propagated as
env vars (`TL_PROMOTION_THRESHOLD_BYPASS=...`, etc.). Substrate-side
B1/B2/B3 then becomes "read these env vars before falling back to
constant" — much smaller substrate change.

**Pros:**
- Framework can ship now without substrate dependency.
- When substrate adds env-var reading, the override path already works.
- Validation (key exists, type correct, range sensible) lives where the
  override surface is — `.framework.yaml`, not buried in Rust constants.

**Cons:**
- 11 keys with no current consumer in framework code is extra surface
  area. Risk: configs drift; consumers tweak values that nothing reads.
- Substrate B1/B2/B3 still required for the keys to take effect.

### Path (c) — Drop B4 from scope; let substrate own its own config

Acknowledge that the 11 substrate-internal keys belong in
`/opt/termlink/etc/routing-policy.yaml` and are read by `termlink-hub`
directly via its own config layer (Rust `serde_yaml`, no framework
plumbing). The 2 framework-side keys
(`DISPATCH_MODEL_DEFAULT`, `ARC_COMPLETION_THRESHOLD`) are already
plumbed.

The original T-1642 framing assumed framework would mediate
substrate config. That's an unnecessary coupling — `fw_config` is the
framework's surface, `routing-policy.yaml` is the substrate's. They
don't need to share.

**Pros:**
- Cleanest separation of concerns.
- Framework stays minimal; substrate owns its config.
- Antifragile: changes to substrate constants don't ripple into
  `lib/config.sh`.
- Aligns with §Portability — framework doesn't gain TermLink-specific
  knowledge.

**Cons:**
- Diverges from T-1642's literal recommendation (which assumed B4 was
  needed).
- Consumers can't override substrate config from `.framework.yaml` —
  they edit `/opt/termlink/etc/routing-policy.yaml` directly. (For
  multi-project hosts this is fine: one TermLink hub, one config.)

## 4. Trade-off matrix

| Dimension                       | (a) Wait | (b) Pass-through | (c) Drop scope |
|---------------------------------|----------|------------------|----------------|
| Effort                          | n/a (block) | ~0.5 days     | ~0.1 days (close + doc) |
| Substrate coupling              | tight    | medium           | none           |
| Forward progress today          | none     | yes              | yes            |
| Surface area added              | none     | 11 keys          | 0 keys         |
| Risk of config drift            | n/a      | high             | none           |
| Aligns with §Portability        | medium   | medium           | high           |
| Aligns with §Reliability        | low      | medium           | high           |
| Antifragility                   | low      | low              | high           |

## 5. Recommendation

**Recommendation:** DEFER

The substrate-internal constants belong in `/opt/termlink/etc/routing-policy.yaml`
and should be consumed by `termlink-hub` directly. The framework's job is to
expose its OWN dispatch-related keys (already done) and stay out of substrate
internals. Path (c) is the antifragile choice; closing T-1666 as DEFER signals
"this remains parked unless promotion criteria fire."

**Concrete actions taken at filing:**

1. Reclassified `workflow_type: build → inception`.
2. Replaced placeholder ACs with `@auto-tick-on-decide` triplet
   (problem statement validated / paths evaluated / recommendation written).
3. Set `horizon: later` until either:
   - substrate-side B1/B2/B3 ships and changes the calculus, OR
   - a real framework consumer needs PROMOTION_THRESHOLD-class config
     overridable via `.framework.yaml`.

**Promotion criteria (revisit if):**
- Substrate ships `/opt/termlink/etc/routing-policy.yaml` AND a consumer
  project requests per-project override via `.framework.yaml`.
- A new framework feature emerges that reads any of the 11 substrate-internal
  constants (none currently planned).

## 6. Decision

This artifact records the analysis. Per §Closure-Decision-Discipline
(T-1259/T-1671), the verb itself
(`fw inception decide T-1666 defer --rationale "..." --i-am-human`)
belongs to the human.

## Dialogue log

This artifact was produced from:

- T-1642 task body (recommendation block specifying B1–B4 cluster
  structure; "Configurable surface" decision)
- `lib/config.sh` (current framework config-key registry)
- `agents/termlink/termlink.sh` (framework dispatch path env-var
  propagation surface area)
- `/opt/termlink/crates/termlink-hub/src/{template_cache,bypass,circuit_breaker,route_cache}.rs`
  (where the 11 hardcoded constants live)
- `git -C /opt/termlink log --since=2026-05-01` (to confirm B1/B2/B3
  not shipped)

No dialogue with the substrate-side session occurred — the analysis
relied on read-only inspection of the substrate repo, which is
sufficient to demonstrate that B1/B2/B3 haven't shipped and that the
keys aren't currently read by framework code.

A future revisit (per promotion criteria above) should include a
TermLink-mediated check-in with the substrate session to confirm
B1/B2/B3 status before taking the rescope decision back off DEFER.
