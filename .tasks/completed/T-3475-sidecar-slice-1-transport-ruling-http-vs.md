---
id: T-3475
name: "sidecar slice 1 transport ruling: HTTP vs unix socket vs TermLink RPC, measured
  against TermLink's actual addressing model"
description: >
  Inception: sidecar slice 1 transport ruling: HTTP vs unix socket vs TermLink RPC,
  measured against TermLink's actual addressing model

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [arc:parallel-execution-aef]
components: []
related_tasks: []
arc_id: parallel-execution-aef
created: 2026-09-25T15:34:34Z
last_update: 2026-09-25T19:43:49Z
date_finished: 2026-09-25T19:43:49Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-09-25T15:35:45Z'
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
  - ts: '2026-09-25T15:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=146,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3475: sidecar slice 1 transport ruling: HTTP vs unix socket vs TermLink RPC, measured against TermLink's actual addressing model

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Is the slice 1 API HTTP, a unix socket, or a TermLink RPC?**
  confidence: 3
  disposition: answered
  rationale: Measured — TermLink addresses only ephemeral sessions or durable broadcast topics, so RPC cannot express push-to-a-durable-receiver; a unix socket is same-host only and would need a second cross-host path, which is the Amendment 1 degradation. HTTP is the only single-path option. Operator ruling still required.

- **IW-2: Does the hub survive beneath the API, or does the API replace it?**
  confidence: 3
  disposition: answered
  rationale: It survives, doing the three things HTTP does not — discovery (circuit-id → host:port, the hub already holds the fleet map), blob transfer (D-645), and fallback carrier when HTTP is unreachable. Matches T-3397's uniform-path amendment.

- **IW-3: How is an HTTP sidecar listener authenticated?**
  confidence: 1
  disposition: deferred
  rationale: A listener that accepts injected prompts is a remote-code-execution surface. TermLink solved this for itself with TOFU + per-hub secrets and observe/interact/control/execute scopes. Not decided here on purpose — it belongs on slice 1's own ACs, named before the port is open rather than discovered after.

- **IW-4: Does this ruling settle the tick cadence and readiness predicate?**
  confidence: 3
  disposition: dissolved
  rationale: Not a transport question. §4 of the target architecture owns it and it stays open there; recorded so it is not silently absorbed into the transport decision.

- **IW-5: Which address grammar does the sidecar speak — T-3433's `inbox:<hub>/<project>` or arc-020's V9 `aef::host=…::@agent::`?**
  confidence: 3
  disposition: answered
  rationale: OPERATOR RULING 2026-09-25 — **converge on V9**. Option 1 of three offered (converge / adapt-with-translation / supersede V9). Chosen against the stated cost that the messaging code needs rewriting. This supersedes T-3433's "Rejected: host-first 5-segment addresses" for the sidecar's addressing, and makes arc-020's headline mechanic reachable for the first time. Recorded verbatim in the Dialogue Log; the formal inception decision is still the operator's to record.

- **IW-6: Is the transport a free choice at all, or is it the ladder's `probe` seam?**
  confidence: 3
  disposition: answered
  rationale: The latter — and this corrects the framing of IW-1. `lib/aef_resolve.py:resolve(target, probe)` takes `Callable[[AEFAddress], bool]` and "calls probe and nothing else". The transport implements the probe. HTTP still wins, but because V9 carries `host=<fqdn>` (the fact T-3433 withholds and HTTP needs), not because of the discovery hand-wave in the original recommendation.

- **IW-7: Should slice 1 keep the proposed HTTP→topics transport fallback?**
  confidence: 3
  disposition: answered
  rationale: No — drop it. The ladder already degrades by address specificity, which is the better axis. Two fallback mechanisms beside each other can disagree about why a message did not land, which is how the `INJECTED_NOW` ambiguity was born. Slice 1 must also bind to `resolve()` and never `provision()`: the design names the hazard ("a typo'd address could provision a whole hub"), so a refusal test belongs in its ACs.

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

Measured: TermLink addresses sessions (ephemeral) or topics (durable but broadcast-pull). There is no durable service address, so TermLink RPC cannot express push-to-a-durable-receiver, which is the one primitive slice 1 needs. Unix socket is same-host only and fails Amendment 1. HTTP is the only option that is one path both same-host and cross-host. Recommend HTTP for the API with TermLink retained beneath for discovery, blob transfer and fallback carrier.

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

**Rationale**: Measured: TermLink addresses sessions (ephemeral) or topics (durable but broadcast-pull). There is no durable service address, so TermLink RPC cannot express push-to-a-durable-receiver, which is the one primitive slice 1 needs. Unix socket is same-host only and fails Amendment 1. HTTP is the only option that is one path both same-host and cross-host. Recommend HTTP for the API with TermLink retained beneath for discovery, blob transfer and fallback carrier.

**Date**: 2026-09-25T19:43:48Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-25T15:35:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-25T15:37:24Z — status-update [task-update-agent]
- **Change:** tags: +arc:parallel-execution-aef

### 2026-09-25T19:43:48Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Measured: TermLink addresses sessions (ephemeral) or topics (durable but broadcast-pull). There is no durable service address, so TermLink RPC cannot express push-to-a-durable-receiver, which is the one primitive slice 1 needs. Unix socket is same-host only and fails Amendment 1. HTTP is the only option that is one path both same-host and cross-host. Recommend HTTP for the API with TermLink retained beneath for discovery, blob transfer and fallback carrier.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bbec31fe
- **Timestamp:** 2026-09-25T19:43:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-7
     - evidence: `IW-7 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-d3537cc1
- **Timestamp:** 2026-09-25T19:43:50Z
- **Overall:** UNVERIFIED
- **Claims:** 0
- No verifiable claims found in ## Recommendation

### 2026-09-25T19:43:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
