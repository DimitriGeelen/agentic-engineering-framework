---
id: T-5190
name: "Cross-project subscription quota overview: record a neutral subscription id
  per worker/dispatch, capture harness limit events with reset time, a per-host overview
  (tokens per subscription, 5h/7d windows, next reset), and a pre-run quota check
  (1409 T-6158 proposal)"
description: >
  Inception: Cross-project subscription quota overview: record a neutral subscription
  id per worker/dispatch, capture harness limit events with reset time, a per-host
  overview (tokens per subscription, 5h/7d windows, next reset), and a pre-run quota
  check (1409 T-6158 proposal)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-11-16T15:30:03Z
last_update: 2026-11-17T08:57:23Z
date_finished: 2026-11-17T08:57:23Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-11-16T16:00:30Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=125,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-16T16:00:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-5190: Cross-project subscription quota overview: record a neutral subscription id per worker/dispatch, capture harness limit events with reset time, a per-host overview (tokens per subscription, 5h/7d windows, next reset), and a pre-run quota check (1409 T-6158 proposal)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

The operator holds several subscriptions: three Anthropic, GLM, Codex, Antigravity and others. Several projects and the ring20 pool nodes share them. On 2026-11-16 the shared Claude subscription on the four pool nodes hit its weekly limit ("resets Nov 21, 5am (UTC)") and nobody saw it coming. The subscriptions give no counter, ring20 sees none, and each project knows only its own use. 1409 (their T-6158) proposed, at their operator's prompting, that AEF provide:
- (1) a neutral subscription id per worker/dispatch, never an account identifier;
- (2) harness limit messages captured as events with reset time;
- (3) a per-machine overview across projects (tokens per subscription in 5 h / 7 d windows, state, next reset);
- (4) a pre-run "is there enough quota for N tokens" check.

ring20 already builds the pool-side quota lock (their T-2707), and since 2026-11-17 records the account (2 or 3) per job and holds jobs at the limit instead of failing them. Who it hurts: the operator, who cannot see or plan around shared limits, and every project whose run dies mid-way. Why now: a week-long lockout of the shared Claude subscription has just happened.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

- **IW-1: Which of 1409's asks belong in AEF rather than ring20 (pool) or 055 (cockpit)? Candidates: dispatch writes a neutral subscription id into meta.json; a machine-wide, cross-project quota ledger; a shared "free / tight / at limit until" signal.**
  confidence: 2
  disposition: answered
  rationale: report F1, F2, F4 — dispatch meta.json and the review cost ledger record no subscription id, and all records are per project; AEF is the one thing every project on a machine runs, so the id at dispatch, the machine-wide ledger and the shared signal are AEF's (S2, S3, S5); the node map, pool lock and pool result field are ring20's, the display 055's
- **IW-2: Where does the subscription id come from without ever touching account identity: a registry entry like policy/review-backends.yaml naming neutral ids, set per worker kind and node by the operator?**
  confidence: 2
  disposition: answered
  rationale: report F1 / S1 — policy/review-backends.yaml already names where credentials live (never values) and a harness_class; an operator-owned registry of neutral ids beside it, assigned per worker kind (and host if needed), keeps account data out entirely
- **IW-3: Can limit messages be captured reliably? 1409's table shows six distinct wordings across claude and glm, one without a time zone; codex/antigravity/vibe showed none in 14 days.**
  confidence: 2
  disposition: answered
  rationale: report F3 / S4 — recognisable per harness from the six known wordings; a reset is recorded when the message states it (Claude: UTC explicit) and as "unknown" otherwise (GLM's zone-less time is not guessed); harnesses with no message yet get none

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

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

**Recommendation:** GO, for build slices S1–S5 in docs/reports/T-5190-subscription-quota-overview.md, in that order.

**Rationale:**

The shared Claude subscription on the pool hit a week-long limit on 2026-11-16 without warning, and no single place can see it coming. Every project on a machine keeps its own partial record. AEF's own records (dispatch meta.json, the review cost ledger) carry no subscription id at all. AEF is the only thing every project on a machine runs, so only AEF can keep the cross-project record and answer "free / tight / at limit until" for all of them.

The slices:
- **S1:** neutral ids in an operator-owned registry; account data never enters.
- **S2:** the id and tokens recorded per dispatch and per review.
- **S3:** a machine-wide append-only ledger of ids and counts.
- **S4:** per-harness recognisers for the limit messages 1409 actually saw. A reset is recorded only when the message states it; otherwise it is "unknown", never a guessed time zone.
- **S5:** a read-only `fw quota status`.

ring20's pool lock (their T-2707) and node→subscription map, and 055's display, stay theirs. S5's output is what they can read. Each slice is small and reversible.

**Evidence:**

- docs/reports/T-5190-subscription-quota-overview.md: 1409's limit-message table (six wordings, which reset times are given) and their stated needs; findings F1–F4 from AEF's own records.
- .context/dispatch/*/meta.json: fields recorded today, no subscription id. .context/costs/reviews.jsonl: backend, class and metering, no subscription id.
- policy/review-backends.yaml: credential location blocks (never values) and harness_class: the pattern S1 follows.
- 1409's report: their commit d9c4512d7, sent as text 2026-11-17 (msg 2b9fb717), since this session cannot read other projects' files.

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

**Rationale**: The shared Claude subscription on the pool hit a week-long limit on 2026-11-16 without warning, and no single place can see it coming. Every project on a machine keeps its own partial record. AEF's own records (dispatch meta.json, the review cost ledger) carry no subscription id at all. AEF is the only thing every project on a machine runs, so only AEF can keep the cross-project record and answer "free / tight / at limit until" for all of them.

The slices:

**Date**: 2026-11-17T08:57:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-16T15:30:35Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-11-17T08:47:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-11-17T08:57:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The shared Claude subscription on the pool hit a week-long limit on 2026-11-16 without warning, and no single place can see it coming. Every project on a machine keeps its own partial record. AEF's own records (dispatch meta.json, the review cost ledger) carry no subscription id at all. AEF is the only thing every project on a machine runs, so only AEF can keep the cross-project record and answer "free / tight / at limit until" for all of them.

The slices:

### 2026-11-17T08:57:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2c005fdc
- **Timestamp:** 2026-11-17T08:57:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Scope:** static anti-pattern scan; PASS means no anti-pattern was found, not that the criteria hold
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-e8466f9d
- **Timestamp:** 2026-11-17T08:57:24Z
- **Overall:** CONFIRMED
- **Claims:** 1

| Claim | Type | Status |
|-------|------|--------|
| `T-2707` | task | ✓ pass |
