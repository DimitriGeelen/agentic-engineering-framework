---
id: T-4309
name: "Should AEF own a joint agent-profile v1 schema (profile, route, instance) for
  every agent an orchestrator starts?"
description: >
  055 proposal at its operator's ruling (055 T-562/T-564): one standard per-agent
  configuration (model, provider, mailbox, MCP, instructions, plugins, paths) shared
  by AEF, TermLink, Ring20 Manager and the cockpit; Ring20 Manager's three-layer registry
  format (PROFILE/ROUTE/INSTANCE) as starting point; AEF asked to own the draft since
  it owns the harness adapters.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [orchestration, agent-profile]
components: []
related_tasks: []
origin: {kind: "peer", source: "055"}
created: 2026-10-18T13:49:36Z
last_update: 2026-10-18T18:41:36Z
date_finished: 2026-10-18T18:41:36Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-10-18T14:01:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-18T14:02:09Z'
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

# T-4309: Should AEF own a joint agent-profile v1 schema (profile, route, instance) for every agent an orchestrator starts?

## Problem Statement

055 asks, at its operator's ruling (055 T-562 GO, T-564), whether AEF will own a joint "agent-profile v1" schema:
one standard way for any orchestrator (AEF dispatch, TermLink, Ring20 Manager, the cockpit) to give every agent it
starts its own configuration — model, provider, mailbox (sidecar identity), MCP servers, instructions, plugins,
readable/writable paths. Starting point: Ring20 Manager's registry format (PROFILE / ROUTE / INSTANCE layers), live
for 7 one-shot commissions. Today AEF holds these facts in several places with no common schema (see the research
artifact docs/reports/T-4309-agent-profile-v1.md). Why now: three projects are about to build their own variants.

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

- **IW-1: Should AEF own (author and maintain) the agent-profile v1 schema, or only review and consume one owned elsewhere (Ring20 Manager, TermLink)?**
  confidence: 1
  disposition: deferred
  rationale: operator's strategic call; artifact lists what AEF already owns that overlaps
- **IW-2: Which of AEF's existing per-agent facts (review-backends registry, review-worker settings, sandbox profile, dispatch --model/--env/--tools, rail identity) would v1 replace, and which would stay AEF-internal?**
  confidence: 1
  disposition: deferred
  rationale: inventory in docs/reports/T-4309-agent-profile-v1.md; mapping to the 3 layers pending the briefing read
- **IW-3: Is the PROFILE/ROUTE/INSTANCE split compatible with AEF's governance boundaries (operator-owned policy files, agent proposes / operator approves, the sandbox enforces)?**
  confidence: 1
  disposition: deferred
  rationale: briefing claims "profiles operator-changed, agents only propose, sandbox enforces" — to verify against the text

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

**Recommendation:** GO (scoped)

**Rationale:** AEF already owns the ROUTE layer in practice (ring20 binds its routes to AEF's policy/review-backends.yaml) and holds most PROFILE facts in five differently shaped files, with no single answer to "what was this agent given". The proposed governance (operator-owned profiles, agents propose, narrowing-only auto-admit, sandbox enforces) matches AEF's own Authority Model. Own the schema, a validator and AEF's own consumption; do NOT own other orchestrators' launchers or sandboxes. Evidence and the field-by-field inventory: docs/reports/T-4309-agent-profile-v1.md.

**Evidence:**
- Ring20 briefing T-2403 read (S-1 live: 2 capabilities, 7 commissions, 85-check preflight, 9 lessons)
- AEF inventory: review-backends.yaml (ROUTE), review-worker-settings.json, tool-set.yaml, sandbox-profile.yaml, dispatch --model/--env/--tools, rail-identity (mailbox)
- Shared-identity lesson (ring20 G-215, our T-4311) shows the mailbox field is needed, not optional

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

**Rationale**: AEF already owns the ROUTE layer in practice (ring20 binds its routes to AEF's policy/review-backends.yaml) and holds most PROFILE facts in five differently shaped files, with no single answer to "what was this agent given". The proposed governance (operator-owned profiles, agents propose, narrowing-only auto-admit, sandbox enforces) matches AEF's own Authority Model. Own the schema, a validator and AEF's own consumption; do NOT own other orchestrators' launchers or sandboxes. Evidence and the field-by-field inventory: docs/reports/T-4309-agent-profile-v1.md.

**Date**: 2026-10-18T18:41:35Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-18T15:58:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-18T18:41:35Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** AEF already owns the ROUTE layer in practice (ring20 binds its routes to AEF's policy/review-backends.yaml) and holds most PROFILE facts in five differently shaped files, with no single answer to "what was this agent given". The proposed governance (operator-owned profiles, agents propose, narrowing-only auto-admit, sandbox enforces) matches AEF's own Authority Model. Own the schema, a validator and AEF's own consumption; do NOT own other orchestrators' launchers or sandboxes. Evidence and the field-by-field inventory: docs/reports/T-4309-agent-profile-v1.md.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cd76fded
- **Timestamp:** 2026-10-18T18:41:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-57757b70
- **Timestamp:** 2026-10-18T18:41:39Z
- **Overall:** CONFIRMED
- **Claims:** 2

| Claim | Type | Status |
|-------|------|--------|
| `T-2403` | task | ✓ pass |
| `T-4311` | task | ✓ pass |

### 2026-10-18T18:41:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
