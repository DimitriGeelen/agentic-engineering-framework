---
id: T-3631
name: "Cross-agent delivery: one acknowledged channel, a delivery ledger for unconfirmed
  messages, and per-agent identity (055 finding, framework:pickup 257)"
description: >
  Inception: Cross-agent delivery: one acknowledged channel, a delivery ledger for
  unconfirmed messages, and per-agent identity (055 finding, framework:pickup 257)

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-01T08:49:35Z
last_update: 2026-10-02T22:14:59Z
date_finished: 2026-10-02T22:14:59Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-10-01T08:51:31Z'
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
  - ts: '2026-10-01T09:00:23Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=143,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-02T22:15:20Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=152,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3631: Cross-agent delivery: one acknowledged channel, a delivery ledger for unconfirmed messages, and per-agent identity (055 finding, framework:pickup 257)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Which ONE channel does a peer use to reach AEF, and who consumes it?** Option one: give framework:pickup a consumer that reads, acts and posts a receipt per offset. Option two: retire it in favour of the sidecar DM to the framework agent. Either way, document the one channel. Today it has 258 posts and one stale receipt (up to 81).
  confidence: 2
  disposition: answered
  rationale: the one channel is the sidecar (D-645 design; receive half delivered in T-3693, HTTP receiver + ready-flag injection, live two-agent e2e 3/3; the 30 s watcher in T-3684/T-3685 also reads the hub inbox topic); framework:pickup gets retired, not given a second consumer (build slice after GO)

- **IW-2: Where do unconfirmed outbound messages surface, and after how long?** A delivery ledger that handover and audit read: an "unconfirmed after N hours" WARN, so that "posted" is never reported as "told". Which N, and does the ledger cover pickups, channel posts and sidecar DMs alike?
  confidence: 2
  disposition: deferred
  rationale: the ledger exists since T-3693 (sender states SENT→RECEIVED→HANDED_OVER→REPLIED, ESCALATED set by infrastructure on deadline); the surfacing (fw sidecar latency, doctor/audit WARN on unconfirmed) is built in T-3684; N is set there from measured latency (median reply today 49 min, max 278 min)

- **IW-3: How do co-resident agents get distinct identities?** All agents on .107 sign as one TermLink identity (T-1448), so replies wake the TermLink agent. The options are per-agent identity in TermLink (Gap Homing: TermLink's fix) or a framework-level reply-to agent id honoured by sidecars. Which side fixes it, and what does the framework do meanwhile?
  confidence: 2
  disposition: deferred
  rationale: per-agent signing identity is TermLink's fix (Gap Homing; D5/D6 routed to 010-termlink 2026-10-01, status asked 2026-10-02); meanwhile the framework distinguishes agents by circuit id (D-660) and per-agent sidecar receivers with bearer tokens (T-3693, T-3725)

- **IW-4: How is the unread backlog (framework:pickup 82-254, ~70 posts addressed to AEF) triaged without a flood of tasks?** One pass reads each post, answers or files it (one bug, one task), and posts a receipt only for what was actually read.
  confidence: 2
  disposition: answered
  rationale: done for the sidecar inbox by T-3678 (54/54 consults classified from decoded bodies, 13 verified defects filed one per task T-3695..T-3707, replies sent); the framework:pickup 82-254 backlog gets the same one-pass treatment as a build slice after GO

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

055 measured (verified here): framework:pickup has 258 posts and ONE consumer receipt (up to offset 81); ~70 posts addressed to AEF since offset 186 have no reader evidence; every post says 'delivered-unconfirmed' and nothing turns that into a follow-up; co-resident agents share one TermLink identity so replies wake the wrong agent. Reliability directive: no silent failures. The evidence is complete; what remains is choosing the channel (ack consumer on framework:pickup vs retire it for sidecar DM), where unconfirmed messages surface (handover/audit after N hours), and identity (framework reply-to vs TermLink per-agent identity, Gap Homing).

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

**Rationale**: 055 measured (verified here): framework:pickup has 258 posts and ONE consumer receipt (up to offset 81); ~70 posts addressed to AEF since offset 186 have no reader evidence; every post says 'delivered-unconfirmed' and nothing turns that into a follow-up; co-resident agents share one TermLink identity so replies wake the wrong agent. Reliability directive: no silent failures. The evidence is complete; what remains is choosing the channel (ack consumer on framework:pickup vs retire it for sidecar DM), where unconfirmed messages surface (handover/audit after N hours), and identity (framework reply-to vs TermLink per-agent identity, Gap Homing).

**Date**: 2026-10-02T22:14:59Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-01T08:51:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-02T22:14:59Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 055 measured (verified here): framework:pickup has 258 posts and ONE consumer receipt (up to offset 81); ~70 posts addressed to AEF since offset 186 have no reader evidence; every post says 'delivered-unconfirmed' and nothing turns that into a follow-up; co-resident agents share one TermLink identity so replies wake the wrong agent. Reliability directive: no silent failures. The evidence is complete; what remains is choosing the channel (ack consumer on framework:pickup vs retire it for sidecar DM), where unconfirmed messages surface (handover/audit after N hours), and identity (framework reply-to vs TermLink per-agent identity, Gap Homing).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3be9dd18
- **Timestamp:** 2026-10-02T22:15:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-32fb3f71
- **Timestamp:** 2026-10-02T22:15:26Z
- **Overall:** UNVERIFIED
- **Claims:** 0
- No verifiable claims found in ## Recommendation

### 2026-10-02T22:14:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
