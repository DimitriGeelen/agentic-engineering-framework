---
id: T-1714
name: "Substrate bypass: fw termlink dispatch ducks under fw resolver dispatch, leaving
  substrate at zero real-consumer telemetry (T-1700 AC4.3 RCA)"
description: >
  Inception: Substrate bypass: fw termlink dispatch ducks under fw resolver dispatch,
  leaving substrate at zero real-consumer telemetry (T-1700 AC4.3 RCA)

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [G-064, substrate-bypass, RCA]
components: []
related_tasks: [T-1684, T-1685, T-1688, T-1689, T-1696, T-1697, T-1700]
arc_id: orchestrator-rethink
created: 2026-05-04T08:05:46Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-04T09:56:32Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1714: Substrate bypass: fw termlink dispatch ducks under fw resolver dispatch, leaving substrate at zero real-consumer telemetry (T-1700 AC4.3 RCA)

## Problem Statement

The dispatch substrate has TWO entry points:

  - `fw resolver dispatch <task_id> <task_type>` — writes envelope row to
    `.context/dispatches.jsonl` (workflow_id, workflow_sha, task_type,
    worker_kind, model, prompt_template, etc). Outcome enrichment hook
    (T-1697) back-props verification + AC results when the task hits
    `work-completed`. This is the telemetered path.
  - `fw termlink dispatch --name X --prompt Y --task-type Z ...` — direct
    PTY worker spawn via `agents/termlink/termlink.sh:cmd_dispatch`. Writes
    `meta.json` to the per-worker dispatch dir. Does NOT write to
    `.context/dispatches.jsonl`. No outcome enrichment possible.

T-1700's harness (`tools/t1700-ollama-harness.sh`) runs 13 dispatches
through `fw termlink dispatch --task-type ollama-research`. Those dispatches
correctly exercise the litellm proxy + ollama-loop worker + workflow `env:`
plumbing — but they're invisible to `fw orchestrator status`. Result:
T-1700 AC4.3 (outcome rows in dispatch-outcomes.jsonl) honestly fails.

The deeper observation: the substrate's first real production-shape
consumer (T-1700 harness) ducked under the substrate. G-064 ("orchestrator
substrate has zero production consumers") was thought to need a NEW
consumer (T-1684 cron health-check, escalation-scan v0.5). T-1714 adds:
G-064 also needs the EXISTING consumer to actually use the telemetered
path. Otherwise we ship the substrate, ship the consumer, and still get
zero substrate signal.

For whom: agents and humans relying on `fw orchestrator status` /
`/orchestrator` page to observe routing decisions. Why now: T-1700 SHIP-
WITH-CAVEAT just exposed the bypass; closing it before more consumers
internalise the pattern is cheaper than fixing it later.

## RCA

**Symptom:** T-1700 AC4.3 fails. `dispatch-outcomes.jsonl` contains zero
T-1700 rows despite 13 harness dispatches running successfully through
the litellm proxy + ollama-loop worker.

**Root cause:** The substrate has two parallel write surfaces:
  - `lib/resolver.py` (Python) writes to `.context/dispatches.jsonl`
  - `agents/termlink/termlink.sh:cmd_dispatch` (bash) writes to
    `<wdir>/meta.json` only
The harness chose the second. The substrate has NO mechanism to record
"a worker spawned without going through resolver" as a substrate event.
Workers spawned via `fw termlink dispatch` are real dispatches as far as
behaviour goes, but invisible as far as observability goes.

**Why structurally allowed:** Both entry points are documented in
CLAUDE.md (§Sub-Agent Dispatch Protocol mentions `fw termlink dispatch`,
§Quick Reference mentions `fw resolver dispatch`). Neither calls out
that one is telemetered and the other isn't. There's no gate, lint, or
warn on `fw termlink dispatch` saying "you're skipping the substrate".
The harness was written before resolver supported the flags it needed
(`--env`, `--worker-kind`, `--tools`); pragmatic choice at the time, but
no follow-up wired the harness through resolver after those flags landed.

The deeper structural enabler: the substrate's value proposition
("agent dispatches without specifying a model → orchestrator picks it
from learned route_cache") is defined at the resolver layer. Anyone
needing flags resolver doesn't pass falls back to termlink dispatch and
loses the value prop. The two layers were not designed with a clear
"resolver is the API, termlink is the implementation" contract.

**Prevention:** Pick one of three:
  1. Make `fw termlink dispatch` also write the envelope row, with
     `workflow_resolved_via: "direct-bypass"` so analytics can identify
     bypass dispatches. Cost: ~30 LOC in cmd_dispatch.
  2. Make `fw resolver dispatch` accept all the flags `fw termlink
     dispatch` accepts, and deprecate direct termlink dispatch as a
     consumer API. Cost: larger refactor; touches resolver.py +
     termlink.sh + workflow YAML schema.
  3. Pre-spawn lint: `cmd_dispatch` warns when called outside a resolver
     context (no envelope_id env var), instructing the caller to use
     `fw resolver dispatch`. Cost: ~10 LOC + agent-prompt update; but
     leaves bypass dispatches still invisible.

The G-064 connection makes this load-bearing: until bypass is closed or
documented + counted, "first real production consumer" claims for the
substrate are uninhabited.

## Assumptions

A1. Bypass is widespread, not just T-1700. A grep across `tools/`,
    `tests/`, and any documentation that recommends `fw termlink dispatch`
    will show multiple consumers.
A2. The harness's choice of termlink dispatch was driven by
    `--env`/`--tools`/`--worker-kind` not being available in resolver
    dispatch at the time the harness was written. Verifiable by reading
    `lib/resolver.py:cmd_dispatch` against `agents/termlink/termlink.sh:
    cmd_dispatch` at HEAD.
A3. Adding envelope-write to `cmd_dispatch` is non-disruptive: the
    envelope schema (.context/dispatches.jsonl) is append-only and the
    new rows would carry `workflow_resolved_via: "direct-bypass"` so
    consumers can filter.
A4. Outcome back-prop (T-1697) is keyed off task_id + dispatch_id; if
    bypass dispatches start writing envelopes, the existing back-prop
    hook (`fw outcome backprop` from `update-task.sh --status
    work-completed`) will pick them up without changes.

## Exploration Plan

Three time-boxed spikes, 1 session each:

1. **Bypass survey spike** — Catalogue every call site of
   `fw termlink dispatch` in framework + consumer projects + tests +
   docs. For each, classify: telemetered-needed (production consumer),
   acceptable-bypass (test harness only), legacy (predates resolver).
   Test A1.

2. **Flag-parity spike** — Compare `lib/resolver.py:cmd_dispatch` flags
   vs `agents/termlink/termlink.sh:cmd_dispatch` flags. Identify which
   resolver lacks (--env, --tools, --worker-kind, --timeout). Estimate
   the cost of bringing resolver to parity. Test A2.

3. **Envelope-from-bypass spike** — Prototype Prevention path 1:
   `cmd_dispatch` writes a envelope row with
   `workflow_resolved_via: "direct-bypass"` when called without
   `FW_RESOLVER_ENVELOPE_ID` env var set (resolver sets it when calling
   into termlink dispatch). Verify `fw orchestrator status` then sees
   bypass dispatches and they back-prop through T-1697 normally. Test
   A3 + A4.

## Technical Constraints

- The envelope schema (`.context/dispatches.jsonl`) is append-only. Any
  fix must preserve append-only semantics — no rewrites, no deduplication
  at write time. Forensic traceability of the bypass period is itself
  evidence for the analytics question "how often did bypass happen?".
- Outcome back-prop (T-1697 hook in `update-task.sh`) keys off `task_id`.
  Bypass dispatches today have task tags (e.g. `task=T-1700`) on the
  TermLink session but no envelope row. If we add envelope writes, the
  back-prop must fire for them too — otherwise we surface bypass volume
  but enrichment ratio still looks bad.
- Tests dispatching workers (e.g. test_orchestrator_learned_routing.py)
  must continue to work. The test harness deliberately bypasses resolver
  in places. Tests should not start writing real envelope rows that
  pollute production analytics — needs a mock-mode env var.

## Scope Fence

IN scope:
- RCA (above) confirmed or refuted by the bypass survey + flag-parity
  spikes.
- Choose one of three Prevention paths (envelope-from-bypass, resolver
  flag parity + termlink deprecation, pre-spawn lint).
- Estimate cost (LOC + risk + migration).
- Decision: GO with chosen path, NO-GO if RCA disproven, DEFER if a
  larger inception (e.g. orchestrator v2) absorbs this.

OUT of scope:
- Doing the build. This is inception only — confirm root cause + pick
  path. The build follows as a separate task.
- G-064 closure. T-1714 fix is a NECESSARY but not SUFFICIENT condition
  for closing G-064. New consumers (T-1684 daily health-check, etc) are
  still needed. T-1714 just removes the structural reason existing
  consumers don't count.
- Cross-repo: any project using `fw termlink dispatch` directly will
  benefit, but T-1714 fix is in the framework only. Consumer projects
  pick up the fix via `fw upgrade`.

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

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Bypass survey shows ≥2 production-shape consumers using direct termlink
  dispatch (T-1700 harness alone is enough — confirms not isolated).
- Flag-parity spike confirms resolver lacks ≥1 flag termlink dispatch
  has (or has structural reason it can't accept them).
- Envelope-from-bypass spike produces a working prototype with
  workflow_resolved_via: "direct-bypass" and back-prop fires correctly.
- One of the three Prevention paths is bounded enough to fit a single
  build task (≤200 LOC equivalent, no schema migrations required).

**NO-GO if:**
- Bypass is isolated to the T-1700 harness and harness can be re-routed
  through resolver with <50 LOC change → just fix the harness, no
  inception needed.
- All three Prevention paths require breaking the append-only contract
  or a schema migration → bigger problem; defer to orchestrator v2.

**DEFER if:**
- T-1709 (review instance) GO turns out to require resolver-flag-parity
  changes anyway → fold T-1714 into that scope.

## Recommendation

**Recommendation:** GO

**Rationale:**

Three convergent reasons:

1. **The bypass is structural, not isolated.** RCA shows two parallel
   write surfaces (`lib/resolver.py` envelope writer vs `agents/termlink/
   termlink.sh:cmd_dispatch` direct writer with `meta.json` only). T-1700
   harness is the smoking gun, but the structural condition affects every
   future consumer that needs flags resolver doesn't yet pass through.
   Bypass survey spike (#1) will quantify, but the structural pattern is
   already evident in code at HEAD.

2. **G-064 is structurally blocked until this closes.** The arc's
   headline mechanic is "agent dispatches → orchestrator picks model →
   user observes the routing decision live on /orchestrator". Bypass
   dispatches don't appear on /orchestrator. Until termlink-dispatch
   bypass is either eliminated or counted as `direct-bypass`,
   "first real production consumer" claims for the substrate are
   uninhabited regardless of how many real consumers we add. T-1684
   (daily health-check cron) and any other G-064 candidate inherit this
   blocker if they pick the wrong path.

3. **The fix is bounded.** Three Prevention paths catalogued in RCA;
   the cheapest (envelope-from-bypass with `workflow_resolved_via:
   "direct-bypass"`) is ~30 LOC in `cmd_dispatch` plus a regression test.
   The append-only contract is preserved. Outcome back-prop (T-1697
   hook) keys off task_id and would pick up bypass envelopes without
   changes (assumption A4 to be confirmed).

**Evidence:**

- `lib/resolver.py:cmd_dispatch` writes envelope row to `dispatches.jsonl`
  including `workflow_id`, `workflow_sha`, `task_type`, `worker_kind`,
  `model`, `prompt_template`, `template_sha`. Verified at HEAD.
- `agents/termlink/termlink.sh:cmd_dispatch` (lines 494-636) writes
  `meta.json` to per-worker `<wdir>` only. No envelope write. Verified
  at HEAD.
- T-1700 harness `tools/t1700-ollama-harness.sh` invokes
  `fw termlink dispatch --task-type ollama-research`, not
  `fw resolver dispatch`. Verified at HEAD.
- `fw orchestrator status` post-T-1712 fix shows 3 real dispatches —
  all from `fw resolver dispatch` calls during T-1696/T-1697/T-1698
  development. T-1700 harness's 13 real-traffic dispatches don't appear.
  Verified live.
- Outcome enrichment fires from `lib/update-task.sh` on `--status
  work-completed`, calling `fw outcome backprop <task_id>` which joins
  outcomes against `.context/dispatches.jsonl` by `task_id`. With no
  envelope row, the join produces zero rows. Verified by code reading.

**Risk acknowledged:**

- The structural fix may surface a flood of historical bypass dispatches
  if applied retroactively. Forward-only application proposed; the
  forensic record of "we couldn't see X" is itself analytics-relevant.
- A test harness writing real envelope rows would pollute analytics.
  Mitigation: `FW_DISPATCH_TEST_MODE=1` env var that skips envelope
  writes when set; tests opt in; production callers don't.
- Fixing this does NOT close G-064 — new consumers (T-1684 etc) still
  needed. T-1714 just removes the structural reason existing consumers
  silently don't count.

## Verification

# Inception — no shell verification required.

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

**Rationale**: Three convergent reasons:

1. **The bypass is structural, not isolated.** RCA shows two parallel
   write surfaces (`lib/resolver.py` envelope writer vs `agents/termlink/
   termlink.sh:cmd_dispatch` direct writer with `meta.json` only). T-1700
   harness is the smoking gun, but the structural condition affects every
   future consumer that needs flags resolver doesn't yet pass through.
   Bypass survey spike (#1) will quantify, but the structural pattern is
   already evident in code at HEAD.

2. **G-064 is structurally blocked until this closes.** The arc's
   headline mechanic is "agent dispatches → orchestrator picks model →
   user observes the routing decision live on /orchestrator". Bypass
   dispatches don't appear on /orchestrator. Until termlink-dispatch
   bypass is either eliminated or counted as `direct-bypass`,
   "first real production consumer" claims for the substrate are
   uninhabited regardless of how many real consumers we add. T-1684
   (daily health-check cron) and any other G-064 candidate inherit this
   blocker if they pick the wrong path.

3. **The fix is bounded.** Three Prevention paths catalogued in RCA;
   the cheapest (envelope-from-bypass with `workflow_resolved_via:
   "direct-bypass"`) is ~30 LOC in `cmd_dispatch` plus a regression test.
   The append-only contract is preserved. Outcome back-prop (T-1697
   hook) keys off task_id and would pick up bypass envelopes without
   changes (assumption A4 to be confirmed).

**Date**: 2026-05-04T09:56:32Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-04T08:17:14Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-04T09:56:32Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Three convergent reasons:

1. **The bypass is structural, not isolated.** RCA shows two parallel
   write surfaces (`lib/resolver.py` envelope writer vs `agents/termlink/
   termlink.sh:cmd_dispatch` direct writer with `meta.json` only). T-1700
   harness is the smoking gun, but the structural condition affects every
   future consumer that needs flags resolver doesn't yet pass through.
   Bypass survey spike (#1) will quantify, but the structural pattern is
   already evident in code at HEAD.

2. **G-064 is structurally blocked until this closes.** The arc's
   headline mechanic is "agent dispatches → orchestrator picks model →
   user observes the routing decision live on /orchestrator". Bypass
   dispatches don't appear on /orchestrator. Until termlink-dispatch
   bypass is either eliminated or counted as `direct-bypass`,
   "first real production consumer" claims for the substrate are
   uninhabited regardless of how many real consumers we add. T-1684
   (daily health-check cron) and any other G-064 candidate inherit this
   blocker if they pick the wrong path.

3. **The fix is bounded.** Three Prevention paths catalogued in RCA;
   the cheapest (envelope-from-bypass with `workflow_resolved_via:
   "direct-bypass"`) is ~30 LOC in `cmd_dispatch` plus a regression test.
   The append-only contract is preserved. Outcome back-prop (T-1697
   hook) keys off task_id and would pick up bypass envelopes without
   changes (assumption A4 to be confirmed).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-74039627
- **Timestamp:** 2026-06-02T14:59:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-04T09:56:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
