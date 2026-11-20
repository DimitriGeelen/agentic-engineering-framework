---
id: T-5300
name: "Shared worker contract: should wc add a 'withdrawn' outcome (dispatched ->
  done, never-started jobs only) so a submitter can withdraw a queued pool job? (ring20
  T-2790)"
description: >
  Inception: Shared worker contract: should wc add a 'withdrawn' outcome (dispatched
  -> done, never-started jobs only) so a submitter can withdraw a queued pool job?
  (ring20 T-2790)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
waiting_on: agent
revisit_at: 2026-11-27
created: 2026-11-20T12:45:49Z
last_update: 2026-11-20T16:27:12Z
date_finished: 2026-11-20T16:27:12Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-11-20T13:00:29Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=124,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-20T13:01:07Z'
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

# T-5300: Shared worker contract: should wc add a 'withdrawn' outcome (dispatched -> done, never-started jobs only) so a submitter can withdraw a queued pool job? (ring20 T-2790)

## Problem Statement

A job submitted to the shared worker pool cannot be taken back before it starts. In lib/dispatch_records.py (contract wc/0.3.3) an attempt in `dispatched` ends only through start+complete by the worker, or, past `deadline_dispatched`, moves to `unknown` and raises an operator-resolve notice. ring20 (T-2790, msg 3d5e1fda, operator-requested, relayed via 1409): 9 judge jobs of 1409 were held 5 h on two nodes on 2026-11-20 with no way to withdraw them. Proposed: `dispatched -> done` with a new outcome `withdrawn` (e.g. `Store.withdraw(dispatch_id, attempt, *, reason, actor, writer='hub')`), allowed only from `dispatched` (never started), refused otherwise (cas_mismatch), logged with actor and reason, no notice; ring20's poold would call it on a `ring20.pool.withdraw/1` request and every view treats it as a normal terminal state. The contract (docs/specs/shared-worker-contract-transitions.md) is owned jointly by AEF, TermLink and ring20 (docs/reports/T-4752/spec-proposal.md), so this is a spec change. Wanted "this week", not urgent.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Does TermLink (co-owner of wc) agree to a `withdrawn` outcome and the `dispatched -> done` transition, and as which spec revision (v0.3.4)?**
  confidence: 3
  disposition: answered
  rationale: 010 msg ab85e88e: agrees, as a T3b variant (to=done, expected_prior=dispatched, withdrawn flag); v0.3.4 must define the evidence (sha256 of the reason, result_kind none) and that a withdrawal closes open questions; TermLink builds it with conformance vectors once v0.3.4 exists
- **IW-2: Who may withdraw (submitter only? hub? operator?), and how is the submitter proven, given the worker's nonce/credential model?**
  confidence: 3
  disposition: answered
  rationale: 010 msg ab85e88e: only the holder of the attempt's credentials (nonce plus the supervisor token dispatch.allocate returns once), on an Execute-scope connection; the hub's sweep never withdraws; an operator path would be a separate command and decision
- **IW-3: What happens if withdraw races a worker's start (the attempt moves to `running` between check and write) — is the existing compare-and-set enough?**
  confidence: 3
  disposition: answered
  rationale: 010 msg ab85e88e: yes, T2 and the withdrawal each run in one IMMEDIATE transaction checking the actual state; one wins, the other gets cas_mismatch; v0.3.4 must state that a supervisor starts the worker only after its T2 succeeded

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

**Recommendation:** GO

**Rationale:**

Add a `withdrawn` outcome to the shared worker contract as v0.3.4, on the shape all three owners now agree on. A job that never started can be taken back by whoever holds that attempt's credentials (the nonce plus the supervisor token returned once at allocation), nobody else; the hub's sweep never withdraws; there is no operator path in this change. It is a `dispatched -> done` transition with outcome `withdrawn`, allowed only from `dispatched` with the current attempt (cas_mismatch from `running`, forbidden_transition from `done`/`lost`/`unknown`, a repeat deduped), carrying sha256 of the reason as evidence with `result_kind: none`, closing the attempt's open questions, logged with actor and reason, raising no notice. The race with a starting worker is safe because both writes are compare-and-set in one transaction; v0.3.4 adds the rule that a supervisor starts the worker only after its start transition succeeded. Build: (1) write v0.3.4 in docs/specs/shared-worker-contract-transitions.md and send it to TermLink and ring20; (2) AEF's lib/dispatch_records.py `Store.withdraw` with the four conformance cases 010 named (from dispatched; race with start; from running; repeat); TermLink and ring20 build theirs against the same vectors.

**Evidence:**

- ring20 request (msg 3d5e1fda): 9 jobs held 5 h with no way back.
- TermLink's answer from its backend (msg ab85e88e): agreement, the T3b-variant shape, credentials-only, CAS race safety, two spec points (evidence digest, close open questions) and one supervisor rule; docs/reports/T-5300-withdraw-outcome.md.
- Contract ownership: docs/reports/T-4752/spec-proposal.md (AEF, TermLink, ring20).

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

**Rationale**: Add a `withdrawn` outcome to the shared worker contract as v0.3.4, on the shape all three owners now agree on. A job that never started can be taken back by whoever holds that attempt's credentials (the nonce plus the supervisor token returned once at allocation), nobody else; the hub's sweep never withdraws; there is no operator path in this change. It is a `dispatched -> done` transition with outcome `withdrawn`, allowed only from `dispatched` with the current attempt (cas_mismatch from `running`, forbidden_transition from `done`/`lost`/`unknown`, a repeat deduped), carrying sha256 of the reason as evidence with `result_kind: none`, closing the attempt's open questions, logged with actor and reason, raising no notice. The race with a starting worker is safe because both writes are compare-and-set in one transaction; v0.3.4 adds the rule that a supervisor starts the worker only after its start transition succeeded. Build: (1) write v0.3.4 in docs/specs/shared-worker-contract-transitions.md and send it to TermLink and ring20; (2) AEF's lib/dispatch_records.py `Store.withdraw` with the four conformance cases 010 named (from dispatched; race with start; from running; repeat); TermLink and ring20 build theirs against the same vectors.

**Date**: 2026-11-20T16:27:10Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-20T16:24:20Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-20T16:27:10Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Add a `withdrawn` outcome to the shared worker contract as v0.3.4, on the shape all three owners now agree on. A job that never started can be taken back by whoever holds that attempt's credentials (the nonce plus the supervisor token returned once at allocation), nobody else; the hub's sweep never withdraws; there is no operator path in this change. It is a `dispatched -> done` transition with outcome `withdrawn`, allowed only from `dispatched` with the current attempt (cas_mismatch from `running`, forbidden_transition from `done`/`lost`/`unknown`, a repeat deduped), carrying sha256 of the reason as evidence with `result_kind: none`, closing the attempt's open questions, logged with actor and reason, raising no notice. The race with a starting worker is safe because both writes are compare-and-set in one transaction; v0.3.4 adds the rule that a supervisor starts the worker only after its start transition succeeded. Build: (1) write v0.3.4 in docs/specs/shared-worker-contract-transitions.md and send it to TermLink and ring20; (2) AEF's lib/dispatch_records.py `Store.withdraw` with the four conformance cases 010 named (from dispatched; race with start; from running; repeat); TermLink and ring20 build theirs against the same vectors.

### 2026-11-20T16:27:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7005ed9b
- **Timestamp:** 2026-11-20T16:27:13Z
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

- **Scan ID:** RC-a06562ca
- **Timestamp:** 2026-11-20T16:27:14Z
- **Overall:** CONFIRMED
- **Claims:** 2

| Claim | Type | Status |
|-------|------|--------|
| `Store.withdraw` | module | ✓ pass |
| `T-4752` | task | ✓ pass |
