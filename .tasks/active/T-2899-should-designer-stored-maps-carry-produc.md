---
id: T-2899
name: "Should designer-stored maps carry producer provenance, or is the corpus-spec
  exporter stamp correctly export-only"
description: >
  Inception: Should designer-stored maps carry producer provenance, or is the corpus-spec
  exporter stamp correctly export-only

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-09T15:04:54Z
last_update: 2026-08-09T15:06:23Z
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
  - ts: '2026-08-09T15:06:24Z'
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

# T-2899: Should designer-stored maps carry producer provenance, or is the corpus-spec exporter stamp correctly export-only

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

`tools/corpus_spec.py:407` emits `exporter="aef-corpus-spec"` on `generate()`
output. Measured 2026-08-09:

    exporter="aef-corpus-spec" on the live designer corpus ..  0 of 37 .bpmn
    exporter="aef-corpus-spec" on any .bpmn on disk .........  0

`web/blueprints/designer_api.py:139` writes the posted payload verbatim, so this
is not a save-path strip. Nothing has ever round-tripped a stored map through
`generate --save`. The stamp is real in the emitter and absent from every
artifact that leaves this project.

**Why now:** it was reported to 832 at rail 494 as shipped, and they built a
T-406 gate prediction on it at rail 502 §3 — "incidental → preserved, because
`aef-task-lifecycle/v1.bpmn` should carry your 494 stamp." It does not. Their
run will land on whatever their gate does with *unstamped* input, and a
"preserved" result would be their default branch being permissive rather than
the stamp working: right answer, wrong mechanism, which retires the question.
Corrected to them at rail 506 §2 before they spend the run.

**The generalisation this is really about:** a producer's report that a stamp
shipped is a claim about the **emitter**; the consumer needs a claim about the
**artifact**. Those are different measurements and only one of them is at the
seam. This is L-560 (a scope note reads as coverage downstream) with me as the
producer, written after I named the class.

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

- **IW-1: Should stored designer maps carry the producer stamp at all?**
  confidence: 2
  disposition:
  rationale: Current answer NO, on the rail-501 asymmetry. 832's identity gate
    reads "names a different producer → preserve". A *laundered* AEF document
    carries `aef-corpus-spec` — it is our text that was mis-adopted — so
    stamping stored maps would move them from their default branch onto the
    STAMPED-other branch and have their gate confidently preserve exactly the
    corruption it exists to suppress. Stamping makes a peer's gate wrong with
    conviction rather than wrong by default. Confidence 2 not 3: this reasons
    about their gate from their description at 502, not from their source.

- **IW-2: Is the emitter stamp dead code, or correctly scoped to exports?**
  confidence: 1
  disposition:
  rationale: Unresolved and the actual residual. `generate --save` POSTs through
    `/api/save`, which persists verbatim — so the stamp is *reachable* into the
    store and has simply never been used that way. Either (a) exports are a real
    consumer we have not enumerated and the scoping is right, or (b) nothing
    consumes the stamp anywhere and it is decoration. Needs one spike: enumerate
    every consumer of `generate()` output.

- **IW-3: Does anything else in this project report a mechanism as shipped
  without measuring it at the seam?**
  confidence: 0
  disposition:
  rationale: Open. The class is L-560 with the producer inside it. T-2897's
    `[PASS] Secret scan` line was the peer's instance; rail 494 is mine. Two
    instances is the threshold in §Bug-Fix Learning Checkpoint for asking
    whether this is systemic, but no sweep has been run.

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

**Recommendation:** NO-GO

**Rationale:**

Measured: tools/corpus_spec.py:407 emits exporter=aef-corpus-spec on generate() output, but 0 of 37 stored designer maps and 0 .bpmn files on disk anywhere carry it. designer_api.py:139 writes payloads verbatim, so this is not a save-path strip — nothing has ever round-tripped a stored map through 'generate --save'. NO-GO on propagating the stamp into the store to feed 832's T-406 identity gate: per rail 501, producer identity is the wrong axis at this seam, because a laundered AEF document carries OUR stamp, so their gate would preserve exactly the corruption it exists to suppress. Stamping would upgrade a default-branch outcome into a confidently-wrong one. The residual question is narrower and worth one spike: is the emitter stamp dead code, or correctly scoped to exports? Reported to 832 at rail 506 sections 2-3.

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

### 2026-08-09T15:06:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
