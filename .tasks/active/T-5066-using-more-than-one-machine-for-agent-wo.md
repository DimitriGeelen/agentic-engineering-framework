---
id: T-5066
name: "Using more than one machine for agent work: pattern from 1409's node1 write-up
  (remote nodes via TermLink pool topics)"
description: >
  Inception: Using more than one machine for agent work: pattern from 1409's node1
  write-up (remote nodes via TermLink pool topics)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-11-08T19:47:48Z
last_update: 2026-11-08T19:55:13Z
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
  - ts: '2026-11-08T19:48:24Z'
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

# T-5066: Using more than one machine for agent work: pattern from 1409's node1 write-up (remote nodes via TermLink pool topics)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->
On 2026-11-08 the operator asked 1409-sprind for "a write-up to 999 how we can use different nodes with node 1 as the example". 1409 measured node1 idle (0 of 8 slots, CPU 4 %) while this host ran at load 8-13. 1409 and proxmox-ring20-management sent the write-up in three parts (sidecar msgs 7292fad1, a0b54205, ec7b90b8; conversation remote-nodes-node1-writeup) as proposal input for a framework pattern: a project's judge and CPU work runs on another machine through TermLink hub topics, while the single writer stays at home. Question for AEF: does this belong in the framework, and in what shape. Full text: docs/reports/T-5066-remote-nodes-writeup.md.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Is "run a project's jobs on another machine" a framework pattern (owned by AEF, usable by every project), or 1409's and the node operator's own setup that AEF only documents?**
  confidence: 2
  disposition: answered
  rationale: Both, in stages: the contract and its nine rules become a framework pattern document now, and two lessons are AEF bugs to fix now; the client tooling (`fw pool`) stays 1409's until a second project asks (assessment in docs/reports/T-5066-remote-nodes-writeup.md).

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

**Recommendation:** GO (narrow scope)

**Rationale:**

The need is measured (node1 idle under 1 % a day for 12 days while this host was overloaded) and every loss was in the control plane, which is framework territory. Two of 1409's lessons are live bugs in AEF itself. But only one project uses remote capacity so far, and it already has a working client. So: GO now on (a) a framework pattern document "remote capacity" (roles, contract, the nine rules), (b) fixing AEF's 24 pid-only temp names, (c) making the dispatch default timeout fit long builders or say clearly when it kills one. Lift 1409's client into `fw pool` and a Watchtower node view only when a second project asks for remote capacity.

**Evidence:**

- Write-up, all 3 parts plus addendum, addresses masked: docs/reports/T-5066-remote-nodes-writeup.md (assessment at the end)
- Trust boundary already decided by the operator: node1 and Ring20 are trusted (2026-10-27, write-up section 5.1)
- 24 pid-only temp names in lib/ agents/ bin/ web/ (grep for `$$`/`os.getpid()` tmp names); `TERMLINK_WORKER_TIMEOUT` default 600 s at agents/termlink/termlink.sh:72
- Proposed answers to 1409's three questions (entry registry on the node; trust per project in config with operator approval; controller limits stay node config) in the assessment

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

### 2026-11-08T19:48:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
