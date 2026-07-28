---
id: T-2663
name: "dispose workflow-process-layer SD register (SD-1 keystone): ratify mirror+rails
  as the Process layer"
description: >
  Operator disposition of the 2026-07-02 package's SD-1..15 decision register, SD-1
  first: is Process the third core concept, and is the delivered mirror+rails architecture
  (corpus + conformance rails + overlay) its ratified shape — retiring the package's
  YAML-canonical/guided-mode form or keeping guided mode as a named future arc. Research
  artifact: docs/reports/T-2662-workflow-process-layer-package-review.md

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [process-layer]
components: []
related_tasks: [T-2662]
arc_id: designer-corpus
created: 2026-07-28T16:18:08Z
last_update: 2026-07-28T17:10:42Z
date_finished: 2026-07-28T17:10:42Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-07-28T16:30:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-28T16:30:08Z'
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

# T-2663: dispose workflow-process-layer SD register (SD-1 keystone): ratify mirror+rails as the Process layer

## Problem Statement

The 2026-07-02 workflow-process-layer package left a 15-item Sovereign decision
register (SD-1..15) entirely undisposed — every disposition is still a design-agent
proposal. Meanwhile the delivered architecture (arc-014 corpus + T-2652 conformance
rails + overlay seam) settled several of those questions de facto, inverting two of
the package's core axes (canonical format: T-2608; enforcement direction: T-2619
keystone). Until the operator disposes SD-1, the repo carries two competing
architectures on paper: the ratified-by-usage mirror+rails shape and the
package's YAML-canonical/guided-mode shape. Full analysis:
`docs/reports/T-2662-workflow-process-layer-package-review.md` (§3 divergences,
§4 per-SD status).

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
- Operator ratifies mirror+rails (corpus + conformance rails + overlay) as the
  Process layer's shape — SD-1 answered "yes, as delivered"; remaining SD items
  inherit (retire guided-mode/YAML-canonical form, or park it as a named future arc)

**NO-GO if:**
- Operator wants the package's original shape (YAML-canonical, guided-mode
  enforcement) pursued instead — delivered architecture becomes transitional

**DEFER if:**
- Operator wants the P4 falsifiability test (T-2664) to run first as evidence

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

**Rationale:** T-2662 review shows the delivered architecture already meets or exceeds the package's interchange (T-2531-T-2543), dogfood (5 live maps), and drift-detection (T-2652 rails) goals while inverting canonical-format (T-2608) and enforcement-direction (T-2619 keystone) deliberately; ratifying mirror+rails as the Process layer makes those inversions the recorded architecture instead of implicit drift. GO = ratify; the register's remaining open items (SD-3/10/13/14) inherit dispositions from this call.

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

**Rationale**: T-2662 review shows the delivered architecture already meets or exceeds the package's interchange (T-2531-T-2543), dogfood (5 live maps), and drift-detection (T-2652 rails) goals while inverting canonical-format (T-2608) and enforcement-direction (T-2619 keystone) deliberately; ratifying mirror+rails as the Process layer makes those inversions the recorded architecture instead of implicit drift. GO = ratify; the register's remaining open items (SD-3/10/13/14) inherit dispositions from this call.

**Date**: 2026-07-28T17:10:41Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-28T17:10:41Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** T-2662 review shows the delivered architecture already meets or exceeds the package's interchange (T-2531-T-2543), dogfood (5 live maps), and drift-detection (T-2652 rails) goals while inverting canonical-format (T-2608) and enforcement-direction (T-2619 keystone) deliberately; ratifying mirror+rails as the Process layer makes those inversions the recorded architecture instead of implicit drift. GO = ratify; the register's remaining open items (SD-3/10/13/14) inherit dispositions from this call.

### 2026-07-28T17:10:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4e6b06a1
- **Timestamp:** 2026-07-28T17:10:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-1ca289a3
- **Timestamp:** 2026-07-28T17:10:43Z
- **Overall:** CONFIRMED
- **Claims:** 6

| Claim | Type | Status |
|-------|------|--------|
| `T-2662` | task | ✓ pass |
| `T-2531` | task | ✓ pass |
| `T-2543` | task | ✓ pass |
| `T-2652` | task | ✓ pass |
| `T-2608` | task | ✓ pass |
| `T-2619` | task | ✓ pass |

### 2026-07-28T17:10:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
