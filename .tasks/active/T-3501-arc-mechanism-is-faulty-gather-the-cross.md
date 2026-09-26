---
id: T-3501
name: "ARC mechanism is faulty: gather the cross-agent proposals and decide what to
  repair"
description: >
  Inception: ARC mechanism is faulty: gather the cross-agent proposals and decide
  what to repair

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-09-26T09:13:48Z
last_update: '2026-09-26T09:15:10Z'
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
  - ts: '2026-09-26T09:15:05Z'
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
  - ts: '2026-09-26T09:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=123,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3501: ARC mechanism is faulty: gather the cross-agent proposals and decide what to repair

## Problem Statement

The operator reports the **arc mechanism is faulty** and that *"a number of
proposals from different agents"* on improving it are sitting in messages.
Verbatim, 2026-09-26: *"Please check messages, there's a number of proposals from
different agents on improving our ARC mechanism. Because it's faulty. So let's
work on that."*

Two things are being explored, and they must not be collapsed:

1. **Where the proposals are, and what each proposes.** Not yet located. Surfaces
   checked so far are logged in `docs/reports/T-3501-arc-mechanism-faults.md`.
2. **What "faulty" means to the operator.** I carry a list of arc faults from
   prior runs (membership recorded three incompatible ways, tasks arriving
   untagged, no `--arc` verb, arc-020's capability-with-no-callers). That list is
   *mine*, not necessarily theirs, and scoping to my list instead of the
   proposals' would be the exact failure this inception exists to avoid.

Why now: the operator asked. Also independently overdue — the 2026-09-26
procAsFit run hand-tagged five tasks that dispatched workers had filed with
`tags: []`, and the audit reports five arcs stale with membership counts that
disagree with themselves.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

- **A1:** The proposals exist in a machine-readable surface in this repo or on the
  TermLink hub, rather than only in the operator's recollection of a conversation.
  *Test:* enumerate every message surface and log each as found/empty/unexamined.
- **A2:** "ARC" means AEF's arc mechanism (`.context/arcs/*.yaml`, `lib/arc.sh`,
  G-062/T-1671), not TermLink's *chat arc*. The two collide lexically and the
  `agent-chat-arc` topic is chat-arc heartbeats, so this needs stating rather than
  assuming.
  *Test:* confirm against the content of whatever proposals are found.
- **A3:** The faults the proposals name overlap only partly with the faults I
  already have on record. *Test:* diff the two lists once the proposals are read.

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

- **IW-1: Where are the cross-agent proposals, and what does each one actually
  propose?**
  confidence: 0
  disposition:
  rationale:

- **IW-2: Does "faulty" mean the faults already on record, the faults the
  proposals name, or a third thing the operator has in mind?**
  confidence: 1
  disposition:
  rationale: Five arc faults are on record from prior runs (membership recorded
    three incompatible ways; tasks filed untagged; no `--arc` verb; zero-population
    arcs exempt from staleness for the wrong reason; arc-020 capability with no
    callers). Confidence 1 because these are measured but were not reported by any
    peer and may not be what prompted this.

- **IW-3: Is the fault in the arc MECHANISM or in arc ADOPTION?**
  confidence: 1
  disposition:
  rationale: The distinction decides what gets built. arc-020's evidence points at
    adoption — G-062 correctly refused closure because the headline mechanic never
    fired, so the gate worked and the wiring did not (OBS-537). But membership
    being recordable three incompatible ways is a genuine mechanism defect. A
    repair aimed at the wrong one of these would change gates that are currently
    doing their job.

- **IW-4: Is arc membership a single source of truth, and if not, which one wins?**
  confidence: 2
  disposition:
  rationale: Three concurrent representations exist — `arc_id:` (accepting both
    slug and `arc-NNN`), the legacy `tags: [arc:<slug>]`, and the arc YAML's own
    `constituent_tasks:`. Measured: arc-017's constituent count disagrees three
    ways and its `arc_id:` matches zero tasks. Confidence 2 because the divergence
    is measured; what is open is which representation should become canonical and
    what a migration costs.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

1. **Locate the proposals (IW-1).** Enumerate every message surface and record
   each as found / empty / unexamined, so an unchecked surface cannot read as an
   empty one (T-3099). Surfaces: TermLink topics + DMs, `.context/pickup/`,
   `bus/`, `handoffs/`, `sidecar/`, `message-archive/`, `inbox.yaml`,
   `peer-consult-prompts.yaml`. **Read-only.**
2. **Read and tabulate each proposal** — who sent it, what fault it claims, what
   it proposes, and whether the claim is verifiable here.
3. **Diff proposal-claimed faults against the on-record faults (A3, IW-2).**
4. **Classify each fault as mechanism vs adoption (IW-3)** with the evidence for
   the classification, because the two take different repairs.
5. **Surface to the operator** for the GO/NO-GO on which faults are in scope.
   Build slices are filed only after that.

**Time-box:** steps 1-4 this session. Step 5 hands back.

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

**Recommendation:** DEFER

**Rationale:**

Filed before reading the proposals, which is a real evidence gap and not a hedge: the operator reports 'a number of proposals from different agents' on the arc mechanism and I have not yet located or read them. Recommendation will be replaced with GO or NO-GO once the proposals are gathered and the fault is characterised. Scope is deliberately an inception rather than a build because the arc mechanism spans lib/arc.sh, the arc YAML schema, Watchtower /arcs, and the G-062/T-1671 closure gates — and per CLAUDE.md G-020 a detailed proposal from another session is a proposal, not authorisation to build.

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

### 2026-09-26T09:15:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
