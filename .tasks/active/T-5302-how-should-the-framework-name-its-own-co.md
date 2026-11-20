---
id: T-5302
name: "How should the framework name its own commands (fw, watchtower) in vendored
  projects, so every printed remedy, page and hand-off runs as written, without path
  rewriting that keeps breaking?"
description: >
  Inception: How should the framework name its own commands (fw, watchtower) in vendored
  projects, so every printed remedy, page and hand-off runs as written, without path
  rewriting that keeps breaking?

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
waiting_on: agent
revisit_at: 2026-11-27
created: 2026-11-20T13:38:57Z
last_update: '2026-11-20T13:39:09Z'
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
  - ts: '2026-11-20T13:39:09Z'
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

# T-5302: How should the framework name its own commands (fw, watchtower) in vendored projects, so every printed remedy, page and hand-off runs as written, without path rewriting that keeps breaking?

## Problem Statement

The framework prints commands for people and agents to run: fw doctor remedies, gate block messages, handover first actions, Watchtower pages, runme scripts. In the framework repo the path is `bin/fw`; in a vendored project it is `.agentic-framework/bin/fw`; on some hosts a `fw` shim is on PATH. Printed commands get this wrong repeatedly: GitHub #68 (fw doctor names `bin/watchtower.sh`, absent in a vendored project), T-609 and T-1257 (handoffs with the wrong path or no cd), T-1633 (fw upgrade depended on the developer's layout). The proposed #68 fix (`bin/fw`) is also not runnable at a vendored project's root. Operator, 2026-11-20: "the bin/fw ... in vendored projects is just really a crappy buggy artifact we still have because it's path rewriting and isolation we should have in the project ... bin/fw is screwing a lot of things up often"; asked for reflection, research (how vendored projects are built, how isolation should work, how Watchtower rewrites pages) and consultation. Research: docs/reports/T-5302-command-naming-vendored.md.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->
- The failures share one cause: each printer decides on its own how to spell the command, instead of one resolver.
- Vendored projects that consult us see the same class of failure.

## Open Questions

- **IW-1: Where does the framework print a command for someone to run, and how does each place spell `fw` today (count by spelling, framework repo vs vendored)?**
- **IW-2: What path rewriting and resolution already exist (fw path resolution in bin/fw, vendoring rewrites, Watchtower page rendering), and where do they disagree?**
- **IW-3: What isolation should a vendored project have (what lives in the project, what in .agentic-framework/, what on PATH), and what should a printed command look like there?**
- **IW-4: What do vendored projects (ring20, 055, 1409, 832, and the outside contributor) see break, and what would they want printed?**

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

**Recommendation:** EXPLORING

**Rationale:**

Operator 2026-11-20 on GitHub #68 (outside PR 2): fw doctor prints bin/watchtower.sh, which does not exist in a vendored project; the proposed fix (bin/fw) is not at the root of a vendored project either. Operator: the bin/fw / bin/watchtower path in vendored projects is a buggy artifact of path rewriting and missing isolation that breaks things often; reflect, research how vendored projects, isolation and Watchtower page rewriting work, and consult before deciding.

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

### 2026-11-20T13:39:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
