---
id: T-3159
name: "Autonomous loop cannot cross a context boundary unattended — model it in the
  designer and fix the driver"
description: >
  Inception: Autonomous loop cannot cross a context boundary unattended — model it
  in the designer and fix the driver

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [arc:continuous-run]
components: []
related_tasks: []
created: 2026-08-26T11:58:42Z
last_update: 2026-08-26T14:27:17Z
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
  - ts: '2026-08-26T12:00:08Z'
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
  - ts: '2026-08-26T12:00:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=123,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3159: Autonomous loop cannot cross a context boundary unattended — model it in the designer and fix the driver

## Problem Statement

**Full artefact: `docs/reports/T-3159-autonomous-loop-context-boundary.md`** (C-001).

The operator reports that continuous/autonomous mode does not continue: at the context
boundary the session is "kicked out" and returns to an idle prompt they must re-enter by
hand. Four defects were located in source this session:

- **F1** no `Stop` / `UserPromptSubmit` / `SessionEnd` hook exists among the 28 registered,
  so `claude-fw`'s auto-restart reopens an **idle** prompt — `FW_NEXT_DIRECTIVE` arrives as
  `additionalContext`, which does not cause a turn. **The loop has no driver.**
- **F2** `claude -c` continues the *same* conversation, so the transcript that just hit
  critical returns whole; `post-compact-resume` resets the budget *gauge* only. It re-crosses
  critical and restarts until `MAX_RESTARTS=5`. **The exit-and-`-c` path cannot free context
  by construction.**
- **F3** `.continuous-mode.yaml` reports `enabled: true` while `last_terminated_reason`
  records `expires_at 2026-06-17` — 70 days expired.
- **F4** `.auto-restart-pending` is consumed only on the `startup` branch, so a leftover
  sentinel makes the next cold start read as a loop continuation.

The operator proposed doing the compaction in-session — precompact, then `/compact` **or**
`/clear` — with the caveat that under `/clear` our own handover must carry everything. That
caveat is **literally the current state**: `PreCompact` has no `/clear` counterpart, and
`post-compact-resume.sh:28` clamps the SessionStart source to `(startup|resume|compact)`, so
`/clear` today gets **zero hooks on both ends**.

**Why now:** the operator asked, and the loop is currently unusable unattended.

## Deliverable

A designer map of the loop with a `vocabulary-set` conformance-rail entry on the
SessionStart-source gateway — which converts F1/F2's `clear` gap from prose in a report into
a rail that goes RED on its own and stays red until the code changes. Authored against
designer **0.11.0** (T-3157), not the 0.8.0 build that was live when the question was asked.

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

- **IW-1: Is the boundary crossing `/compact` or an own-both-ends `/clear`?**
  confidence: 2
  disposition:
  rationale:
  <!-- Operator proposed `/clear` and their caveat is literally correct: PreCompact does
       not fire on it, and post-compact-resume.sh:28 clamps the source allowlist to
       (startup|resume|compact), so `clear` gets NO hooks on either end today. `/clear` is
       deterministic and we control the artefact; `/compact` is lossy and model-written but
       works now. This is the operator's fork, not the agent's. -->

- **IW-2: What terminates a self-driving loop, and who holds that authority?**
  confidence: 1
  disposition:
  rationale:
  <!-- A `Stop` hook that re-injects a directive can, by construction, prevent a session
       from ever ending. Existing caps (max_iterations, expires_at, tier_ceiling in
       .continuous-mode.yaml) were designed for the restart path, not for a turn-driver.
       Whether they are sufficient — and whether the operator must be able to halt it
       without killing the process — is unresolved and is a sovereignty question. -->

- **IW-3: Should the map's `clear` branch be authored RED deliberately?**
  confidence: 2
  disposition:
  rationale:
  <!-- If the map asserts a `clear` branch before the code supports it, the conformance rail
       goes red immediately and stays red until leg 2 lands — the divergence becomes the
       tracking mechanism. T-2619's cascading-detail model says a map graduates to
       detail-authority only when its entry stays green, so a deliberately-red entry is a
       novel use of the rail and needs a ruling, not an assumption. -->

- **IW-4: Does the re-injected handover carry enough to resume cold?**
  confidence: 1
  disposition:
  rationale:
  <!-- Under `/compact` the model summary covers the gap. Under `/clear` there is no summary
       — LATEST.md is the only carrier. It has never been tested as a SOLE carrier, and the
       SessionStart preview is truncated by the harness (docs/context-compaction.md), so
       "the banner appeared" is not evidence the content arrived. Measure before relying. -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** locating the defects (done); checking the operator's `/clear` proposal against the
hook table and source allowlist (done); assessing whether the conformance rail can carry this
machine (done); the four Open Questions; authoring the map on GO.

**OUT — explicitly, until the operator rules:**
- No `Stop` hook is written. IW-2 (what terminates a self-driving loop, and who holds that
  authority) is a **sovereignty** question, not plumbing — a `Stop` hook that re-injects can
  by construction prevent a session from ever ending.
- No SessionStart matcher added, no `post-compact-resume.sh:28` allowlist widened.
- No `.continuous-mode.yaml` re-enable. F3 is reported, not repaired, because re-enabling an
  expired loop while F1 stands would restart the exact behaviour the operator reported.
- No registry entry landed while IW-3 (may a rail entry be authored deliberately RED?) is
  open — T-2619's cascading-detail model assumes entries go green.

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

**Rationale:**

Four defects measured this session, not hypothesised: (1) no Stop/UserPromptSubmit/SessionEnd hook exists, so the auto-restart reopens an idle prompt and nothing takes the next turn — this is the operator's 'kicked back to the general menu'; (2) claude -c restores the same oversized transcript, so the exit-restart path can never free context by construction, and it re-fires until MAX_RESTARTS=5; (3) continuous-mode.yaml reports enabled:true while last_terminated_reason shows expires_at 2026-06-17 passed 70 days ago; (4) .auto-restart-pending is only consumed on the startup branch, so a leftover sentinel makes the next cold start read as a loop continuation. The operator's /clear proposal is structurally sound and sharper than it looks: PreCompact does not fire on /clear and our SessionStart matchers are compact|resume|startup only, with post-compact-resume.sh clamping the source allowlist — so /clear today gives zero hooks on BOTH ends, and the handover would have to carry the whole load exactly as they said. GO rather than DEFER because the evidence is complete; what remains is a fork the operator owns (/compact vs own-both-ends /clear), not a knowledge gap. Deliverable is a designer map with a conformance-rail entry, which converts three of these findings from prose into a rail that goes red on its own.

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

**Rationale**: Four defects measured this session, not hypothesised: (1) no Stop/UserPromptSubmit/SessionEnd hook exists, so the auto-restart reopens an idle prompt and nothing takes the next turn — this is the operator's 'kicked back to the general menu'; (2) claude -c restores the same oversized transcript, so the exit-restart path can never free context by construction, and it re-fires until MAX_RESTARTS=5; (3) continuous-mode.yaml reports enabled:true while last_terminated_reason shows expires_at 2026-06-17 passed 70 days ago; (4) .auto-restart-pending is only consumed on the startup branch, so a leftover sentinel makes the next cold start read as a loop continuation. The operator's /clear proposal is structurally sound and sharper than it looks: PreCompact does not fire on /clear and our SessionStart matchers are compact|resume|startup only, with post-compact-resume.sh clamping the source allowlist — so /clear today gives zero hooks on BOTH ends, and the handover would have to carry the whole load exactly as they said. GO rather than DEFER because the evidence is complete; what remains is a fork the operator owns (/compact vs own-both-ends /clear), not a knowledge gap. Deliverable is a designer map with a conformance-rail entry, which converts three of these findings from prose into a rail that goes red on its own.

**Date**: 2026-08-26T12:11:45Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-26T12:00:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-26T12:11:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Four defects measured this session, not hypothesised: (1) no Stop/UserPromptSubmit/SessionEnd hook exists, so the auto-restart reopens an idle prompt and nothing takes the next turn — this is the operator's 'kicked back to the general menu'; (2) claude -c restores the same oversized transcript, so the exit-restart path can never free context by construction, and it re-fires until MAX_RESTARTS=5; (3) continuous-mode.yaml reports enabled:true while last_terminated_reason shows expires_at 2026-06-17 passed 70 days ago; (4) .auto-restart-pending is only consumed on the startup branch, so a leftover sentinel makes the next cold start read as a loop continuation. The operator's /clear proposal is structurally sound and sharper than it looks: PreCompact does not fire on /clear and our SessionStart matchers are compact|resume|startup only, with post-compact-resume.sh clamping the source allowlist — so /clear today gives zero hooks on BOTH ends, and the handover would have to carry the whole load exactly as they said. GO rather than DEFER because the evidence is complete; what remains is a fork the operator owns (/compact vs own-both-ends /clear), not a knowledge gap. Deliverable is a designer map with a conformance-rail entry, which converts three of these findings from prose into a rail that goes red on its own.

### 2026-08-26T14:27:17Z — status-update [task-update-agent]
- **Change:** tags: +arc:continuous-run
