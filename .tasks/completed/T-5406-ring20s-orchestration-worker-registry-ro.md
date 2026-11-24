---
id: T-5406
name: "Ring20's orchestration (worker registry, routes, commissions, gates, supervisor):
  separate plug-in module like designer/TermLink/ontology, or an integral part of
  AEF?"
description: >
  Inception: Ring20's orchestration (worker registry, routes, commissions, gates,
  supervisor): separate plug-in module like designer/TermLink/ontology, or an integral
  part of AEF?

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
waiting_on: agent
revisit_at: 2026-12-01
created: 2026-11-24T19:11:24Z
last_update: 2026-11-24T23:06:40Z
date_finished: 2026-11-24T23:06:40Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-11-24T19:11:40Z'
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
cost_estimate_proposed:
  - ts: '2026-11-24T19:15:27Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=128,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5406: Ring20's orchestration (worker registry, routes, commissions, gates, supervisor): separate plug-in module like designer/TermLink/ontology, or an integral part of AEF?

## Problem Statement

Ring20 Manager built a substantial orchestration capability (arc-009): a registry of worker types, routes, commissions, admission gates, caps, a supervisor with halts, and candidates that only the operator admits. It is visible at http://192.168.10.122:3000/orchestration. AEF has a dispatch substrate (`fw termlink dispatch`, `fw orchestrator status`, resolver workflows) and a multi-vendor review panel, and co-owns the shared dispatched-worker contract with TermLink and ring20 (T-4435, wc v0.3.4). The operator is unsure how much of ring20's work AEF has incorporated, and wants it brought in. Either as a separate module that plugs in (like the workflow designer from 832, TermLink and the ontology work), or as an integral part of AEF. Research: `docs/reports/T-5406-orchestration-module.md`.

## Assumptions

- Ring20's orchestration contains generic parts (registry, routes, gates, commission ledger, supervisor) and ring20-specific parts (hosts, pools, uids, its own entries).
- The shared worker contract (wc v0.3.4) is already the interface between a dispatcher and a supervisor, so the module boundary may follow it.

## Open Questions

- **IW-1: Inventory: which of ring20's orchestration components exist, where is their code, and which does AEF already have an equivalent of?**
  confidence: 3
  disposition: answered
  rationale: ring20 T-2868 inventory (paths, ~4,900 + 4,700 test lines, parked since 2026-10-20); AEF comparison table in docs/reports/T-5406-orchestration-module.md.
- **IW-2: Which parts are generic (any AEF project) and which are ring20-specific?**
  confidence: 3
  disposition: answered
  rationale: T-2868 boundary sketch — generic core (supervisor state machine, ledger, gates 4.1-4.11, halts, registry/admission schema, view, contract tests) vs ring20 adapters (uid/containment, preflight hosts, routes/logins, entries, role chain).
- **IW-3: Separate plug-in module (own repo, versioned, pinned by AEF like the designer) or integral to AEF — and who owns it?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-11-24 chose option 2 on both sides (ring20 msg babd07bb; AEF "3 ok"): separate versioned module, ring20 as producer, after ring20 specifics move into config.

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

**Recommendation:** GO — option 2: ring20's orchestration engine becomes a separate, versioned module, with ring20 as producer and AEF pinning a version (as with the workflow designer).

**Rationale:** The operator chose option 2 on both sides on 2026-11-24 (ring20 msg babd07bb; AEF: "3 ok"). Ring20's inventory (T-2868) shows a generic core: supervisor state machine, ledger, gates 4.1-4.11, halts, registry/admission schema, view and contract tests. Its ring20 parts (worker uid range, containment, preflight hosts, launcher list, cap defaults, routes and logins, entries) can move into config. A module keeps those out of what every AEF consumer receives, which is the lesson of T-5392.

**Evidence:**
- Ring20 inventory: http://192.168.10.122:3000/file/docs/reports/T-2868-arc009-orchestration-inventory.md
- AEF comparison and options: `docs/reports/T-5406-orchestration-module.md`
- Ring20 first: move hard-coded values into config, then split out the module (their task). AEF afterwards: a pickup task pins the first module release and connects it through the shared worker contract (wc v0.3.4).
- Accepted risk: the engine is parked (no runs since 2026-10-20) and AEF has no second user yet, so the module starts dormant.

**Evidence:**

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

**Rationale**: The operator chose option 2 on both sides on 2026-11-24 (ring20 msg babd07bb; AEF: "3 ok"). Ring20's inventory (T-2868) shows a generic core: supervisor state machine, ledger, gates 4.1-4.11, halts, registry/admission schema, view and contract tests. Its ring20 parts (worker uid range, containment, preflight hosts, launcher list, cap defaults, routes and logins, entries) can move into config. A module keeps those out of what every AEF consumer receives, which is the lesson of T-5392.

**Date**: 2026-11-24T23:06:39Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-24T19:11:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-24T23:06:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The operator chose option 2 on both sides on 2026-11-24 (ring20 msg babd07bb; AEF: "3 ok"). Ring20's inventory (T-2868) shows a generic core: supervisor state machine, ledger, gates 4.1-4.11, halts, registry/admission schema, view and contract tests. Its ring20 parts (worker uid range, containment, preflight hosts, launcher list, cap defaults, routes and logins, entries) can move into config. A module keeps those out of what every AEF consumer receives, which is the lesson of T-5392.

### 2026-11-24T23:06:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-37cbd3cf
- **Timestamp:** 2026-11-24T23:06:42Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Scope:** static anti-pattern scan; PASS means no anti-pattern was found, not that the criteria hold
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-f83d489b
- **Timestamp:** 2026-11-24T23:06:42Z
- **Overall:** CONFIRMED
- **Claims:** 3

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-5406-orchestration-module.md` | file | ✓ pass |
| `T-2868` | task | ✓ pass |
| `T-5392` | task | ✓ pass |
