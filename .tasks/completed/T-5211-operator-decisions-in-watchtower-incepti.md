---
id: T-5211
name: "Operator decisions in Watchtower (inception GO first) reach the project's own
  agent as a sidecar notice, delivered only when the session is idle"
description: >
  Inception: Operator decisions in Watchtower (inception GO first) reach the project's
  own agent as a sidecar notice, delivered only when the session is idle

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-11-17T20:46:40Z
last_update: 2026-11-17T23:17:20Z
date_finished: 2026-11-17T23:17:20Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-11-17T20:47:23Z'
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
  - ts: '2026-11-17T21:00:36Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=128,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5211: Operator decisions in Watchtower (inception GO first) reach the project's own agent as a sidecar notice, delivered only when the session is idle

## Problem Statement

The operator, 2026-11-17: when an inception gets a GO, the agent should get a trigger to act on it. If not immediately, then through the sidecar, delivered when the session is ready, never injected into a busy interaction. Today the GO goes unseen. This session learned of T-5199's GO (commits 83676d1ac, 84b9e1cb5) only because a later commit was refused. Watchtower's decide chain (web/decide_runner.py) commits the decision and tells no one. The idle-aware delivery already exists: lib/sidecar/inject.py injects non-urgent mail only into a session whose record says ready, and only urgent mail (R5) bypasses that. Research: docs/reports/T-5211-decision-notice-to-agent.md.

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

- **IW-1: Which operator actions in Watchtower should notify the agent: inception decisions only, or also review approvals (human criteria ticked), approved paid-review proposals, accepted restatements and Tier 0 approvals?**
  confidence: 3
  disposition: answered
  rationale: Operator, 2026-11-18 ("all yes" to proposal 1): inception decisions, human criteria ticked on the Watchtower review page, restatement accept/reject, and paid-review approval. Not Tier 0, because the agent is normally waiting on it in the same turn.
- **IW-2: Can a project post to its own sidecar inbox today, and does the receiver deliver it to its own session when idle (lib/sidecar/addressing.py treats the own inbox specially, line 604)?**
  confidence: 3
  disposition: answered
  rationale: Yes, verified 2026-11-17 21:47Z. `fw sidecar send --to 999-Agentic-Engineering-Framework --notice` was stored as RECEIVED by this project's receiver (msg 254f3e5a) and surfaced in this session's prompt at the next idle point, between turns, not mid-interaction.
- **IW-3: The prompt hook frames all sidecar mail as untrusted peer data. Is that right for a notice from the project's own Watchtower? (Proposal: yes. The notice is only a trigger, and the agent reads the decision from the task file, which is the source of truth.)**
  confidence: 3
  disposition: answered
  rationale: Operator, 2026-11-18 ("all yes" to proposal 2): yes. The notice is a trigger only; the agent acts on the task file, so a forged notice cannot start work.
- **IW-4: With no session running, does the notice wait for the next session's start alerts, and is anything lost if Watchtower restarts mid-chain?**
  confidence: 3
  disposition: answered
  rationale: Operator, 2026-11-18 ("all yes" to proposal 3). With no ready session the message stays flagged and surfaces in the next session's start alerts (lib/sidecar/inject.py). The decide chain runs detached (web/decide_runner.py, T-3749), so a Watchtower restart does not stop it. A failed post never fails the action and is logged.

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

**Recommendation:** GO, wide scope: every Watchtower action that hands the next step to the agent

**Rationale:**

The idle-aware delivery already exists (lib/sidecar/inject.py: non-urgent mail goes only to a session whose record says ready; R5 urgent is the only bypass). What is missing is the trigger. web/decide_runner.py commits the decision and tells nobody, and the review, restatement and paid-proposal actions in Watchtower do the same. The proposal is one non-urgent notice to the project's own inbox per action, sent after the action's commit lands. It needs no new delivery machinery. If no session is running, the notice waits for the next session's alerts. If posting fails, the action still goes through and the failure is logged. The notice is only a trigger: the agent reads the decision from the task file before acting.

Build slices if GO:
1. Inception decisions (GO / NO-GO / DEFER) from the decide chain.
2. Human criteria ticked on the Watchtower review page, restatement accept/reject, and paid-proposal approval.

Tier 0 approvals are excluded: the agent is normally waiting on them in the same turn.

**Evidence:**

- This session learned of T-5199's GO (83676d1ac, 84b9e1cb5) only because a later commit was refused.
- web/decide_runner.py has no notify step. The decide chain ends at its follow-up commit.
- lib/sidecar/inject.py: non-urgent mail is injected only into a session whose own record says ready.
- IW-2 verified: a notice sent to the project's own address (msg 254f3e5a) was delivered to this session at its next idle point (2026-11-17 21:47Z).
- Research: docs/reports/T-5211-decision-notice-to-agent.md

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

**Rationale**: Recommendation: GO, wide scope: every Watchtower action that hands the next step to the agent

Rationale:

The idle-aware delivery already exists (lib/sidecar/inject.py: non-urgent mail goes only to a session whose record says ready; R5 urgent is the only bypass). What is missing is the trigger. web/decide_runner.py commits the decision and tells nobody, and the review, restatement and paid-proposal actions in Watchtower do the same. The proposal is one non-urgent notice to the project's own inbox per action, sent after the action's commit lands. It needs no new delivery machinery. If no session is running, the notice waits for the next session's alerts. If posting fails, the action still goes through and the failure is logged. The notice is only a trigger: the agent reads the decision from the task file before acting.

Build slices if GO:
1. Inception decisions (GO / NO-GO / DEFER) from the decide chain.
2. Human criteria ticked on the Watchtower review page, restatement accept/reject, and paid-proposal approval.

Tier 0 approvals are excluded: the agent is normally waiting on them in the same turn.

Evidence:

- This session learned of T-5199's GO (83676d1ac, 84b9e1cb5) only because a later commit was refused.
- web/decide_runner.py has no notify step. The decide chain ends at its follow-up commit.
- lib/sidecar/inject.py: non-urgent mail is injected only into a session whose own record says ready.
- IW-2 verified: a notice sent to the project's own address (msg 254f3e5a) was delivered to this session at its next idle point (2026-11-17 21:47Z).
- Research: docs/reports/T-5211-decision-notice-to-agent.md

**Date**: 2026-11-17T23:17:18Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-17T20:47:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-17T23:17:18Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO, wide scope: every Watchtower action that hands the next step to the agent

Rationale:

The idle-aware delivery already exists (lib/sidecar/inject.py: non-urgent mail goes only to a session whose record says ready; R5 urgent is the only bypass). What is missing is the trigger. web/decide_runner.py commits the decision and tells nobody, and the review, restatement and paid-proposal actions in Watchtower do the same. The proposal is one non-urgent notice to the project's own inbox per action, sent after the action's commit lands. It needs no new delivery machinery. If no session is running, the notice waits for the next session's alerts. If posting fails, the action still goes through and the failure is logged. The notice is only a trigger: the agent reads the decision from the task file before acting.

Build slices if GO:
1. Inception decisions (GO / NO-GO / DEFER) from the decide chain.
2. Human criteria ticked on the Watchtower review page, restatement accept/reject, and paid-proposal approval.

Tier 0 approvals are excluded: the agent is normally waiting on them in the same turn.

Evidence:

- This session learned of T-5199's GO (83676d1ac, 84b9e1cb5) only because a later commit was refused.
- web/decide_runner.py has no notify step. The decide chain ends at its follow-up commit.
- lib/sidecar/inject.py: non-urgent mail is injected only into a session whose own record says ready.
- IW-2 verified: a notice sent to the project's own address (msg 254f3e5a) was delivered to this session at its next idle point (2026-11-17 21:47Z).
- Research: docs/reports/T-5211-decision-notice-to-agent.md

### 2026-11-17T23:17:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-362fc4d6
- **Timestamp:** 2026-11-17T23:17:23Z
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

- **Scan ID:** RC-9cbf4465
- **Timestamp:** 2026-11-17T23:17:23Z
- **Overall:** CONFIRMED
- **Claims:** 1

| Claim | Type | Status |
|-------|------|--------|
| `T-5199` | task | ✓ pass |
