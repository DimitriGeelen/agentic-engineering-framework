---
id: T-4376
name: "Test-suite refactor: hermetic fast tier that gates the push, slow nightly tier,
  shared fixtures, lints for recurring test-defect classes"
description: >
  Inception: Test-suite refactor: hermetic fast tier that gates the push, slow nightly
  tier, shared fixtures, lints for recurring test-defect classes

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
arc_id: test-suite-health
created: 2026-10-19T11:55:19Z
last_update: 2026-10-19T12:13:43Z
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
  - ts: '2026-10-19T11:56:07Z'
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
  - ts: '2026-10-19T12:00:44Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=140,acs=4)
    rubric_sha: e4a00f38e801
---

# T-4376: Test-suite refactor: hermetic fast tier that gates the push, slow nightly tier, shared fixtures, lints for recurring test-defect classes

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

- **IW-1: Where does the suite's time and nondeterminism actually come from (per-file duration, timeout frequency, load-only reds, tests touching live repo/host state)?**
  confidence: 1
  disposition:
  rationale:
- **IW-2: Can a hermetic fast tier be defined that runs in under 10 minutes and still catches what the pre-push gate exists to catch?**
  confidence: 1
  disposition:
  rationale:
- **IW-3: What does an independent external review (two other vendors) say about how to optimise this, and where does it disagree with the measurement?**
  confidence: 0
  disposition:
  rationale:
- **IW-4: How do we prove a refactored or pruned test still fails on the bug it was written for (no silent coverage loss)?**
  confidence: 1
  disposition:
  rationale:

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
- [x] IW-1 measurement report exists at docs/reports/T-4376-test-suite-measurement.md with the five sections (duration distribution, timeouts, reds/baseline, live-state scan, fast-tier candidate), each stating its method
- [x] Report contains no hostnames or IP addresses
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
test -s docs/reports/T-4376-test-suite-measurement.md
for s in "Duration distribution" "Timeout frequency" "Reds" "Live-state" "Fast-tier"; do grep -qi "$s" docs/reports/T-4376-test-suite-measurement.md || exit 1; done
! grep -qE '([0-9]{1,3}\.){3}[0-9]{1,3}' docs/reports/T-4376-test-suite-measurement.md

## Recommendation

**Recommendation:** GO

**Rationale:**

Evidence from 2026-10-19 alone: a full unit run takes ~55 min over 1,172 files, 5-8 files hit the per-file timeout every run (results not determined), several reds appear only under parallel load (t3636, t2290, hook_telemetry_race, audit.bats exit 124), audit.bats was anchored to the live repo and created a self-sustaining ratchet loop, a test read this project's .framework.yaml (t4347), an old test contradicted a deliberate behaviour change (lib_firewall vs T-4330), and the baseline grew to 44 entries; getting one push through cost two extra full suite runs and an operator baseline step. Measurement and an independent external review come before any build; the go/no-go is the operator's.

Updated after measurement and external review: GO, in a changed order. Both external reviewers (codex, opencode) support the tier split and the fidelity-first rule. Both say the runner's own verdicts are not yet trustworthy enough to tune against. So step 0 is runner accounting (T-4381), triage of the hanging or instant-finish files (T-4382), the audit.bats contract (T-4383), t2332 isolation (T-4384) and the 2026-10-31 baseline cliff (T-4385). Step 1 is the tier split, the helper and the lint (T-4377..T-4379). Pruning (T-4380) waits for a seeded-defect detection baseline.

**Evidence:**

- Measurement: docs/reports/T-4376-test-suite-measurement.md
  - 1,175 files, ~36,200 file-seconds; the top 30 files take 52.6%.
  - A file at the 900 s cap in 16/20 reports; the bats leg exited 0 in none of 81 logged runs.
  - 83% of 246 reds appear in ≤2 of 20 reports.
  - A fast tier of ~950–1,014 files (~80% of tests) fits the budget.
- External review, verbatim: docs/reports/T-4376-reviews/codex.md, docs/reports/T-4376-reviews/opencode.md. Synthesis
  and disagreements: docs/reports/T-4376-test-suite-refactor.md §External review.
- Arc: .context/arcs/test-suite-health.yaml (arc-026), two reviewer-approved drivers.

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

### 2026-10-19T11:56:06Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
