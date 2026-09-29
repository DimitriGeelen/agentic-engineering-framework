---
id: T-3532
name: "Workflow-management task class (WM-NNN): give governance-necessary work a home
  so the task gate never has to be weakened"
description: >
  Inception: Workflow-management task class (WM-NNN): give governance-necessary work
  a home so the task gate never has to be weakened

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [agents/context/check-active-task.sh, agents/context/lib/focus.sh, agents/task-create/update-task.sh, lib/inception-readiness.sh, lib/inception.sh, lib/review.sh, lib/wm_tasks.sh, web/blueprints/inception.py]
related_tasks: [T-3536, T-3537]
# T-1984 GO-scope traceability. Operator ruling 2026-09-28: "We're fine with doing B
# first, but A is really important, so we must be absolutely sure that gets done next."
# Recorded here rather than promised, because a promise does not survive a context reset
# and today's audit reports 19 GO'd inceptions with no build follower. The close gate
# validates every ships_in: referent is reachable, and the audit rail surfaces a GO'd
# inception whose followers never shipped — so A going missing becomes a WARN, not a
# silence.
inception_decisions:
  - id: tier-3-read-categories
    text: "Implement Tier 3 pre-approved read categories so status queries and discovery do not require an active task — the read half, separable and carrying no standing exemption."
    ships_in: deferred:T-3536
  - id: wm-task-class
    text: "The WM- namespace (WM-001 selection, WM-002 close-out, WM-003 session lifecycle) with per-id scope fences enforced in the gate. Sequenced AFTER Tier 3, NOT dropped: operator ruled it is the important half."
    ships_in: deferred:T-3537
created: 2026-09-28T12:37:47Z
last_update: 2026-09-28T18:23:49Z
date_finished: 2026-09-28T18:23:49Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-09-28T12:39:28Z'
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
  - ts: '2026-09-28T12:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=148,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3532: Workflow-management task class (WM-NNN): give governance-necessary work a home so the task gate never has to be weakened

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Are WM tasks stored in a separate `.tasks/workflow/` directory, or in `active/` with a class marker?**
  confidence: 2
  disposition: answered
  rationale: Directory. `.tasks/workflow/` — shipped T-3537. Chosen because episodic gen, staleness audits, review-queue counts and find_task_file all glob active/+completed/ and assume closure; a directory is skipped BY CONSTRUCTION, a marker needs a special case in each and the missed one is a silent bug.

- **IW-2: Does the gate ENFORCE per-WM scope fences, or are they advisory with an audit rail behind them?**
  confidence: 1
  disposition: answered
  rationale: Enforced, not advisory. Shipped T-3537: under WM focus a Write/Edit to any source path exits 2. Verified live — a real source write was refused with focus WM-001. An advisory fence is no fence when the risk IS the standing exemption.

- **IW-3: Does WM-002 (close-out) carry the just-closed task's id to bound its scope, and if so who sets it — `update-task.sh` at close?**
  confidence: 2
  disposition: answered
  rationale: Capability-scoped, not task-id-scoped. WM-002 is bounded by 'no source writes', not by the id of the task that just closed. Binding the id would couple the fence to the close transition, which OBS-468 already shows is the fragile part. Revisit if the log shows misuse.

- **IW-4: Is Tier 3 (pre-approved read categories, "Spec only" since the tiers were written) implemented in this arc or split out as its own?**
  confidence: 2
  disposition: answered
  rationale: Split out and shipped separately as T-3536. Measurement dissolved most of it: T-3096 had already built the fw read allowlist, and the claimed '4 of 7 blocks were reads' was false. Real residue was 3 read-only verbs shipped after that derivation; added with negative controls.

- **IW-5: How does this interact with OBS-468 / T-3432, where session-scoped focus means close FAILS to clear focus and the session hard-deadlocks?**
  confidence: 1
  disposition: answered
  rationale: No collision. OBS-468/T-3432 is close FAILING to clear focus under session-scoped focus (stale value); WM adds a NEW valid focus value. Different states, different fixes. T-3537's 148-test regression run included the focus suites and stayed green.

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

Twelve instances of the closed-task/focus-null dead end, three today, one of which blocked an autonomous mandate at step zero and one of which forced a worker to file T-3530 purely to commit finished work. The gate's purpose is governance coverage, not bookkeeping; selection and close-out ARE work, so they need tasks rather than an exemption. Tier 3 (pre-approved read categories) has been 'Spec only' in CLAUDE.md since the tiers were written, which is the read half of the same gap. GO rather than DEFER because the evidence is complete and the alternative designs are already enumerated with their trade-offs; what remains is a scope-fence design decision, not a knowledge gap.

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

**Rationale**: Twelve instances of the closed-task/focus-null dead end, three today, one of which blocked an autonomous mandate at step zero and one of which forced a worker to file T-3530 purely to commit finished work. The gate's purpose is governance coverage, not bookkeeping; selection and close-out ARE work, so they need tasks rather than an exemption. Tier 3 (pre-approved read categories) has been 'Spec only' in CLAUDE.md since the tiers were written, which is the read half of the same gap. GO rather than DEFER because the evidence is complete and the alternative designs are already enumerated with their trade-offs; what remains is a scope-fence design decision, not a knowledge gap.

**Date**: 2026-09-28T18:23:49Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-28T12:39:28Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-28T18:23:49Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Twelve instances of the closed-task/focus-null dead end, three today, one of which blocked an autonomous mandate at step zero and one of which forced a worker to file T-3530 purely to commit finished work. The gate's purpose is governance coverage, not bookkeeping; selection and close-out ARE work, so they need tasks rather than an exemption. Tier 3 (pre-approved read categories) has been 'Spec only' in CLAUDE.md since the tiers were written, which is the read half of the same gap. GO rather than DEFER because the evidence is complete and the alternative designs are already enumerated with their trade-offs; what remains is a scope-fence design decision, not a knowledge gap.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f6ef984d
- **Timestamp:** 2026-09-28T18:23:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-8f6830f8
- **Timestamp:** 2026-09-28T18:23:50Z
- **Overall:** CONFIRMED
- **Claims:** 1

| Claim | Type | Status |
|-------|------|--------|
| `T-3530` | task | ✓ pass |

### 2026-09-28T18:23:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
