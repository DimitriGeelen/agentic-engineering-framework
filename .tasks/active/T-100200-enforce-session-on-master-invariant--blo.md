---
id: T-100200
name: "Enforce session-on-master invariant — blocking gate vs advisory"
description: >
  Inception: Enforce session-on-master invariant — blocking gate vs advisory

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-05T20:43:21Z
last_update: 2026-07-05T20:44:33Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
---

# T-100200: Enforce session-on-master invariant — blocking gate vs advisory

## Problem Statement

T-100196 shipped **session-on-master (option c)** as a *practice* — the persistent session tracks
`origin/master` directly instead of a long-lived session branch — plus detection (`diverged-fork`
WARN) and `fw worktree gc`. The operator challenged the claim that this "fixes" branch/worktree
drift: *"how can you be sure its fixed?"* It is NOT enforced — nothing structurally blocks the
antipattern from recurring. This inception explores whether to harden the invariant into a
**blocking gate**, and if so, which mechanism closes the drift **without breaking the deliberate
worktree-branch parallelism flow** (the operator's explicit constraint: branches are created on
purpose). Now: because the mitigation just shipped and its completeness is unproven.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->
- A1: persistent-session branch is the complete/dominant root of drift → **PARTIAL** (dominant, not complete; Spike 1).
- A2: "main checkout on master" is a safe discriminator → **CONFIRMED w/ constraints** (Spike 2).
- A3: a blocking gate's lockout risk is acceptable → **CONTEXT-DEPENDENT** (Spike 3 — not worth paying yet).

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

- **IW-1: Is the persistent-session branch the COMPLETE root of working-state drift, or are there other vectors (interrupted integrate, consumer vendored drift, background/cron writers, stale-ref go-live reset) that session-on-master does not close?**
  confidence: 3
  disposition: answered
  rationale: Spike 1 DONE — 7-vector table in docs/reports/T-100200-session-on-master-enforcement.md. Dominant NOT complete: session-on-master closes #1 (persistent-session branch) + #3 (cron amplifier, conditional); residual #2 (enforcement target, WARN-detected), #4/#6 (gc-mitigated), #5 (new independent — stale-ref go-live reset).

- **IW-2: Is there a mechanical discriminator that blocks persistent-session-branch drift WITHOUT breaking the worktree parallelism flow (worktree branches are also non-master and commit legitimately)?**
  confidence: 3
  disposition: answered
  rationale: Spike 2 DONE — discriminator "main checkout on master; worktrees free" holds ONLY when scoped to framework repo + exempting detached-HEAD/CI + firing on commit not startup. Commit-target gate (mech B) satisfies all; session-start refusal (mech A) fights every edge.

- **IW-3: Which enforcement mechanism (A session-start refusal / B commit-target gate / C WARN→FAIL escalation / D none) has the right risk-benefit — specifically, is a blocking gate's lockout risk acceptable with a clean bypass?**
  confidence: 3
  disposition: answered
  rationale: Spike 3 DONE — recommend mech C (escalate diverged-fork WARN→FAIL after N days): zero lockout risk, closes the ignorable-WARN gap for the narrow deliberate-action vector #2. Hold B (commit-gate) as conditional follow-up; reject A (dominated by B) + D (undersells — WARN ignorable forever). File #5 separately.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** enumerate all working-state drift vectors; decide whether/how to enforce the
session-on-master invariant for the *framework repo*. **OUT:** consumer-repo branch policy
(consumers run their own branches — gap-homing); the actual build of the chosen mechanism (a GO
spawns separate build tasks); vector #5 (stale-ref go-live reset) — surfaced here but filed as its
own independent task.

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

**Recommendation:** GO — scoped to mechanism **C** (escalate the `diverged-fork` WARN → FAIL after
N days), NOT a blocking commit-gate; and file drift-vector **#5** (stale-ref go-live reset) as its
own separate task. Hold mech **B** (commit-target gate) as a conditional follow-up.

**Rationale:**

Spikes 1–3 are complete (docs/reports/T-100200-session-on-master-enforcement.md). Spike 1 proved
the **dominant** drift vector (#1, persistent-session branch) is **already closed by the shipped
practice** — a heavy blocking gate defends an already-shut door. The residual enforcement target
**narrows to vector #2** (a *deliberate* `git checkout -b` in the main checkout), which the
`diverged-fork` WARN **already detects**; the only gap is that a WARN is ignorable forever — exactly
what mech C closes, at zero lockout risk and near-zero build cost. Mech B is the only true
*prevention* but Spike 2 shows real consumer/CI/detached-HEAD collateral and Spike 3 shows its
marginal value over C is low for a non-accidental vector → hold it. Vector #5 is independent of the
A/B/C/D axis and newly surfaced → own task. GO not DEFER: the spikes closed the *evidence* gap
(feedback_defer_for_evidence_not_confidence).

**Evidence:**
- Drift-vector table (7 vectors, Y/N verdicts): `docs/reports/T-100200-session-on-master-enforcement.md` §Spike 1.
- Discriminator edge-case matrix + IW-2 verdict: same doc §Spike 2.
- Mechanism A/B/C/D verdict table: same doc §Spike 3.
- Vector #5 hit **live this session** (operator's `git reset --hard origin/master` landed on stale tip 79b9dc8f0); recovered via `git fetch && git checkout -f -B master origin/master`.
- Dominant vector #1 already closed: session-on-master keystone shipped in 42f9c3552 (T-100196), `fw worktree gc` in 2dd655171.

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

### 2026-07-05T20:44:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
