---
id: T-4737
name: "Which designer data APIs should AEF serve (/api/validate, /api/instances, /api/field-profile,
  /api/field-suggestions)?"
description: >
  Inception: Which designer data APIs should AEF serve (/api/validate, /api/instances,
  /api/field-profile, /api/field-suggestions)?

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-24T20:09:41Z
last_update: '2026-10-24T20:30:39Z'
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
  - ts: '2026-10-24T20:19:29Z'
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
  - ts: '2026-10-24T20:30:39Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=143,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4737: Which designer data APIs should AEF serve (/api/validate, /api/instances, /api/field-profile, /api/field-suggestions)?

## Problem Statement

Designer 0.26.0, served at http://192.168.10.107:3000/designer, calls four data endpoints that AEF does not answer. As a result, Check (validation), the instance overlay, the project field profile and "Suggest as a field" are all off in AEF. Under the operator ruling, AEF serves the designer's data APIs but never its UI, so these fall on AEF's side. The question is which of the four to build. Contract: `docs/reports/T-4737-designer-data-apis.md`, from 832 msg 047ee6a3; their full contract is 832 `docs/reports/T-1300-designer-data-api-contract.md`.

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

- **IW-1: Should AEF serve POST /api/validate (designer Check)?**
  confidence: 2
  disposition: answered
  rationale: 832 ships the validator as one stdlib file (tools/validate-workflow.py, run_xml()) with each release, so the route is a thin wrapper that holds no rules. Pinning that file alongside the designer keeps it from drifting. Cost is low and value is direct: operators see findings as they edit. Recommend GO.
- **IW-2: Should AEF serve GET /api/instances (live tasks drawn on the map)?**
  confidence: 1
  disposition: answered
  rationale: AEF tasks carry no current_node. The mapping exists only for aef-task-lifecycle, whose state-carrier nodes are tl_create/tl_work/tl_heal/tl_human_review/tl_archive (CLAUDE.md §Task Lifecycle). It is valuable but needs a state-to-node mapping per map. Recommend GO scoped to aef-task-lifecycle only, with NO-INSTANCES for every other map.
- **IW-3: Should AEF serve GET/PUT /api/field-profile and GET/POST /api/field-suggestions?**
  confidence: 2
  disposition: answered
  rationale: These are write paths with an operator-approval flow (profile.fields approved_by). Nothing recorded shows demand for designer-side field authoring in AEF. Recommend NO-GO for now; revisit when an operator asks for field settings. Absence is already a clean state: the HTML 404 shows the read-only panel.

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
**GO (per endpoint) if:**
- The endpoint can be served without AEF holding designer rules or UI (operator ruling)
- 832's contract and reference tests give a deterministic acceptance target
- The data it needs already exists in AEF, or comes from a bounded mapping

**NO-GO (per endpoint) if:**
- It needs a write path or approval flow nobody has asked for
- Its absence is already a clean state, so the designer degrades quietly

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

**Recommendation:** GO — build `/api/validate` and `/api/instances` (scoped to aef-task-lifecycle); do not build field-profile or field-suggestions for now

**Rationale:**

The contracts have arrived (832 msg 047ee6a3); this replaces the filing-time DEFER.

`/api/validate` is a thin wrapper over 832's own stdlib validator, pinned with each designer release. AEF holds no rules, so it stays inside the ruling (AEF serves data, never designer UI or logic) and cannot drift. It turns on Check for every map an operator edits.

`/api/instances` draws live tasks on the task-lifecycle map. Only that map has state-carrier nodes for task status. Every other map answers NO-INSTANCES, which the contract allows.

field-profile and field-suggestions are write paths with an operator-approval flow. Nothing recorded asks for them, and their absence already degrades cleanly to a read-only panel.

**Evidence:**
- Contract and live probe: `docs/reports/T-4737-designer-data-apis.md`. Correction from 832 (msg cae77bad): **Check is visibly broken in AEF today**. Pressing it shows "could not check: HTTP 403" and logs a fault, because a person-initiated call is never quiet. The other three are quietly off on their HTML 404. Of the four endpoints, validate is the one where not building it leaves something broken.
- Acceptance: 832's designer-side headless tests (`test_t961_designer_validate_reach.py`, `_t884-instance-overlay-cdp.mjs`) run against AEF's server.
- 832 offers reference tests as acceptance criteria for whichever endpoints are built.
- Proposed build slices if GO: (1) pin `validate-workflow.py` with the designer and serve `/api/validate`; (2) serve `/api/instances` from task status → aef-task-lifecycle nodes, cross-checked by the T-2621 conformance rail.

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

### 2026-10-24T20:19:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
