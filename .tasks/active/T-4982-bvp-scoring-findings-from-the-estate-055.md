---
id: T-4982
name: "BVP scoring findings from the estate (055 T-677): unknown is not 0, evidence-cited
  scores, no batch rewrites, horizon in rank"
description: >
  055-agentic-fleet-cockpit (msg d6ab6680, estate survey of 11 of 13 agents, their
  docs/reports/T-677-*): (1) no-signal is written as a number (0, 2, 108) and enters
  sums/medians/ties; wants an explicit unknown; (2) task scores 0-5 cannot express
  harm while decision briefs use -2..+2 (bvp.sh range check); (3) a driver score with
  no cited fact should count as unknown; estimator scores wording and treats its own
  earlier rationale as evidence; (4) estimate all rewrote last_update on 382 tasks
  (ring20-dashboard) and the sweep rewrites other tasks' frontmatter (1023 T-120);
  (5) driver weights cap project work at 0.444 (1409: 55.6% of weight on framework
  internals) - per-arc driver sets T-4961 may address it; (6) estimator AUC 0.62-0.66
  vs operator choice, 'operator ruled/reported it' alone 0.75; fw bvp rank ignores
  horizon (5 of 055's top 15 are parked). One inception to triage which become build
  tasks; (4) and the horizon point look like plain bugs.

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: []
components: []
related_tasks: []
created: 2026-11-01T20:35:15Z
last_update: '2026-11-01T20:45:31Z'
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
  - ts: '2026-11-01T20:45:17Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=112,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-01T20:45:31Z'
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

# T-4982: BVP scoring findings from the estate (055 T-677): unknown is not 0, evidence-cited scores, no batch rewrites, horizon in rank

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->
`fw bvp` does not predict what the operator chooses, across the estate (055 T-677 survey, 11 of 13 agents; msg d6ab6680). Six findings are in the description. Evidence 055 sent for this task (msg 927f9b3a, 2026-11-01), kept here verbatim in substance:

- **AUC method (055 T-677-ground-truth.md):**
  - Chosen tasks: 489, i.e. completed in the last 45 days, or carrying an "operator ruling" or a Dialogue Log.
  - Not chosen: 64 tasks, active and parked (horizon later/next) or stale captured.
  - Score: the confirmed score, else the latest proposed score, weighted (max 270).
  - Results: value AUC 0.66; pre-finish proposal 0.69; `fw bvp` position 0.59; constants removed 0.62; operator-ruling tasks alone 0.75.
  - Ties: 389 scored tasks share only 57 distinct values. Of the 110 tasks with no signal at all, 79 score 0 and 31 score 108, and the 108s rank above every varied score.
- **Their top 15 on 2026-11-01** (`fw bvp --include-proposed`): 9 are already started (in-progress work is listed as a candidate), 5 are parked later/next, and 3 carry the constant no-signal 108. Only one is both waiting and horizon now.
- **Trust meter (055 T-678, 2026-10-02 to 11-01):**
  - 211 picks: 137 were new work, never in the backlog; 74 came from the backlog, and 69 of those had no score when picked.
  - The top-ranked task was picked once: override rate 98.6 %.
  - **Corrected by 055 (msg 033615f1, after the meter's review round 2):** `fw bvp` as it ranks put either T-058 (parked later all window, constant 108) or T-474 (already started) on top for 71 of the 74 backlog picks. That is the started-and-parked defect.
  - Counting only real candidates (captured, horizon not later): the top-ranked was picked once, a top-5 task 5 times out of 74, and the top candidate (T-475) was top for 58 picks.
  - The override rate is unchanged at 98.6 %. Report: 055 `docs/reports/T-678-pick-meter-first-report.md` (round 3 PASS).
- **Candidate defects visible already:**
  - no-signal is written as a number (0 or 108);
  - the rank lists started work and parked work as candidates;
  - the estimator sweep rewrites other tasks' frontmatter.

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

**Rationale:** Six cross-project findings received; needs evidence excerpts from 055 and a design read of the estimator before a GO/NO-GO.

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
