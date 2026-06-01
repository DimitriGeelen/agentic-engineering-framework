---
id: T-1642
name: "Arc A — Orchestrator routing-policy consultation (T-1061 follow-up)"
description: >
  Surface 13 hardcoded routing-policy parameters in /opt/termlink (model fallback chain, bypass thresholds, breaker thresholds, route-cache TTL, confidence threshold, task-type taxonomy, tag prefix, concurrency cap, success/failure attribution, selector role contract, default-on governance) as explicit human decisions; capture rationale in decisions.yaml; produce routing-policy.yaml or per-param fw config keys making them runtime-configurable. Top-5 questions: task_type taxonomy (closed enum or free-string?); model fallback order (quality-first vs cost-aware); bypass promotion threshold (5 — calibrated to what?); circuit breaker (3 fail / 60s cool — production-realistic?); discovery filter strictness (fail-closed or soft-preference). Source: docs/reports/T-1641-worker-08-policy-questions.md. Out of scope: implementing configurable values (separate build tasks). Blocks Arc B framework-wiring completion.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [from-T-1641, t-1061-followup, policy, orchestrator, termlink]
components: [web/blueprints/__init__.py, web/blueprints/orchestrator.py, web/templates/orchestrator.html]
related_tasks: [T-1641, T-1061, T-1064, T-1065]
arc_id: orchestrator-rethink
created: 2026-05-01T11:54:33Z
last_update: 2026-05-01T18:58:36Z
date_finished: 2026-05-01T17:08:41Z
---

# T-1642: Arc A — Orchestrator routing-policy consultation (T-1061 follow-up)

## Problem Statement

The orchestrator arc (T-1062–T-1066) ships 13 hardcoded routing-policy constants in `/opt/termlink`, every one set silently by the implementing agent — no commit-message rationale, no design-doc cite, no `decisions.yaml` entry, no human consultation. The user's pushback during T-1641 ("nor have i been consulted for routing rules etc") is structurally accurate: the orchestrator encodes ~10 unilateral policy calls. None are runtime-configurable; changing any policy today requires Rust edit + cargo build + reinstall.

T-1641 W08 enumerated the 13 parameters (model fallback chain, bypass/template-cache PROMOTION_THRESHOLDs, FAILURE_THRESHOLD, COOLDOWN, route-cache TTL & CONFIDENCE_THRESHOLD, task_type taxonomy, tag prefix, discovery filter strictness, cost weighting, concurrency cap, success/failure attribution). Source: `docs/reports/T-1641-worker-08-policy-questions.md`.

This inception's job: make all 13 explicit human decisions with recorded rationale, before Arc B (T-1643) wires the framework to depend on them.

## Assumptions

- **A1:** All 13 parameters are *policy* choices (subjective, context-dependent), not engineering invariants. Validated — none follow from a derivation; each was a code-author judgment call.
- **A2:** The cost of leaving these implicit > the cost of consultation. Validated — T-1061 was framed on closing G-015 partly via these defaults; the human flagged the unilateralism explicitly.
- **A3:** Runtime configurability is feasible via either `routing-policy.yaml` shipped under `/etc/termlink/` or `fw config` keys propagated via env. Both have prior art in the framework. (No spike needed; pick one in implementation tasks.)

## Exploration Plan

Already complete via T-1641 W08. Artefact: `docs/reports/T-1641-worker-08-policy-questions.md`. Contains: enumerated 13 parameters with current-default + set-by + question-for-human; top-5 surfaced; recommended follow-up filing pattern. No further spike work needed before decision.

## Technical Constraints

- Configurable surface must survive consumer-project upgrades (per `fw upgrade` semantics).
- Changes must NOT break current callers (default-on, opt-in override).
- TermLink is machine-wide (per CLAUDE.md TermLink section) — config surface lives in TermLink config or framework `fw config` plumbed via env, not per-project.

## Scope Fence

**IN:**
- Surface all 13 routing-policy parameters as explicit human decisions.
- Capture rationale per parameter in `.context/project/decisions.yaml`.
- Propose a runtime-configurable surface: pick `routing-policy.yaml` vs `fw config` keys vs `hub.toml`.
- Produce per-cluster build-task specs (one per cluster, see "Recommendation" below).

**OUT:**
- Implementing the configurable values (separate per-cluster build tasks — pre-decisioned here, executed there).
- Cost-aware routing (T-1637 already deferred to `horizon: later`).
- Multi-LLM fallback policy beyond order/quality (T-1065 owns the routing intelligence).
- Migration of existing on-disk caches to a new format (separate concern; default is rebuild-on-mismatch per T-1650 proposal).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Human accepts (or overrides) each of the 13 proposed defaults in the Recommendation table.
- A configurable surface (`routing-policy.yaml` vs `fw config` vs `hub.toml`) is chosen; `decisions.yaml` records the choice.
- 4 build tasks (B1–B4) are filed on `horizon: now` or `next` per cluster sequencing in the Recommendation.

**NO-GO if:**
- Human decides the orchestrator arc itself should be deprecated (would invalidate the policy decisions before they land).
- A fundamental restart of routing is preferred over surfacing the existing 13 (would re-litigate W08).

**DEFER if:**
- Other arcs (T-1653 first-class arcs, or routing redesign) need to settle before policy commitment makes sense — but in that case, freeze the 13 constants where they are and re-surface after settling.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:** Every one of these 13 constants is a policy decision masquerading as an engineering default. Leaving them implicit forfeits the framework's auditability promise (D2 directive — Reliability) and blocks Arc B (T-1643) from wiring the framework to depend on stable contracts. The exploration is already done (W08 artefact); what remains is recording 13 explicit decisions and sequencing the build tasks that flip each from constant to config. The cost of doing this now (~1 session of human dialogue + 4 build tasks) is dominated by the cost of *not* doing it (T-1061-class accusations of unilateral design recurring on every routing-related fix).

**Evidence:**
- W08 enumeration of all 13 parameters with current values, set-by, and per-param question — `docs/reports/T-1641-worker-08-policy-questions.md`
- T-1641 W02 (review-feedback mining, item N3) confirms these were never consulted in the original review either — `docs/reports/T-1641-worker-02-review-feedback-mining.md`
- T-1650 proposal to termlink-agent (route_cache `version: u32` field) was accepted in principle — concrete signal that policy/contract changes can land cross-repo.
- 13 cross-repo fabric cards (`.fabric/components/cross-repo-termlink-*.yaml`) already pin the constant values from the framework side as of T-1652 — moving them from constants to config is a bounded refactor, not a redesign.

**Proposed defaults for human override (each is a separate decision in `decisions.yaml`):**

| # | Parameter | Proposed default | Rationale |
|---|-----------|------------------|-----------|
| 1 | task_type taxonomy | **Closed enum** mirroring framework `workflow_type` (build/test/audit/review/inception/specification/design/refactor/decommission) | Avoids silent typos routing to nobody; consistent with the rest of the framework's vocabulary. |
| 2 | DEFAULT_MODEL_FALLBACK | **`[opus-4-7, sonnet-4-6, haiku-4-5]`** quality-first; per-task-type override allowed in v2 | Quality-first matches current default behaviour; cost-awareness deferred per T-1637 horizon: later. |
| 3 | PROMOTION_THRESHOLD (bypass) | **5 successes / 0 failures** keep current; emit warning when promoted | 5 is calibration-by-feel; keep until we have RouteCache hit-rate data to recalibrate. Warning gives audit trail. |
| 4 | PROMOTION_THRESHOLD (template_cache) | **Diverge** — 3 successes for template-cache vs 5 for bypass | Template caching is a reversible perf opt; bypass skips orchestration entirely. Different stakes, different bars. |
| 5 | FAILURE_THRESHOLD (circuit) | **3 consecutive** keep current; **add per-model override** | 3 is fine for opus/sonnet; haiku flakes more. Per-model override hedges. |
| 6 | COOLDOWN (circuit) | **60s linear** keep current; revisit when T-1639 throughput benchmark lands | No data to justify exponential yet. |
| 7 | DEFAULT_TTL_HOURS (route cache) | **168h (7d)** keep current | Matches a typical work-week cycle; short enough that fleet churn invalidates within bounds. |
| 8 | CONFIDENCE_THRESHOLD | **0.8** keep current; document operational meaning in `decisions.yaml` | Document, don't change — the 0.8 isn't broken, the missing rationale is. |
| 9 | task-type tag prefix | **`task-type:`** keep current; reserve `arc:` namespace alongside (per T-1653 if GO) | Already in production; alternative `tt:`/`workflow:` saves bytes but loses readability. |
| 10 | Discovery filter (no-match) | **Soft preference** (current) keep; add `--strict` flag for fail-closed at call site | Fail-closed by default risks cascading dispatch failures during specialist outages; opt-in strict for tests/CI. |
| 11 | Cost weighting | **Defer** — T-1637 already at `horizon: later` | Confirmed deferral. |
| 12 | Concurrency cap | **5 hub-side, 10 client-side** | 5 matches framework sub-agent dispatch protocol; 10 client-side preserves current dispatch caller behaviour. |
| 13 | Success/failure attribution | **`InfraFailure` does NOT block promotion; `CommandFailure` does** keep current; add `UserAbort` as third class (counts as neither) | Stable boundary needs operator definition. UserAbort case is currently misclassified as failure. |

**Configurable surface:** propose `routing-policy.yaml` shipped at `/opt/termlink/etc/routing-policy.yaml` (TermLink-side), with `fw config` keys plumbed through env for per-project override. Decided in build task, not here.

**Proposed follow-up build tasks (file under `from-T-1642`, on GO):**
- T-1642-B1: Lift parameters #1–#5 (task_type, fallback, both PROMOTION_THRESHOLDs, FAILURE_THRESHOLD) to `routing-policy.yaml` — cluster: dispatch core
- T-1642-B2: Lift #6–#8 (COOLDOWN, TTL, CONFIDENCE_THRESHOLD) — cluster: route cache + breaker tunables
- T-1642-B3: Lift #9–#10 + #12–#13 (tag prefix, discovery filter, concurrency, attribution) — cluster: discovery + dispatch
- T-1642-B4: `fw config` plumbing (read `routing-policy.yaml` via env, validate on startup) — cluster: framework wiring (overlaps T-1643)

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: Every one of these 13 constants is a policy decision masquerading as an engineering default. Leaving them implicit forfeits the framework's auditability promise (D2 directive — Reliability) and blocks Arc B (T-1643) from wiring the framework to depend on stable contracts. The exploration is already done (W08 artefact); what remains is recording 13 explicit decisions and sequencing the build tasks that flip each from constant to config. The cost of doing this now (~1 session of human dialogue + 4 build tasks) is dominated by the cost of not doing it (T-1061-class accusations of unilateral design recurring on every routing-related fix).

Evidence:
- W08 enumeration of all 13 parameters with current values, set-by, and per-param question — `docs/reports/T-1641-worker-08-policy-questions.md`
- T-1641 W02 (review-feedback mining, item N3) confirms these were never consulted in the original review either — `docs/reports/T-1641-worker-02-review-feedback-mining.md`
- T-1650 proposal to termlink-agent (route_cache `version: u32` field) was accepted in principle — concrete signal that policy/contract changes can land cross-repo.
- 13 cross-repo fabric cards (`.fabric/components/cross-repo-termlink-.yaml`) already pin the constant values from the framework side as of T-1652 — moving them from constants to config is a bounded refactor, not a redesign.

Proposed defaults for human override (each is a separate decision in `decisions.yaml`):

| # | Parameter | Proposed default | Rationale |
|---|-----------|------------------|-----------|
| 1 | task_type taxonomy | Closed enum mirroring framework `workflow_type` (build/test/audit/review/inception/specification/design/refactor/decommission) | Avoids silent typos routing to nobody; consistent with the rest of the framework's vocabulary. |
| 2 | DEFAULT_MODEL_FALLBACK | `[opus-4-7, sonnet-4-6, haiku-4-5]` quality-first; per-task-type override allowed in v2 | Quality-first matches current default behaviour; cost-awareness deferred per T-1637 horizon: later. |
| 3 | PROMOTION_THRESHOLD (bypass) | 5 successes / 0 failures keep current; emit warning when promoted | 5 is calibration-by-feel; keep until we have RouteCache hit-rate data to recalibrate. Warning gives audit trail. |
| 4 | PROMOTION_THRESHOLD (template_cache) | Diverge — 3 successes for template-cache vs 5 for bypass | Template caching is a reversible perf opt; bypass skips orchestration entirely. Different stakes, different bars. |
| 5 | FAILURE_THRESHOLD (circuit) | 3 consecutive keep current; add per-model override | 3 is fine for opus/sonnet; haiku flakes more. Per-model override hedges. |
| 6 | COOLDOWN (circuit) | 60s linear keep current; revisit when T-1639 throughput benchmark lands | No data to justify exponential yet. |
| 7 | DEFAULT_TTL_HOURS (route cache) | 168h (7d) keep current | Matches a typical work-week cycle; short enough that fleet churn invalidates within bounds. |
| 8 | CONFIDENCE_THRESHOLD | 0.8 keep current; document operational meaning in `decisions.yaml` | Document, don't change — the 0.8 isn't broken, the missing rationale is. |
| 9 | task-type tag prefix | `task-type:` keep current; reserve `arc:` namespace alongside (per T-1653 if GO) | Already in production; alternative `tt:`/`workflow:` saves bytes but loses readability. |
| 10 | Discovery filter (no-match) | Soft preference (current) keep; add `--strict` flag for fail-closed at call site | Fail-closed by default risks cascading dispatch failures during specialist outages; opt-in strict for tests/CI. |
| 11 | Cost weighting | Defer — T-1637 already at `horizon: later` | Confirmed deferral. |
| 12 | Concurrency cap | 5 hub-side, 10 client-side | 5 matches framework sub-agent dispatch protocol; 10 client-side preserves current dispatch caller behaviour. |
| 13 | Success/failure attribution | `InfraFailure` does NOT block promotion; `CommandFailure` does keep current; add `UserAbort` as third class (counts as neither) | Stable boundary needs operator definition. UserAbort case is currently misclassified as failure. |

Configurable surface: propose `routing-policy.yaml` shipped at `/opt/termlink/etc/routing-policy.yaml` (TermLink-side), with `fw config` keys plumbed through env for per-project override. Decided in build task, not here.

Proposed follow-up build tasks (file under `from-T-1642`, on GO):
- T-1642-B1: Lift parameters #1–#5 (task_type, fallback, both PROMOTION_THRESHOLDs, FAILURE_THRESHOLD) to `routing-policy.yaml` — cluster: dispatch core
- T-1642-B2: Lift #6–#8 (COOLDOWN, TTL, CONFIDENCE_THRESHOLD) — cluster: route cache + breaker tunables
- T-1642-B3: Lift #9–#10 + #12–#13 (tag prefix, discovery filter, concurrency, attribution) — cluster: discovery + dispatch
- T-1642-B4: `fw config` plumbing (read `routing-policy.yaml` via env, validate on startup) — cluster: framework wiring (overlaps T-1643)

**Date**: 2026-05-01T17:08:40Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-01T17:08:40Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Every one of these 13 constants is a policy decision masquerading as an engineering default. Leaving them implicit forfeits the framework's auditability promise (D2 directive — Reliability) and blocks Arc B (T-1643) from wiring the framework to depend on stable contracts. The exploration is already done (W08 artefact); what remains is recording 13 explicit decisions and sequencing the build tasks that flip each from constant to config. The cost of doing this now (~1 session of human dialogue + 4 build tasks) is dominated by the cost of not doing it (T-1061-class accusations of unilateral design recurring on every routing-related fix).

Evidence:
- W08 enumeration of all 13 parameters with current values, set-by, and per-param question — `docs/reports/T-1641-worker-08-policy-questions.md`
- T-1641 W02 (review-feedback mining, item N3) confirms these were never consulted in the original review either — `docs/reports/T-1641-worker-02-review-feedback-mining.md`
- T-1650 proposal to termlink-agent (route_cache `version: u32` field) was accepted in principle — concrete signal that policy/contract changes can land cross-repo.
- 13 cross-repo fabric cards (`.fabric/components/cross-repo-termlink-.yaml`) already pin the constant values from the framework side as of T-1652 — moving them from constants to config is a bounded refactor, not a redesign.

Proposed defaults for human override (each is a separate decision in `decisions.yaml`):

| # | Parameter | Proposed default | Rationale |
|---|-----------|------------------|-----------|
| 1 | task_type taxonomy | Closed enum mirroring framework `workflow_type` (build/test/audit/review/inception/specification/design/refactor/decommission) | Avoids silent typos routing to nobody; consistent with the rest of the framework's vocabulary. |
| 2 | DEFAULT_MODEL_FALLBACK | `[opus-4-7, sonnet-4-6, haiku-4-5]` quality-first; per-task-type override allowed in v2 | Quality-first matches current default behaviour; cost-awareness deferred per T-1637 horizon: later. |
| 3 | PROMOTION_THRESHOLD (bypass) | 5 successes / 0 failures keep current; emit warning when promoted | 5 is calibration-by-feel; keep until we have RouteCache hit-rate data to recalibrate. Warning gives audit trail. |
| 4 | PROMOTION_THRESHOLD (template_cache) | Diverge — 3 successes for template-cache vs 5 for bypass | Template caching is a reversible perf opt; bypass skips orchestration entirely. Different stakes, different bars. |
| 5 | FAILURE_THRESHOLD (circuit) | 3 consecutive keep current; add per-model override | 3 is fine for opus/sonnet; haiku flakes more. Per-model override hedges. |
| 6 | COOLDOWN (circuit) | 60s linear keep current; revisit when T-1639 throughput benchmark lands | No data to justify exponential yet. |
| 7 | DEFAULT_TTL_HOURS (route cache) | 168h (7d) keep current | Matches a typical work-week cycle; short enough that fleet churn invalidates within bounds. |
| 8 | CONFIDENCE_THRESHOLD | 0.8 keep current; document operational meaning in `decisions.yaml` | Document, don't change — the 0.8 isn't broken, the missing rationale is. |
| 9 | task-type tag prefix | `task-type:` keep current; reserve `arc:` namespace alongside (per T-1653 if GO) | Already in production; alternative `tt:`/`workflow:` saves bytes but loses readability. |
| 10 | Discovery filter (no-match) | Soft preference (current) keep; add `--strict` flag for fail-closed at call site | Fail-closed by default risks cascading dispatch failures during specialist outages; opt-in strict for tests/CI. |
| 11 | Cost weighting | Defer — T-1637 already at `horizon: later` | Confirmed deferral. |
| 12 | Concurrency cap | 5 hub-side, 10 client-side | 5 matches framework sub-agent dispatch protocol; 10 client-side preserves current dispatch caller behaviour. |
| 13 | Success/failure attribution | `InfraFailure` does NOT block promotion; `CommandFailure` does keep current; add `UserAbort` as third class (counts as neither) | Stable boundary needs operator definition. UserAbort case is currently misclassified as failure. |

Configurable surface: propose `routing-policy.yaml` shipped at `/opt/termlink/etc/routing-policy.yaml` (TermLink-side), with `fw config` keys plumbed through env for per-project override. Decided in build task, not here.

Proposed follow-up build tasks (file under `from-T-1642`, on GO):
- T-1642-B1: Lift parameters #1–#5 (task_type, fallback, both PROMOTION_THRESHOLDs, FAILURE_THRESHOLD) to `routing-policy.yaml` — cluster: dispatch core
- T-1642-B2: Lift #6–#8 (COOLDOWN, TTL, CONFIDENCE_THRESHOLD) — cluster: route cache + breaker tunables
- T-1642-B3: Lift #9–#10 + #12–#13 (tag prefix, discovery filter, concurrency, attribution) — cluster: discovery + dispatch
- T-1642-B4: `fw config` plumbing (read `routing-policy.yaml` via env, validate on startup) — cluster: framework wiring (overlaps T-1643)

### 2026-05-01T17:08:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.4)

- **Scan ID:** R-5c7aac69
- **Timestamp:** 2026-05-01T17:08:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-01T17:08:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-05-01T18:58:36Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
