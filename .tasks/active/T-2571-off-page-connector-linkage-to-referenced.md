---
id: T-2571
name: "off-page connector linkage to referenced workflows (uuid registry + forward-ref
  capture)"
description: >
  Inception: off-page connector linkage to referenced workflows (uuid registry + forward-ref
  capture)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-20T20:49:13Z
last_update: '2026-07-20T21:00:05Z'
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
  - ts: '2026-07-20T20:50:01Z'
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
  - ts: '2026-07-20T21:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2571: off-page connector linkage to referenced workflows (uuid registry + forward-ref capture)

## Problem Statement

Off-page connectors in designer diagrams are name-only visuals — nothing links them to the workflow they reference. The store has no immutable workflow identity (directory slug only), `/api/save` and `fw bpmn compile` have no resolution surface, so a dangling reference (referrer drawn before the target workflow exists) is silently invisible. Operator sketch (2026-07-20): mint a UUID entry at reference time, claim it when the target is created; in parallel propose a task to document the referenced workflow. Research artifact: `docs/reports/T-2571-offpage-connector-linkage.md`.

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

- **IW-1: What is the workflow identity model — immutable uuid in meta.json (slug as display) or slug-only pins?**
  confidence: 3
  disposition: answered
  rationale: operator steer 2026-07-20 dialogue — uuid-canonical as recommended (T-1848 precedent)
- **IW-2: How are forward references captured — pending-ref registry file, ghost store entries, or hybrid (registry + gallery ghost rendering)?**
  confidence: 3
  disposition: answered
  rationale: operator steer 2026-07-20 — ghosts, WITH back-reference visual markers (which workflows/nodes reference it + needs-mapping state); registry is the data source, gallery renders ghosts from it
- **IW-3: When is the documentation task for a referenced-but-uncreated workflow minted — at save-time through the FW_TASK_ORIGIN gate, or batch-proposed at a governed verb (refs/promote/compile)?**
  confidence: 2
  disposition: answered
  rationale: operator delegated ("most reliable") — save-time gate minting (capture-at-source, idempotent per uuid) + compile WARN + audit sweep backstop; two-layer pattern per T-2204 precedent
- **IW-4: How does a newly created workflow claim a pending uuid — designer UI picker (832-side), CLI claim verb, or name-match heuristic?**
  confidence: 1
  disposition:
  rationale: operator asked for elaboration (2026-07-20); agent proposal = UI picker + CLI claim fallback, no silent name-match; awaiting operator confirm after elaboration
- **IW-5: What is the AEF/832 seam split, and does 832 accept the vocabulary extension (workflowRef on aef:link)?**
  confidence: 1
  disposition:
  rationale: operator said run in parallel — seam proposal posted to 832 at rail offset 107 (Q1 attr shape, Q2 draw-time uuid mint, Q3 claim UX + GET /api/workflows contract); awaiting 832 reply

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

**Recommendation:** DEFER

**Rationale:**

Evidence gap: operator design dialogue in progress (identity model, ghost visibility, task-minting timing undecided) and 832 seam position not yet requested — DEFER until dialogue converges

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

### 2026-07-20T20:50:00Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
