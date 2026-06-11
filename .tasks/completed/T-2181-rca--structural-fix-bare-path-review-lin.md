---
id: T-2181
name: "RCA + structural fix: bare-path review links in chat output (T-2030 gap)"
description: >
  T-2030's structural fix covers file artifacts (## Recommendation Evidence, Human
  AC Steps) via lib/review.sh + reviewer detector review-link-homework + transition-time
  gate. None of these surfaces see chat output — agent emits bare /review/T-XXX in
  session summary tables and the structural net never fires. 2026-06-02 regression
  incident: 3 sibling memories ([[feedback_review_concrete_links]] + [[feedback_handoff_url_per_class]]
  + [[feedback_human_review_links]]) all told the agent to emit full URLs; brevity
  in session-summary table caused regression to bare paths anyway. Inception question:
  what structural mechanism catches/prevents bare paths in chat output where no file
  artifact exists for an existing hook to scan?

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-06-02T19:13:31Z
last_update: '2026-06-11T22:24:10Z'
date_finished: 2026-06-02T19:24:22Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-02T19:13:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-02T19:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-2181: RCA + structural fix: bare-path review links in chat output (T-2030 gap)

## Problem Statement

When the agent hands work to the operator for [REVIEW] in **chat output** (session
summary tables, mid-thread responses, hand-off prose), it emits bare paths
(`/review/T-XXXX`) instead of full clickable URLs (`http://192.168.10.107:3000/review/T-XXXX`).
Operator has to construct URLs by hand, remember the per-project port, or scroll back
to find one.

T-2030 (GO 2026-05-25) shipped the structural net for **file artifacts** —
`lib/review.sh` validates URLs in `## Recommendation` Evidence + Human-AC `**Steps:**`
against `app.url_map`; reviewer detector `review-link-homework` (T-2140) flags task
bodies; transition-time blocking gate (T-2139) blocks closure. **None of this sees
chat output.** The 2026-06-02 regression hit precisely there — 22 historical hits in
this session's transcript alone (detector prototype).

Research artifact: `docs/reports/T-2181-chat-output-bare-path-rca.md` — full 5-Whys,
4 candidate analysis (A: Stop-hook scanner, B: session-capture scan, C: review-batch
helper, D: A+C combined), empirical prototype evidence, dialogue log.

## Assumptions

- **A1:** Stop hook + UserPromptSubmit hook can read the assistant's just-completed
  turn from the session JSONL. (Validate via Spike 1.)
- **A2:** A regex restricted to bullet/table-cell contexts + code-block stripping
  achieves <5% FP rate. (Partially validated: prototype hit 22 occurrences in this
  session's transcript, zero apparent FPs in sample — `docs/reports/T-2181-…md`.)
- **A3:** A `fw task review-batch T-A T-B …` helper that emits pre-formatted markdown
  with full URLs will be used by the agent when summarising 2+ tasks IF CLAUDE.md
  §Presenting Work for Human Review documents it as the canonical form.

## Exploration Plan

- **Spike 1** (30min, AGENT) — read Claude Code hook contract docs for Stop +
  UserPromptSubmit; confirm transcript-path access + exit-code semantics. (Will
  happen during Slice 2 build.)
- **Spike 2** (30min, AGENT) — prototype `agents/context/chat-bare-path-scan.sh` against
  3 historical transcripts; count hits + FPs. (Partially done — prototype regex
  results recorded in research artifact.)
- **Spike 3** (15min, AGENT) — sketch `bin/fw task review-batch` shape; verify it
  composes from existing `lib/review.sh` helpers. (Will happen during Slice 1 build.)

## Technical Constraints

- Hook scripts must respect path isolation (no edits outside PROJECT_ROOT).
- `.claude/settings.json` Stop and UserPromptSubmit currently have 0 handlers — adding
  them changes the enforcement baseline (L-398). Build slices MUST run
  `bin/fw enforcement baseline` after settings edit.
- Stop hook fires AFTER message emission — cannot prevent the operator from reading
  the bare-path message once. Acceptable trade-off: feedback lands at next user
  prompt, fast enough to course-correct.
- `fw task review-batch` is additive; the existing single-task `fw task review T-XXX`
  must remain unchanged for backward compatibility.
- Build slices must keep `tests/unit/upgrade_fresh_machine_simulation.bats` green
  (T-1633 consumer-fresh contract).

## Scope Fence

**IN:**
- Chat-output bare-path detection (Stop-hook scanner + UserPromptSubmit warning injection).
- Batch helper for multi-task review handoffs in chat (`fw task review-batch`).
- CLAUDE.md §Presenting Work for Human Review rule update documenting both.
- bats + E2E evidence per slice (works) + regression net (doesn't break).

**OUT:**
- File-artifact coverage (already shipped via T-2030/T-2139/T-2140).
- Re-writing bad URLs (flag, don't auto-correct — same as T-2030's scope).
- External (non-Watchtower) URLs.
- Modifying transcript JSONL or capturing prompts (read-only scan).

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

**Recommendation:** GO — Candidate D (combined: helper + Stop-hook scanner).

**Rationale:** Candidate A (Stop-hook scanner) alone catches regressions but doesn't
reduce their rate. Candidate C (review-batch helper + CLAUDE.md rule) alone relies on
agent discipline that has demonstrably failed (this exact recurrence). Combined: C
cuts the regression rate by making the right thing cheaper than the wrong thing;
A is the structural backstop catching residual misses. Layered defence mirrors the
T-2030 architecture (documentation + tooling + hook) which has held for file
artifacts since 2026-05-25.

**Evidence:**
- 22 occurrences of bare-path patterns in this session's 5-day transcript (detector
  prototype, `docs/reports/T-2181-chat-output-bare-path-rca.md`).
- Zero apparent FPs in inspected sample — pattern is real and unambiguous.
- T-2030's file-artifact coverage shipped 2026-05-25 and has held (no regression on
  task `## Recommendation` or Human-AC Steps surfaces since); chat is the only
  uncovered surface.
- Memory-as-advisory has failed: 3 sibling memories
  ([[feedback_review_concrete_links]], [[feedback_handoff_url_per_class]],
  [[feedback_human_review_links]]) did not prevent the 2026-06-02 regression.
  CLAUDE.md "Structural enforcement over agent discipline" applies.
- Existing hook plumbing supports the design: `.claude/settings.json` Stop and
  UserPromptSubmit arrays exist and are currently empty (0 handlers each) — clean
  insertion point with no existing-handler interaction risk.
- Build cost is bounded: each slice is ~1 session of build + bats + E2E + non-breakage
  evidence. Two slices, parallelisable.

**Build slices to file on GO:**
1. **Slice 1 (Candidate C):** `bin/fw task review-batch T-A T-B …` emits a markdown
   table of full URLs ready for paste. Add to CLAUDE.md §Presenting Work for Human
   Review as the canonical multi-task hand-off form.
   - Works: bats test asserts table shape + URL correctness; E2E paste-and-grep test.
   - Doesn't break: `fw task review T-XXX` single-task form unchanged; consumer-fresh
     bats simulation green.
2. **Slice 2 (Candidate A):** `agents/context/chat-bare-path-scan.sh` (Stop-hook) +
   UserPromptSubmit injector that surfaces violations at next prompt. Wire into
   `.claude/settings.json`.
   - Works: bats test on regex (positive + negative corpus); E2E test where bare-path
     message in turn N triggers system-reminder in turn N+1.
   - Doesn't break: existing hooks unaffected (Stop + UserPromptSubmit currently 0
     handlers); `bin/fw enforcement baseline` refreshed; consumer-fresh bats green;
     FP-rate measured <5% on 30-message backtest corpus.

**What's next (operator approval routing):**
- Inception decide is operator-only under `$CLAUDECODE=1` (T-1259). Use:

  http://192.168.10.107:3000/inception/T-2181

  (or the `/approvals` queue view). Watchtower renders the recommendation, candidates,
  and research artifact link inline. GO triggers automatic build-slice filing per the
  two slices above.

**Why I am not DEFERring** (per [[feedback_defer_for_evidence_not_confidence]],
T-2144 origin): The evidence is complete — 5-Whys, 4 candidates, empirical detector
prototype with hit-count, predecessor chain analysis, and dialogue log all in place.
DEFERring with this much evidence in hand would be hedge-DEFER, not evidence-DEFER.
I have the confidence to recommend GO Candidate D.

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

**Rationale**: Candidate A (Stop-hook scanner) alone catches regressions but doesn't
reduce their rate. Candidate C (review-batch helper + CLAUDE.md rule) alone relies on
agent discipline that has demonstrably failed (this exact recurrence). Combined: C
cuts the regression rate by making the right thing cheaper than the wrong thing;
A is the structural backstop catching residual misses. Layered defence mirrors the
T-2030 architecture (documentation + tooling + hook) which has held for file
artifacts since 2026-05-25.

**Date**: 2026-06-02T19:24:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-02T19:13:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-02T19:24:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Candidate A (Stop-hook scanner) alone catches regressions but doesn't
reduce their rate. Candidate C (review-batch helper + CLAUDE.md rule) alone relies on
agent discipline that has demonstrably failed (this exact recurrence). Combined: C
cuts the regression rate by making the right thing cheaper than the wrong thing;
A is the structural backstop catching residual misses. Layered defence mirrors the
T-2030 architecture (documentation + tooling + hook) which has held for file
artifacts since 2026-05-25.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-99a2a5f9
- **Timestamp:** 2026-06-02T19:24:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-02T19:24:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
