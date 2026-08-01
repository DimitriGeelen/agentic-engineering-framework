---
id: T-2715
name: "first-run experience: why four green install surfaces missed a blocked user"
description: >
  Inception: first-run experience: why four green install surfaces missed a blocked
  user

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-01T10:01:22Z
last_update: '2026-08-01T10:15:06Z'
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
  - ts: '2026-08-01T10:03:36Z'
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
  - ts: '2026-08-01T10:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2715: first-run experience: why four green install surfaces missed a blocked user

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

Full context, findings and dialogue log: `docs/reports/T-2715-first-run-experience.md`.

- **IW-1: What isolation mechanism gives a genuinely fresh machine per run?**
  confidence: 3
  disposition: answered
  rationale: D-1 — two tiers, Docker (fast loop) + VirtualBox (release gate); host verified 2026-08-01 (Docker 29.6.2, VBox 7.0.16 with vboxdrv loaded alongside kvm_amd, /dev/kvm present)

- **IW-2: Which install path do we exercise — greenfield only, or also upgrade of a legacy vendored consumer?**
  confidence: 1
  disposition:
  rationale: greenfield is cheap but is NOT the path that blocked Mehdi (frozen pre-T-2232 sentinel); agent leans both, operator call

- **IW-3: Does the worker self-heal, or halt on first error?**
  confidence: 1
  disposition:
  rationale: prompt instructs repair, so a healing run measures agent resilience not installer correctness (F-3); agent leans both modes, halt-first

- **IW-4: What is the pass oracle, given doctor cannot judge itself?**
  confidence: 2
  disposition:
  rationale: F-4 — doctor lied twice this week (OBS-110/T-2714, T-2713); agent proposes "first governed commit exists + gate demonstrably blocks an ungoverned edit"

- **IW-5: Is fix-the-installer and improve-the-prompt one arc or two?**
  confidence: 1
  disposition:
  rationale: shell/deterministic/exit-codes vs English/non-deterministic/taste; agent leans one arc fenced paste → first governed commit

- **IW-6: What is the run budget, serial or parallel?**
  confidence: 0
  disposition:
  rationale: prompt behaviour is non-deterministic so single runs prove nothing; operator's call, drives whether Tier 1 alone suffices

- **IW-7: Who answers the prompt's `[ASK]` points in an unattended run?**
  confidence: 1
  disposition:
  rationale: STEP 2 (piped installer) and STEP 3 (dir + provider) both block; auto-confirm stops testing the [ASK] design, blocking hangs the run

- **IW-8: Which ref does the worker install from — public GitHub mirror or local master?**
  confidence: 2
  disposition:
  rationale: install.sh clones the public mirror (what users hit); mirror lag is a known condition (T-1594), so local master tests bytes no user can obtain

- **IW-9: When a run surfaces a bug, does this arc fix it or file it?**
  confidence: 2
  disposition:
  rationale: scope fence — fixing inline grows the arc without bound; agent leans file-and-continue with fixes as separate tasks

- **IW-10: What ends the arc — N consecutive clean runs, or a fixed run count?**
  confidence: 1
  disposition:
  rationale: loop-until-dry suits unknown-size discovery; fixed count risks stopping while the tail is still producing

- **IW-11: Which persona — agent-assisted only, or also a human typing README commands by hand?**
  confidence: 1
  disposition:
  rationale: README prompt presumes an agent; a by-hand reader is a different test surfacing different defects

- **IW-12: How are findings classified?**
  confidence: 1
  disposition:
  rationale: without a taxonomy (installer bug / prompt ambiguity / environment / agent error) runs produce anecdotes rather than evidence

- **IW-13: Who is the student — the human or the agent?**
  confidence: 2
  disposition:
  rationale: F-7 — T-001 is owner:agent with 4/4 Agent ACs and zero Human ACs; the AC carrying the education ("understand core principle, task system, enforcement tiers") is assigned to the agent, so the human currently learns nothing

- **IW-14: Prologue or interleaved curriculum?**
  confidence: 2
  disposition:
  rationale: operator wants "gradual deepening discovery", which is structurally incompatible with 5 front-loaded tasks completed before real work begins

- **IW-15: Does the scenario CONTAIN explanations or ROUTE to them?**
  confidence: 2
  disposition:
  rationale: operator's own T-2622 precedence decision (MD thins to principles+pointers, detail lives in maps) implies routing; embedding creates a second source of truth that drifts from CLAUDE.md/FRAMEWORK.md

- **IW-16: What exactly is deficient about the existing `fw onboarding skip`?**
  confidence: 2
  disposition:
  rationale: F-8 — the verb exists (bin/fw:6284) but is absent from README, lib/init.sh and docs/*.md; may be a discoverability fix rather than a new capability

- **IW-17: Does the existing-codebase path (README option B) get a scenario too?**
  confidence: 3
  disposition:
  rationale: F-9 — lib/seeds/tasks/existing/ is empty while greenfield/ has 5 tasks; option B users get no onboarding at all

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

Grill in progress. Five scope decisions are the operator's and materially change what gets built (which install path, heal-vs-halt, oracle, arc fence, run budget). Evidence gap is real and external: the answers are not derivable from the codebase. Flip to GO once the grill resolves.

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

### 2026-08-01T10:03:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
