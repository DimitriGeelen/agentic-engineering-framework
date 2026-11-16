---
id: T-5186
name: "Watchtower overview pages slow down with project volume (/approvals >90s on
  a ~6k-task project): measure, then design a stepped index layer (files stay source
  of truth)"
description: >
  Inception: Watchtower overview pages slow down with project volume (/approvals >90s
  on a ~6k-task project): measure, then design a stepped index layer (files stay source
  of truth)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-11-16T13:47:22Z
last_update: 2026-11-16T16:54:21Z
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
  - ts: '2026-11-16T15:00:32Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=123,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-16T15:01:07Z'
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

# T-5186: Watchtower overview pages slow down with project volume (/approvals >90s on a ~6k-task project): measure, then design a stepped index layer (files stay source of truth)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

dimitri-mint-dev reported (msg fc3a6ba2, 2026-11-16, on their operator's instruction) that Watchtower overview pages get slower as a project grows. The measurements were taken on .107 at load average 37:

| Project | Tasks | `/approvals` load time |
|---|---|---|
| dimitri-mint-dev | ~233 | 0.95 s |
| 1023 | not given | 1.25 s |
| 055 | not given | 4.3 s |
| 1409-sprind | ~6,150 | over 90 s (timed out); `/` also over 90 s |

On 1409, a single task page (`/review/T-6144`) answers in 0.03 s. 1409's Watchtower sits at about 67 % CPU. Since 2026-11-12, Watchtowers started from claude-fw sessions run at CPUWeight=20, so under host load they also get little CPU. Their operator proposes a stepped design: above some volume, a rebuildable index between the task files and Watchtower, with the files staying the source of truth.

Who it hurts: every operator of a large project. Overview pages are where decisions are made (approvals, the home page), and they become unusable. Why now: 1409 is unusable today, and AEF itself has ~5,170 task files.

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

- **IW-1: Where does the time on `/approvals` and `/` go at ~5,000 tasks, in CPU seconds with no CPU contention (in-process profile, not wall time on a loaded host)?**
  confidence: 0
  disposition: open
  rationale: not yet measured
- **IW-2: How much of 1409's >90 s is CPU starvation (CPUWeight=20 at load 37) rather than work, i.e. what does the same page cost on an idle core?**
  confidence: 0
  disposition: open
  rationale: not yet measured
- **IW-3: Does the cost scale with task count (re-reading/re-parsing the corpus per request), and is a per-process cache keyed on file mtimes enough, or is a separate index layer needed?**
  confidence: 0
  disposition: open
  rationale: not yet measured

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

Evidence gap, not a confidence gap: the reported timings mix two causes that have not been separated: per-request re-parsing of the whole corpus (systemic, grows with task count) and CPU starvation (Watchtowers in agentic.slice at CPUWeight=20 on a host at load 37). The next step is a profile of /approvals and / on a large corpus, with CPU weight controlled. The recommendation becomes GO or NO-GO once that profile names where the time goes.

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

### 2026-11-16T13:47:48Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-11-16T16:54:21Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
