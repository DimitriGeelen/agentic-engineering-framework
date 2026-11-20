---
id: T-5300
name: "Shared worker contract: should wc add a 'withdrawn' outcome (dispatched -> done, never-started jobs only) so a submitter can withdraw a queued pool job? (ring20 T-2790)"
description: >
  Inception: Shared worker contract: should wc add a 'withdrawn' outcome (dispatched -> done, never-started jobs only) so a submitter can withdraw a queued pool job? (ring20 T-2790)

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
waiting_on: agent
revisit_at: 2026-11-27
created: 2026-11-20T12:45:49Z
last_update: 2026-11-20T12:45:49Z
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

# T-5300: Shared worker contract: should wc add a 'withdrawn' outcome (dispatched -> done, never-started jobs only) so a submitter can withdraw a queued pool job? (ring20 T-2790)

## Problem Statement

A job submitted to the shared worker pool cannot be taken back before it starts. In lib/dispatch_records.py (contract wc/0.3.3) an attempt in `dispatched` ends only through start+complete by the worker, or, past `deadline_dispatched`, moves to `unknown` and raises an operator-resolve notice. ring20 (T-2790, msg 3d5e1fda, operator-requested, relayed via 1409): 9 judge jobs of 1409 were held 5 h on two nodes on 2026-11-20 with no way to withdraw them. Proposed: `dispatched -> done` with a new outcome `withdrawn` (e.g. `Store.withdraw(dispatch_id, attempt, *, reason, actor, writer='hub')`), allowed only from `dispatched` (never started), refused otherwise (cas_mismatch), logged with actor and reason, no notice; ring20's poold would call it on a `ring20.pool.withdraw/1` request and every view treats it as a normal terminal state. The contract (docs/specs/shared-worker-contract-transitions.md) is owned jointly by AEF, TermLink and ring20 (docs/reports/T-4752/spec-proposal.md), so this is a spec change. Wanted "this week", not urgent.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Does TermLink (co-owner of wc) agree to a `withdrawn` outcome and the `dispatched -> done` transition, and as which spec revision (v0.3.4)?**
- **IW-2: Who may withdraw (submitter only? hub? operator?), and how is the submitter proven, given the worker's nonce/credential model?**
- **IW-3: What happens if withdraw races a worker's start (the attempt moves to `running` between check and write) — is the existing compare-and-set enough?**

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

**Recommendation:** EXPLORING

**Rationale:**

ring20 (T-2790, msg 3d5e1fda, 2026-11-20, operator-requested via 1409): today a dispatched attempt can only end by start+complete, or move to unknown past deadline_dispatched and raise an operator-resolve notice; 9 judge jobs of 1409 sat 5 h on two nodes. lib/dispatch_records.py implements the shared contract wc/0.3.3 (docs/specs/shared-worker-contract-transitions.md), owned jointly by AEF, TermLink and ring20, so a new transition and outcome is a spec change those owners agree, not an AEF-only edit.

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
