---
id: T-3970
name: "BPMN mapping standard: move who-performs authority from lane to element (832
  T-896 proposal, amend IW-9)"
description: >
  832 proposes amending policy/standards/aef-bpmn-mapping-v1-partI.md: (a) authority
  as a §2 semantic meta-key on the element (aef:meta/@authority, sovereignty|initiative|authority|external);
  (b) aef:laneMeta/@authoringDefault as a §1 presentational (compiler-ignored) key;
  (c) replace §3 IW-9 'owner MUST be its lane, lane is the sole authority-of-record'.
  Evidence per 832: 60/67 lanes in the shared corpus are the actor triple because
  one tenant modelled its own governance; tenant-neutral partitions (domain lanes)
  are blocked; context-memory.bpmn needed authority=none filler with 12 ownerless
  nodes. 832 has built the editor side (T-889/T-892/T-893) and waits on this before
  migrating the 67 lane values in the byte-pinned corpus (832 T-895). IW-9 was a ratified
  v1.1 ruling, so this is a standard change for the operator.

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-10-06T22:39:01Z
last_update: 2026-10-08T10:03:47Z
date_finished: 2026-10-08T10:03:47Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-10-06T22:45:22Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-06T22:45:49Z'
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

# T-3970: BPMN mapping standard: move who-performs authority from lane to element (832 T-896 proposal, amend IW-9)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

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

**Rationale:** GO as a v1.2 amendment with a compatibility rule. The current rule ties two facts together (how the diagram is partitioned, who performs a node) that the corpus already shows are independent: one in nine lanes is not an actor, and a filler value was needed to satisfy the MUST. Element-level authority is read directly by the compiler, so it removes ordering/membership inference rather than adding any. Condition: diagrams declared v1.1 keep lane-derived authority (no silent reinterpretation of pinned maps); v1.2 diagrams require element authority and treat missing as an error, as 832 proposes. authoringDefault is presentational and costs nothing at compile time. 832 has already built and validated the editor side, so the AEF cost is the standard text, the compiler read path and the corpus re-pin after their migration.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-08 — operator walkthrough (chat): GO on B — v1.2 and migrate everything now
- **Chose:** B. Element-level authority (`aef:meta/@authority`, sovereignty|initiative|authority|external) as a §2 semantic key; `aef:laneMeta/@authoringDefault` as a §1 presentational key the compiler ignores; §3 IW-9 ("owner MUST be its lane") replaced; missing element authority is an error. All existing diagrams migrate now — no v1.1 lane-derived compatibility path.
- **Consequence:** 832 proceeds with T-895 (moving the 67 lane values onto elements in the rendered corpus); AEF re-pins the byte-pinned corpus after their migration and updates the forward compiler to read element authority only.
- **Rejected:** A (dual v1.1/v1.2 semantics kept indefinitely); C (keeps the filler workaround and the 12 ownerless nodes).

## Decision

**Decision**: GO

**Rationale**: Walkthrough 2026-10-08, option B: element-level authority as v1.2 and migrate every existing diagram now (832 T-895 proceeds; AEF re-pins the corpus).

**Date**: 2026-10-08T10:03:44Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-08T10:03:44Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Walkthrough 2026-10-08, option B: element-level authority as v1.2 and migrate every existing diagram now (832 T-895 proceeds; AEF re-pins the corpus).

### 2026-10-08T10:03:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c994ca5e
- **Timestamp:** 2026-10-08T10:03:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-9378e226
- **Timestamp:** 2026-10-08T10:03:50Z
- **Overall:** UNVERIFIED
- **Claims:** 0
- No verifiable claims found in ## Recommendation

### 2026-10-08T10:03:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
