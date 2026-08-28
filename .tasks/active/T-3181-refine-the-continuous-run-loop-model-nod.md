---
id: T-3181
name: "Refine the continuous-run loop model node by node into a buildable spec (arc-012)"
description: >
  Inception: Refine the continuous-run loop model node by node into a buildable spec
  (arc-012)

status: started-work
arc_id: continuous-run
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-26T20:00:07Z
last_update: '2026-08-27T20:15:09Z'
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
  - ts: '2026-08-26T20:01:12Z'
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
  - ts: '2026-08-26T20:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=171,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-27T20:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=8 (lines=248,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3181: Refine the continuous-run loop model node by node into a buildable spec (arc-012)

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

- **IW-1: Which caps may end a run, and what does the "run cap" count — turns, tasks, or sessions?**
  Four caps now exist in `.context/working/.continuous-mode.yaml` (`max_iterations`,
  `max_tasks`, `tier_ceiling`, `expires_after_seconds`). The operator's stated terminal
  conditions are arc-drained or run-cap, and wall-clock is explicitly NOT one of them —
  yet `expires_after_seconds` is the last thing that actually terminated a run.
  confidence: 2
  disposition: deferred
  rationale: The MEASUREMENT half is now settled and was worth settling separately —
    `.context/working/.continuous-mode.yaml` reads `last_terminated_reason: expires_at
    2026-06-17T00:00:00Z passed`, `max_tasks: null` (never configured), `max_iterations: 10`
    with `current_iteration: 3`, `tier_ceiling: 1`. So of the four caps, exactly one has
    ever ended a run, and it is the one the operator says is NOT a terminal condition;
    the other three have never fired because two are unreached and one is unset. The
    DESIGN half — what a "run cap" should count — is a D-1.5 call the operator has not
    made, and node 2 of 15 has not reached it. Deferring the design half rather than
    inferring it from the GO: the GO's own rationale says these are unwalked evidence
    gaps. Evidence needed to close: the operator picks turns | tasks | sessions.

- **IW-2: Does the halt mechanism satisfy the sovereignty requirement now that it is built?**
  v5 filed this MISSING. `stop-driver.sh:60,80-82` reads a halt file as Brake 1, before
  anything else votes. Open: is a file enough without a Watchtower control, and is it
  reachable when the model is the thing misbehaving?
  confidence: 3
  disposition: answered
  rationale: Yes on reachability, no on sufficiency — and the second half is now a
    verified gap rather than a suspicion. Verified: `agents/context/stop-driver.sh:80-82`
    is "Brake 1: the halt file, before anything else gets a vote", ahead of the enabled
    flag and caps (Brake 2, line 107) and the platform runaway guard (Brake 3a, line 86),
    so a halt cannot be outvoted. Reachability holds precisely BECAUSE it is a file: it
    is written from a shell the model does not mediate, so a misbehaving model cannot
    suppress it — which a model-issued halt could not claim. Sufficiency does not:
    `grep -rln halt web/blueprints/ web/templates/` returns NOTHING, so there is no
    Watchtower control at all and the only halt affordance requires shell access. Filed
    as T-3200 rather than left inside this question — an operator watching a runaway from
    a phone has no brake.

- **IW-3: Is a deliberately-RED conformance rail entry a legitimate use of the rail?**
  Registering the `SessionStart source?` gateway as a vocabulary-set entry would go red on
  landing (the `clear` branch is not in `post-compact-resume.sh`'s allowlist) and stay red
  until the allowlist widens — converting prose into a self-reporting audit finding.
  confidence: 1
  disposition: deferred
  rationale: Rail policy is the operator's call and node 2 of 15 has not reached it, so
    recording an answer here would be inventing one. What the walkthrough should weigh is
    stated, so the deferral is not empty: a deliberately-RED entry trades a durable,
    self-reporting finding against the cost every standing red imposes — teaching readers
    that red is the resting state, which is how the t100195 suite (T-3199, filed today)
    stayed broken since T-3094 with nobody noticing. Evidence needed to close: whether
    the rail is treated as must-be-green (then a planted red is corrosive) or as a
    findings surface (then it is exactly the right instrument).

- **IW-4: Is our PreCompact handover already compaction-grade, and how would we know?**
  Nobody has taken `LATEST.md` into a genuinely cold session and measured whether
  it resumes. Cheap to falsify; nothing should be built on top of it before it is.
  confidence: 3
  disposition: answered
  rationale: MEASURED, and the answer is no — PARTIALLY at best. Two TermLink workers,
    same five questions, one variable: arm A saw `LATEST.md` and nothing else (verified
    cold by an upward CLAUDE.md scan); arm B saw the repo, so the 119KB CLAUDE.md
    auto-loaded, as a control. Both returned PARTIALLY. The control not rescuing it is
    the load-bearing result: the deficiency is the handover's own content, not a reader
    lacking framework knowledge, and a single-arm run could not have established that.
    Four defects, both arms converging on the first two: (1) "Suggested First Action"
    names T-1719, which appears nowhere else in the document except as a bare ID and is
    unrelated to the arc the session actually worked — arm B: "state is transmitted,
    intent is not"; (2) ~430 bare task IDs across three frontmatter arrays, roughly a
    third of the document, unusable to both arms; (3) the diffstat says 13 files changed
    and names 4, truncating 9 with no ellipsis — so it reads exactly like a complete
    list; (4) Decisions/failures/blockers all read "None", indistinguishable from an
    unfilled template. Full write-up + reproduction recipe:
    docs/reports/T-3181-iw4-cold-resume.md. NOTE: these are handover-GENERATOR defects,
    separable from arc-012's loop work — they are recorded, not fixed here.

- **IW-5: On hitting a human gate mid-run, does the run park the task and take the next, or stop and notify?**
  (v5's Q5.) With ~48 started-work tasks, most human-owned, an arc drain hits one almost
  immediately. Park-and-next keeps the run alive but grows a pile nobody asked for;
  stop-and-notify is honest but may end the run in its first minutes.
  confidence: 1
  disposition: deferred
  rationale: Explicitly the operator's call — it is a sovereignty question wearing a
    scheduling question's clothes, and picking a default here would be the agent deciding
    how much unreviewed work it may pile up. Node 2 of 15 has not reached it. One datum
    added since v5 that sharpens the choice: today's `fw review-queue` shows 280 tasks
    already awaiting human verification, so park-and-next would not START growing a pile
    nobody asked for, it would feed an existing one — which weakens the "keeps the run
    alive" argument considerably. Evidence needed to close: the operator picks, and if
    park-and-next, names the cap on parked tasks per run.

- **IW-6: Why did the claude-fw wrapper leave its restart loop instead of iterating?**
  Measured tonight: restart branch ran at 21:25:46 (sentinel written), but the wrapper
  running now is a different PID started by hand at 21:39:52. Links 1-4 fired; link 5
  did not. Not in v5 — v5 records the supervisor as live with only a flag defect.
  confidence: 2
  disposition: deferred
  rationale: Still open on its original question, but the EVIDENCE GAP it named is now
    half-closed and the remaining half is measured rather than asserted. T-3206 shipped
    the arm-time `start` event this question implied was missing, so a supervisor now
    records that it armed, and a start line whose pid is dead reads "killed, not stopped"
    instead of green. Re-measured today: `.context/working/continuous-run.jsonl` STILL
    does not exist. Discriminated rather than assumed — the two explanations (the running
    wrapper predates the change / the start event does not fire) are not equally likely
    but are equally consistent with an empty directory. Verified: this session's
    supervisor is pid 1851680, started 2026-08-27 10:52:14; T-3206 landed b072d815f at
    2026-08-28 16:14:24, twenty-nine hours later, so the live wrapper never executed the
    new line; and `tests/unit/t3206_continuous_run_ledger.bats` is 12/12 green, so the
    shipped path does fire. The absence is the old process, not a false green. What
    remains open is the original question — WHY the 21:25:46 wrapper's process ended —
    and that needs a run armed after T-3206 to answer, which no restart has yet produced.
    Evidence needed to close, unchanged: one wrapper lifecycle recorded end to end.
    Found while re-measuring: the doctor surface reports "Expected when the session was
    not launched via claude-fw" while claude-fw IS running and supervising, and would say
    the same thing if the deliberately non-fatal recorder had silently failed to write.
    Filed separately rather than fixed here.

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

**Recommendation:** DEFER

**Rationale:**

Filed at the start of the walkthrough — the operator and I are about to go through draft-continuous-run-loop v5 node by node. The four open questions (IW-2 halt authority, IW-3 deliberately-red rail entry, IW-4 is PreCompact compaction-grade, Q5 park-vs-notify on a human gate) are genuine evidence gaps, not confidence gaps: none has been walked yet. This DEFER is expected to resolve to GO or NO-GO per node as the dialogue produces evidence.

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

**Decision**: GO

**Rationale**: Operator recorded GO on 2026-08-27 — the walkthrough of
draft-continuous-run-loop v5 proceeds node by node.

Note on the record: the verdict flipped DEFER → GO but this rationale text was
carried over verbatim from the DEFER filing, so it read as a deferral under a GO
heading. Rewritten here rather than left standing, because the stale wording said
the opposite of the decision it was filed under.

The GO authorises the walkthrough; it does not retroactively answer the open
questions. Their dispositions are recorded per-question in §Open Questions: one
answered on verified evidence (IW-2), five deferred with the specific evidence
each still needs. The original rationale's own claim — that these are genuine
evidence gaps, not confidence gaps, and that none had been walked — remains true
of the five, and is the reason they were not upgraded to "answered" on the
strength of the GO alone.

**Date**: 2026-08-27T11:12:10Z (verdict), disposition pass 2026-08-27

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-26T20:01:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-27T11:12:10Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Filed at the start of the walkthrough — the operator and I are about to go through draft-continuous-run-loop v5 node by node. The four open questions (IW-2 halt authority, IW-3 deliberately-red rail entry, IW-4 is PreCompact compaction-grade, Q5 park-vs-notify on a human gate) are genuine evidence gaps, not confidence gaps: none has been walked yet. This DEFER is expected to resolve to GO or NO-GO per node as the dialogue produces evidence.
