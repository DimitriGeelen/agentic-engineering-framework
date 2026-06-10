# T-2320: F-ORCH retire-or-keep brief

**Status:** Advisory (Sovereign decision)
**Recommendation:** KEEP (refine `retire_when:` to a sharper criterion)
**Author:** agent
**Date:** 2026-06-10

---

## 1. When F-ORCH was added

- **Commit:** `1159898f3` — T-1917 "BVP T-NEW-2 — policy/value-drivers.yaml schema + initial content"
- **Refined in:** `5a3b643cb` — T-2166 "land value-drivers.yaml v3 schema"
- **Current definition** (verbatim from `policy/value-drivers.yaml`):

  > **id:** F-ORCH
  > **name:** Orchestration Leverage
  > **weight:** 5 (strategic/forward bet; sits below Recall by design)
  > **rationale:** Rewards expanding the surface that can be routed to a NON-primary executor — how much a piece of work raises the framework's capacity to dispatch, fan out, and run unattended rather than serially through the primary agent. Maps onto the Initiative axis (L4→L5→L6) and the in-flight orchestrator substrate (T-1643). No other driver scores work by how much it raises that ceiling.
  > **retire_when:** Multi-agent orchestration criterion goes green / orchestrator substrate (T-1643) lands in production.

## 2. What F-ORCH surfaced (load-bearing evidence)

- **Influence breadth:** F-ORCH scored across **170 task files** (72 active + 98 completed) since landing. It is one of two free drivers in the active pool (alongside F-RECALL); the active driver shelf is 2/5.
- **Behavioural effect:** F-ORCH gave orchestrator-substrate work (the T-1643 arc, dispatch infrastructure, peer-consult, capability-overlay arc) a scoring axis that no constitutional driver (D1–D4) covered. Without it, that work registered as low-BVP and would have been deferred under HV-LC selection.
- **Triggering event for the advisory:** G-064 (orchestrator substrate has zero production consumers) was closed `2026-06-10T13:54:54Z` with verdict `READY` (481 dispatches, 290 cron firings, escalation-triage workflow live since `2026-05-14`). T-1643 sits in `.tasks/completed/`. Both retire-when clauses literally true.

## 3. Pipeline check (work that would re-justify F-ORCH in the next 30 days)

- **arc-011 parallel-execution-aef** (T-2303 inception, status: started-work) — the *exact* kind of orchestration substrate uplift the driver was created to value. The agent-drafted Spike 1 wire-evidence test (WE-1: ≥2 `status: in_flight` rows with non-overlapping `artifactsWrites` globs) is a Level 5 outcome on the F-ORCH rubric ("parallel/multi-perspective dispatch, or advances the orchestrator").
- **T-1820 v2 peer-consult joint smoke-test** — §ACD-paused on headline mechanic; once user-facing trigger lands (T-1821 follow-up), the demo is an F-ORCH 4–5 outcome.
- **T-1719 Embeddings strategy V1 Slice 1** (HV-LC top, BVP 103) — post-write hook for an embeddings indexer would expand the substrate surface that workers can route against.
- **T-1639 TermLink throughput benchmark** — would establish dispatch-capacity baseline; F-ORCH-scoring exposes whether benchmarks (vs anecdote) actually justify "uplift" claims downstream.

## 4. Retire cost vs keep cost

**Retire cost (RETIRE F-ORCH now):**
- Drops the *single* scoring dimension under which the upcoming arc-011 parallel-execution work would rank as HV-LC. T-2303 would re-rank as low-BVP if F-ORCH is removed.
- The four constitutional drivers (D1–D4) do not score orchestration uplift directly — D1 is failure-driven, D2 is reliability, D3 is usability, D4 is portability. None reward "raises the framework's dispatch ceiling."
- Loses the recompute audit trail for the 170 tasks already scored on F-ORCH (history kept in `.context/bvp-weight-history.yaml`, but new scoring drops the dimension).

**Keep cost (KEEP F-ORCH, status quo):**
- One ongoing audit WARN line per `fw audit --section structure` invocation (cron + pre-push). Cosmetic noise; does not block any gate.
- Estimator continues proposing F-ORCH scores on new tasks; operator continues confirming via `fw bvp confirm`. No incremental cost.

**Silence cost (KEEP F-ORCH, `FW_RETIRE_WHEN_ADVISORY=0`):**
- Suppresses the WARN globally. Loses the surface for the *other* free driver (F-RECALL) when its retire-when criterion eventually fires.

## 5. Recommendation: KEEP — refine `retire_when:` text

The retire-when text is too narrow. T-1643's completion was foundational substrate (the orchestrator router lib), not the production payoff F-ORCH was created to surface. The *real* retire criterion is the headline-mechanic instance of an orchestration arc firing in production (e.g. arc-011 parallel-execution demonstrating ≥2 concurrent in-flight dispatches with non-overlapping write globs, or v2 peer-consult firing user-side).

**Operator commands:**

```bash
# Recommended: KEEP F-ORCH, refine retire_when text
# (manual edit; no Sovereign verb gates value-drivers.yaml retire_when refinement)
$EDITOR policy/value-drivers.yaml
# Replace F-ORCH retire_when block with sharper criterion, e.g.:
#   retire_when: >
#     arc-011 parallel-execution ships its headline mechanic in production
#     (≥2 concurrent in-flight dispatches with non-overlapping artifactsWrites
#     globs captured in dispatches.jsonl) AND v2 peer-consult fires user-side.
#     Until both gates close, F-ORCH continues to score orchestration-uplift work.

# Alternative A: SILENCE advisory (keeps F-ORCH AND F-RECALL retire-checks off)
fw config set FW_RETIRE_WHEN_ADVISORY 0

# Alternative B: RETIRE F-ORCH (Sovereign — agent cannot run this)
# Comment out the F-ORCH entry in policy/value-drivers.yaml and move it to a
# `retired_drivers:` section, OR call (when implemented):
#   fw bvp driver --remove F-ORCH --rationale "T-1643 + G-064 closed; arc-011 will get scored on D1-D4 + new V_PROMPT_QUALITY/V_CONTEXT_FABRIC/V_COMPONENT_FABRIC after T-2306 lands."
```

**Decision shape:** if KEEP-with-refinement, the operator edits `policy/value-drivers.yaml` directly (manual edit; not Sovereign-gated for `retire_when:` text refinement, only for `--add` / `--remove` / weight changes). Refinement is a policy edit but not a structural mutation of the driver pool — agent could draft the exact replacement text on operator request.
