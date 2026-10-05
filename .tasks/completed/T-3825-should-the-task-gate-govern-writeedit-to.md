---
id: T-3825
name: "Should the task gate govern Write/Edit to paths outside PROJECT_ROOT? (1409
  field report)"
description: >
  1409-sprind, 2026-09-25 09:10Z (rescued 2026-10-04). An orchestrator session could
  not write its own scratch file /root/.claude/jobs/826eacd0/tmp/bericht-focus.txt
  because another session held focus on a placeholder-AC task. Assessment: still true
  at HEAD. check-active-task.sh exempts only PROJECT_ROOT/{.context,.tasks,.claude,.git}
  and */.claude/projects/*/memory/*, so an out-of-project path falls through to G-020/P-002.
  Question: should the gate be bounded to the project it governs, given scratch space,
  and is any out-of-project write a governance concern?

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-10-04T14:34:51Z
last_update: 2026-10-05T22:37:59Z
date_finished: 2026-10-05T22:37:59Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-10-04T14:45:21Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-04T14:45:43Z'
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

# T-3825: Should the task gate govern Write/Edit to paths outside PROJECT_ROOT? (1409 field report)

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

**Rationale:** Two measured reports from 1409 show the gate refusing writes to /root/.claude/jobs/<id>/tmp, a path outside PROJECT_ROOT, because of another session task. check-active-task.sh only exempts in-project framework paths plus the auto-memory dir. Whether the scope gate should govern out-of-project writes at all is a policy question with Tier-1 implications. GO to decide it explicitly instead of leaving it implicit.

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

**Rationale**: Recommendation: GO

Rationale: Two measured reports from 1409 show the gate refusing writes to /root/.claude/jobs/<id>/tmp, a path outside PROJECT_ROOT, because of another session task. check-active-task.sh only exempts in-project framework paths plus the auto-memory dir. Whether the scope gate should govern out-of-project writes at all is a policy question with Tier-1 implications. GO to decide it explicitly instead of leaving it implicit.

**Date**: 2026-10-05T22:37:57Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-10-05T22:37:57Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Two measured reports from 1409 show the gate refusing writes to /root/.claude/jobs/<id>/tmp, a path outside PROJECT_ROOT, because of another session task. check-active-task.sh only exempts in-project framework paths plus the auto-memory dir. Whether the scope gate should govern out-of-project writes at all is a policy question with Tier-1 implications. GO to decide it explicitly instead of leaving it implicit.

### 2026-10-05T22:37:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3cd8c125
- **Timestamp:** 2026-10-05T22:38:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-e589b0b5
- **Timestamp:** 2026-10-05T22:38:03Z
- **Overall:** UNVERIFIED
- **Claims:** 0
- No verifiable claims found in ## Recommendation

### 2026-10-05T22:37:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
