---
id: T-2522
name: "BPMN to AEF task-inception-YAML mapping contract (T-175 Child 1 AEF half)"
description: >
  Inception: BPMN to AEF task-inception-YAML mapping contract (T-175 Child 1 AEF half)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-10T15:50:16Z
last_update: 2026-07-10T16:53:10Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-07-10T16:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-10T16:00:09Z'
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

# T-2522: BPMN to AEF task-inception-YAML mapping contract (T-175 Child 1 AEF half)

## Problem Statement

T-175 (workflow-design integration) decomposes into 5 children. **Child 1 (this task, the
keystone) fixes the bidirectional mapping between a BPMN diagram (edited in 832's Workflow
Designer) and the AEF task/inception-YAML graph.** Child 2 (forward bridge: diagram→tasks) and
Child 3 (reverse discovery: record→diagram) both *implement* this contract — if it's wrong, both
compilers inherit the error. Pin it once, with 832, before either side writes compiler code.

Full research artifact (schema, rulings, dialogue log): `docs/reports/T-2522-bpmn-aef-mapping-contract.md`.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->
- The AEF task graph (tasks + `related_tasks` + arc membership + inception decisions,
  episodic-ordered) is the canonical AEF-side node set. Fabric (code topology) is OUT of scope.
- BPMN's `extensionElements` can carry an `aef:` namespaced identity anchor that survives
  standard-BPMN round-trips (needs 832 confirmation — IW-1/IW-2).

## Open Questions

<!-- IW-N ↔ Q1-Q5 in docs/reports/T-2522-bpmn-aef-mapping-contract.md. Dispositions filled on
     832 convergence. -->

- **IW-1: Which BPMN extension element holds `aef:task-id` (the identity anchor for round-trip UPDATE-vs-CREATE)?**
  confidence: 1
  disposition: deferred
  rationale: candidates: extensionElements property / bpmn:documentation / custom namespaced attr — 832 owns the BPMN-side ruling; Q1 posted to thread T-175.

- **IW-2: What `aef:` extension namespace URI survives BPMN-standard round-trips without loss?**
  confidence: 1
  disposition: deferred
  rationale: needs 832 to confirm their serializer preserves foreign-namespace extensionElements verbatim.

- **IW-3: What BPMN shape represents an inception DEFER decision (revisit-later), vs GO→children / NO-GO→terminate?**
  confidence: 1
  disposition: deferred
  rationale: GO→build-children flow, NO-GO→terminateEndEvent are clear; DEFER (parked/revisit) has no obvious BPMN idiom — 832 input needed.

- **IW-4: If a diagram has no lanes, is per-node `aef:owner` required, or is there a diagram-level owner default?**
  confidence: 2
  disposition: deferred
  rationale: ruling #6 (node `aef:owner` overrides lane) covers the with-lane case; no-lane fallback is a 832 UX decision.

- **IW-5: Editing a collapsed subProcess (an arc) — does it regenerate the arc YAML, or only its member tasks?**
  confidence: 1
  disposition: deferred
  rationale: arc YAML has its own lifecycle gates (headline_mechanic, close/demo); round-trip write-back semantics need a joint ruling.

## Exploration Plan

<!-- Time-boxed. -->
1. **AEF-side schema draft** (done) — node schema (6 `aef:*` attrs), edge schema, 7 rulings. See artifact.
2. **832 convergence** (in progress) — post Q1-Q5 to thread T-175; collect BPMN-side rulings for IW-1..IW-5.
3. **Round-trip proof** (blocked on 2) — one worked example: task graph → BPMN → task graph, byte-identity on `aef:task-id`.
4. **Recommendation** — GO (adopt → spin Child 2/3 compiler inceptions) or NO-GO (if round-trip proves lossy beyond the extension layer).

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** the AEF↔BPMN node/edge/decision mapping contract (the schema + rulings both compilers
must obey); convergence with 832 on the BPMN-side shapes; a round-trip identity proof.
**OUT:** writing either compiler (Child 2/3); fabric/code-topology ingestion (later phase);
the 832-side serializer implementation (832 owns it). This inception produces a *contract*, not code.

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

Exploration just opened. The mapping contract needs the AEF-side node/edge schema drafted + convergence with 832 (workflow-designer) on the BPMN-side shapes and the extension mechanism for the identity anchor. Recommendation (GO/NO-GO on adopting the contract) pending that evidence. Honest evidence-gap DEFER, not a hedge — the artifact is empty at filing.

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

### 2026-07-10T16:53:10Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
