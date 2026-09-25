---
id: T-3461
name: "Sidecar architecture review — is there a coherent design description, and is
  the mechanism actually working in practice"
description: >
  Inception: Sidecar architecture review — is there a coherent design description,
  and is the mechanism actually working in practice

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-09-25T09:11:46Z
last_update: '2026-09-25T09:15:11Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-09-25T09:12:12Z'
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
  - ts: '2026-09-25T09:15:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=157,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3461: Sidecar architecture review — is there a coherent design description, and is the mechanism actually working in practice

## Problem Statement

Sidecar is now carrying real cross-project traffic (45 consults, three peers), and the
operator asked two questions: is the design written down anywhere coherent, and is the
mechanism actually working. Full evidence and reasoning:
**`docs/reports/T-3461-sidecar-architecture-review.md`**.

Short answers: **no**, and **partly — with one defect that undoes the rest**. The retry
ladder escalates an unanswered message to the operator via `fw note`, which writes
`.context/inbox.yaml` — a file with 319 pending entries, no Watchtower renderer, and
push notifications disabled. The last rung of an escalation ladder built to recover from
"nobody read it" terminates in a queue nobody reads.

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

- **IW-1: Does a single coherent architectural description of Sidecar exist, or is the
  design only recoverable by reading code and a scatter of task files?**
  confidence: 3
  disposition: answered
  rationale: No. docs/architecture/ holds 2 files, neither about sidecar; the design lives in 3 per-slice reports (T-3396, T-3433, T-3434) plus lib/sidecar/*.py.

- **IW-2: Is the mechanism actually delivering? The audit line reports 45 consults, 45
  delivered, 0 in flight, 0 dead-lettered — but a ledger that only counts what it
  recorded cannot see a message that was never enqueued. What is the denominator?**
  confidence: 3
  disposition: answered
  rationale: Both true — 45/45 injected, but 15/45 needed escalation to rung 4-5 over 10-12 attempts. The dashboard shows only the flattering number.

- **IW-3: `fw sidecar whoami` reports `identity fp: - (termlink unreachable)`. Is the DM
  rail (T-3405) currently down, and if so for how long and with what consequence?**
  confidence: 1
  disposition: deferred
  rationale: Hub is up (PID 3071124) and messages flow, so the message is misleading — a specific identity lookup fails. Needs its own diagnosis; not resolvable inside this review.

- **IW-4: The 5-level circuit addressing (host/hub/project/session/agent) replaced
  `sidecar:<agent>` topics with `inbox:<circuit-id>` (T-3433). Did the legacy address
  actually get retired, or are both live — and can a message sent to one be invisible at
  the other?**
  confidence: 3
  disposition: answered
  rationale: Both live with independent offsets — sidecar:…@21 and inbox:…@6. Reader covers both, so the transition is safe; no retirement date stated.

- **IW-5: What is the retry ladder (T-3434) doing in practice? 2×1m, 2×5m, 2×15m, 2×1h,
  2×4h, 2×1d, 2×1w, 2×1mo is a month-long tail — has anything ever ridden it to the end,
  and is a message still in flight after a week distinguishable from one that is lost?**
  confidence: 3
  disposition: answered
  rationale: Ladder works — 14 messages reached rung 5. Its terminus does not: fw note -> .context/inbox.yaml, 319 pending, no Watchtower renderer, notify disabled.

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
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** GO — two bounded pieces, in order

**Rationale:**

The mechanism is sound and its terminus is a no-op. 15 of 45 messages climbed to rung 4-5
over 10-12 attempts and 14 ended `escalated:operator — operator-notice-sent`; that notice
goes to `fw note` -> `.context/inbox.yaml`, which holds 319 pending entries, is read by no
Watchtower blueprint or template (`grep -rln 'inbox.yaml' web/` returns nothing), and is
not pushed (`fw notify status`: `Enabled: false`). So the escalation path exists, runs,
records itself faithfully, and delivers to nobody.

**First: fix the terminus.** Cheapest first — enable `fw notify` (server already
configured), render `.context/inbox.yaml` in Watchtower, or route sidecar escalations to a
surface that already has a reader (`/approvals`). Any one makes the existing ladder real.

**Second: write the missing architecture document.** One page — components, message
lifecycle from `send` to `ack`, addressing ladder, retry schedule, failure modes and their
detectors. The three slice reports become references rather than substitutes; this review
is most of the raw material.

**Not recommended:** further Sidecar feature work before the terminus is fixed. Adding
capability to a system whose escalation path is a no-op only increases the volume of
unread escalations.

**Evidence:**

- No architecture doc: `docs/architecture/` = 2 files, both parallel-execution, last
  touched 2026-06-11. Design spread across T-3396 (350 lines), T-3433 (183), T-3434 (204).
- Ledger collapsed to per-message state: rung 1 ×22, rung 4 ×1, **rung 5 ×14**, none ×8.
  Escalated peers: 832 ×4, 010-termlink ×4, own worker topics ×3, e2e responders ×4.
- Terminus: `lib/sidecar/retry.py:163` -> `fw note --tag sidecar`; `.context/inbox.yaml`
  524 entries / **319 pending** / 27 sidecar-tagged; no `web/` file references it;
  `fw notify status` = disabled.
- Dual addressing live: `sidecar:…@21` and `inbox:…@6`, independent offsets.
- `whoami` says "termlink unreachable" while `termlink hub status` says running — a
  specific identity-fp failure wearing a general connectivity message.
- Third instance of one class in a week: OBS-482 (832's rail had no consumer), 832's @20
  (their inbox had a consumer that never looked), and this.

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-25T09:12:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
