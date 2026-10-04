---
id: T-3818
name: "Ring20 Manager committed directly to AEF master (eb49ff9, 2026-10-04 07:25Z,
  removing the OneDev LXC prod-deploy job): agree with ring20 how AEF master is protected
  — OneDev branch protection, who may write, and the route for cross-project change
  requests"
description: >
  Operator 2026-10-04: 'the fact that Ring20 Manager could commit to our master is
  not good; talk to Ring20 Manager how we can change that'. ring20-manager pushed
  eb49ff9 straight to AEF master (operator-requested change, via ring20 T-2216). master
  is the consumer install surface and receives only release fast-forwards from bleeding-edge
  (Release-Train model); PROTECT_MASTER is a local hook and cannot stop a remote push.
  It blocked the v1.8.0 release until merged into bleeding-edge. Questions: OneDev
  branch protection on master (release-only writer), ring20's write access to the
  AEF repo, and the sanctioned path for a change ring20 needs in AEF (sidecar request/pickup
  to 999, or a PR into bleeding-edge).

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [security, release-train, ring20]
components: []
related_tasks: [T-3785, T-3185]
bvp_scores: {D1: 4, D2: 5, D3: 3, D4: 3}
confirmed_by: operator
confirmed_at: 2026-10-04T13:34:11Z
confirmed_via: human   # operator ruling 2026-10-04: "give the very high value", "on horizon now, picked up soon after this"
created: 2026-10-04T13:34:11Z
last_update: 2026-10-04T22:34:33Z
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
  - ts: '2026-10-04T13:45:21Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-04T22:34:34Z'
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

# T-3818: Ring20 Manager committed directly to AEF master (eb49ff9, 2026-10-04 07:25Z, removing the OneDev LXC prod-deploy job): agree with ring20 how AEF master is protected — OneDev branch protection, who may write, and the route for cross-project change requests

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

- **IW-1: Which identity and credential did ring20-manager push to AEF master with, and what other write access to the AEF repo does ring20 rely on?**
  confidence: 0
  disposition:
  rationale: asked ring20-manager on sidecar conversation aef-master-protection (msg e45cd15c, 2026-10-04)
- **IW-2: Does ring20 object to OneDev branch protection on master (release fast-forwards only, no direct pushes)?**
  confidence: 0
  disposition:
  rationale: same message
- **IW-3: Which path should ring20 use for future AEF changes — sidecar request to 999, patch bundle (832 style), or a branch/PR into bleeding-edge?**
  confidence: 1
  disposition:
  rationale: release-train model (CLAUDE.md §Release-Train) makes bleeding-edge the only authored branch; ring20's preference asked
- **IW-4: Does any ring20 automation (CI, mirror, timers) write AEF master or tags that protection would break?**
  confidence: 0
  disposition:
  rationale: eb49ff9 edited .onedev-buildspec.yml (the GitHub mirror job lives there); asked ring20-manager

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

**Recommendation:** GO

**Rationale:** A peer agent wrote the consumer install surface directly, bypassing the release train and every client-side gate; server-side protection plus an agreed request path is the only control that holds, and ring20 must be party to it because it currently relies on that access.

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

### 2026-10-04T22:34:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
