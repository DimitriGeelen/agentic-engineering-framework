---
id: T-4470
name: "Adopt 832's runme job queue (data-defined operator jobs, sha-bound dry run,
  y/N per step, ordered batches, signal library + watcher) into fw runme?"
description: >
  Proposal from 832-Workflow-designer at their operator's request (msg ff397b49, 2026-10-20).
  Covers: one fixed operator command; jobs as data, not safety code; a required, sha-bound
  dry run; y/N per step from the terminal with typeahead discarded; a menu of job
  states; ordered BATCHES (arrow-key picker or typed 3,1,2 / x=all; refused up front
  if any job unready; stops at first failure); a signal library (events file + TermLink
  topic, from traps) and a background watcher whose exit wakes the agent. 56 jobs
  run in 832 since 2026-10-05. Write-up: 832 docs/reports/runme-job-queue-for-aef.md
  at 7c1bea00 (§9 compares with fw runme T-3675; §10 the proposal: items 1-5 to port,
  6-8 unbuilt ideas). Code: runme.sh, tools/runme-{launcher,signal,watch,new}.sh,
  tests test_t1055_runme_launcher.py (26 legs), test_t1003_runme_signal.sh (11). Overlaps
  AEF fw runme (T-3675), runme watch --until (T-4464), and the T-4435 answer/notice
  discussion. Pickup rule (G-020): proposal, not a build spec.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-20T13:47:07Z
last_update: '2026-10-20T14:00:36Z'
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
  - ts: '2026-10-20T13:50:54Z'
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
  - ts: '2026-10-20T14:00:36Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=129,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4470: Adopt 832's runme job queue (data-defined operator jobs, sha-bound dry run, y/N per step, ordered batches, signal library + watcher) into fw runme?

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

- **IW-1: Does the job queue reduce operator friction without weakening any gate (no queued Tier 0 action or approval slips past the operator; the sha-bound dry run binds what runs to what was shown)?**
  confidence: 3
  disposition: answered
  rationale: Friction falls (all 3 seats). Not as written: jobs are loaded into the launcher's shell, so a job can redefine confirm() and defeat per-step consent; the dry run shows titles, not resolved commands; the sha covers job.sh only (codex, claude independently). Relative to today's fw runme nothing is weaker (opencode). Artefact §6
- **IW-2: Which of 832's §10 items 1-5 should AEF port, in what order, and at what cost against fw runme (T-3675, T-4464)?**
  confidence: 2
  disposition: answered
  rationale: Take the fixed command, menu, lifecycle, dry-run requirement, per-step confirm with typeahead drain, ordered batches, tests; order slice 1 menu+lifecycle on out-of-process jobs, slice 2 sha manifest + confirm, slice 3 batches. Artefact §7
- **IW-3: What are the risks (jobs as data: injection/quoting; typeahead discard; batch stop/resume; watcher waking the agent) and are items 6-8 now or later?**
  confidence: 2
  disposition: answered
  rationale: Risks = job code sharing the launcher namespace, probe executing builtins, dry-run checks running real code, narrow sha, scripted-answer override reaching real projects; items 6-8 deferred. Artefact §6 items 1-6, §7

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

**Recommendation:** GO, adapt rather than port.

**Rationale:** All three isolated reviewers agree that the friction reduction is real: one fixed command, a visible queue, ordered batches and per-step confirmation. They also agree, codex and claude independently, that "without weakening any gate" does not hold for 832's code as written:

- jobs are loaded into the launcher's own shell, so a job can redefine `confirm()` and defeat per-step consent;
- the load probe stops only external commands;
- the dry run shows titles, not resolved commands;
- the sha binds only `job.sh`.

opencode's counterpoint stands: relative to today's fw runme, which has no consent at all, nothing is weaker.

So adopt the design, with these prerequisites:

1. Jobs run out-of-process from a declarative step manifest, and launcher functions are unreachable from job code.
2. The confirmation shows the resolved command and helper bodies.
3. A sha manifest covers the job and every helper, checked again before each step.
4. No scripted-answer path outside tests.
5. The queue is never an authorisation: Tier 0 and approvals stay at their own gates.

Port in three slices (menu and lifecycle → sha manifest and confirm → batches); items 6-8 are deferred.

**Evidence:**
- docs/reports/T-4470-runme-job-queue.md §6 (synthesis) and §7 (recommendation).
- Verbatim reviews: docs/reports/T-4470-reviews/{codex,opencode,claude}.md.
- Inputs, sha-verified: docs/reports/T-4470-inputs/.

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

### 2026-10-20T13:50:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
