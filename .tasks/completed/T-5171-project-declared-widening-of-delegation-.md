---
id: T-5171
name: "Project-declared WIDENING of delegation: let a project's recorded operator
  ruling make one criterion class (act-in-the-world) agent-closeable on measured evidence
  + reviewer green (010 T-3800)"
description: >
  010-termlink msg 1a3cdc2d (2026-11-15): their operator ruled (010 T-3800 Decisions,
  extending D-626) that the agent may close a task whose remaining act-in-the-world
  criterion it MEASURED as done (command + output recorded) AND an independent reviewer
  passed. lib/delegation.py keeps act-in-the-world operator-only always, with no bypass
  flag, so 3 of their 7 qualifying tasks (T-1632, T-2258, T-3685) went to partial-complete
  and the operator must tick evidence two reviewers already checked. T-3968 (closed)
  covered the opposite direction, a project NARROWING delegation. Question: should
  AEF let a project declare, in a committed policy file, a ruling that widens one
  class under stated conditions, with the ruling id cited on every tick?

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [delegation, governance, reviewer]
components: []
related_tasks: [T-3968, T-3557, T-3445]
origin: {kind: "peer", source: "010-termlink", ref: "1a3cdc2d"}
created: 2026-11-15T23:55:07Z
last_update: 2026-11-16T08:38:23Z
date_finished: 2026-11-16T08:38:23Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-11-16T00:00:42Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-16T00:01:16Z'
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

# T-5171: Project-declared WIDENING of delegation: let a project's recorded operator ruling make one criterion class (act-in-the-world) agent-closeable on measured evidence + reviewer green (010 T-3800)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->
010-termlink's operator ruled that their agent may close a task whose remaining act-in-the-world step it measured as done, once an independent review passes. AEF's `lib/delegation.py` keeps act-in-the-world operator-only in every project, with no bypass flag. So the agent cannot carry out the ruling, and the operator ends up ticking evidence two reviewers already checked: the rubber-stamping D-626 exists to prevent. T-3968 (closed) let a project NARROW delegation; nothing lets a project WIDEN it. Who: any consumer whose operator makes such a ruling (010 first, 7 tasks through it so far). Why now: three 010 tasks (T-1632, T-2258, T-3685) are waiting on rubber-stamp ticks.

**The ruling, verbatim** (010-termlink msg 1a622646, from their T-3800 ## Decisions, 2026-11-15). Their operator, two messages in sequence:
1. "Yes, you may close the task yourself." (answering option A: "when I can check the action directly (a file on disk, an installed unit, a commit, a peer's reply on record), I close the task myself and record the command and its output in the task. Anything I can't measure stays with you.")
2. "of course assuming you got a positive review from the reviewers as we have defined it in our review protocol."

Recorded by 010 as: the agent may close such a task provided (1) the command and its output are recorded in the task, and (2) an independent reviewer seat, run per their protocol (isolated run, tools off, neutral bundle with the task and the measured evidence, no recommendation), returns a positive verdict; a negative or unclear verdict sends it back to the operator. Scope: extends D-626 for that project; decisions, sovereignty fields, tier-0 approvals and anything not measurable stay with the operator. In practice they run two seats (opencode + claude-code) and require BOTH to pass; a split goes back to evidence-gathering, then to the operator.

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

**Rationale:** The ruling is the project operator's own sovereign decision, recorded with an id; the framework currently forces a workaround (rubber-stamp ticks), which is the outcome D-626 exists to prevent. GO to scope it with hard conditions: the policy entry is operator-authored (written through an --i-am-human/Watchtower path, never by an agent), names one class and the exact conditions (measured command + recorded output, plus an independent reviewer green at the task's rung), every tick cites the ruling id, fw audit WARNs on each such tick, and the three carve-outs stay operator-only by default in every project that declares nothing. Tier-0 and sovereignty classes stay out of scope.

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

**Rationale**: The ruling is the project operator's own sovereign decision, recorded with an id; the framework currently forces a workaround (rubber-stamp ticks), which is the outcome D-626 exists to prevent. GO to scope it with hard conditions: the policy entry is operator-authored (written through an --i-am-human/Watchtower path, never by an agent), names one class and the exact conditions (measured command + recorded output, plus an independent reviewer green at the task's rung), every tick cites the ruling id, fw audit WARNs on each such tick, and the three carve-outs stay operator-only by default in every project that declares nothing. Tier-0 and sovereignty classes stay out of scope.

**Date**: 2026-11-16T08:38:20Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-16T08:38:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The ruling is the project operator's own sovereign decision, recorded with an id; the framework currently forces a workaround (rubber-stamp ticks), which is the outcome D-626 exists to prevent. GO to scope it with hard conditions: the policy entry is operator-authored (written through an --i-am-human/Watchtower path, never by an agent), names one class and the exact conditions (measured command + recorded output, plus an independent reviewer green at the task's rung), every tick cites the ruling id, fw audit WARNs on each such tick, and the three carve-outs stay operator-only by default in every project that declares nothing. Tier-0 and sovereignty classes stay out of scope.

### 2026-11-16T08:38:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** Inception decision in progress

### 2026-11-16T08:38:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a056de1a
- **Timestamp:** 2026-11-16T08:38:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Scope:** static anti-pattern scan; PASS means no anti-pattern was found, not that the criteria hold
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-3651a839
- **Timestamp:** 2026-11-16T08:38:25Z
- **Overall:** UNVERIFIED
- **Claims:** 0
- No verifiable claims found in ## Recommendation
