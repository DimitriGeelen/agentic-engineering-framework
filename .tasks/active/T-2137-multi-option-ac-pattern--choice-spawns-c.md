---
id: T-2137
name: "Multi-option AC pattern — choice spawns child inception (T-1776 surfaces the
  gap)"
description: >
  Inception: Multi-option AC pattern — choice spawns child inception (T-1776 surfaces
  the gap)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [inception-spawn, arc-008, multi-option-ac, review-loop, ac-classification]
components: []
related_tasks: [T-1776, T-2101, T-2097, T-2098, T-2100]
arc_id: inception-review-loop
created: 2026-05-31T10:28:56Z
last_update: '2026-05-31T10:30:02Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-31T10:29:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F1: 1
    rationale: "D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); D4=2
      (body:env-class-handled); F1=1 (body/tag hits for 'F1': 1)"
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-31T10:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2137: Multi-option AC pattern — choice spawns child inception (T-1776 surfaces the gap)

## Problem Statement

When a `[REVIEW]` Human AC presents multi-option choices (A/B/C) that each imply a different follow-up task, the framework has no structured way to (a) capture which option the operator picked, (b) auto-spawn the chosen option's follow-up task, (c) link the spawned task back to the parent AC. The current shape forces the pick into chat or commit-message text, producing CTL-029 partial-completes (T-1776 sat completable-but-not-completed for 22 days) and lost provenance (the operator's choice survives only as inference from later commit text).

**Full research artifact:** `docs/reports/T-2137-multi-option-ac-inception-spawn.md` (created before this body per Inception Discipline C-001; contains the dialogue log with operator's verbatim ask).

**Surfaces from:** T-1776 close on 2026-05-31 (commits `625557f1`+`9f08aa42`). Operator: *"in this case we just need to give an option a,b,c which actually should surface with an inception"*.

## Assumptions

- **A1:** Multi-option ACs are a recurring shape, not a one-off — `[REVIEW] Choose A/B/C, file a follow-up` will keep appearing as the framework matures. (Test: grep `[REVIEW].*A/B/C\|option.*[abc]\.` across all task files in `.tasks/{active,completed}/`. Pre-test estimate: ≥3 occurrences.)
- **A2:** The operator's pick is high-signal — knowing *which* option was chosen is essential context for the spawned task, distinct from a free-text rationale. (Backed by T-1776 evidence: the agent had to read commit messages 22 days later to infer option A was picked.)
- **A3:** A structured shape — whether `[CHOICE]` AC kind, Watchtower-form button-set, or convention-only — has zero schema-migration cost on existing tasks, since the existing `[REVIEW]` shape stays valid by default.
- **A4:** This is the structured-pick complement to T-2101's free-text feedback channel; both ship under the same Watchtower review form once the operator picks a direction here.

## Exploration Plan

Research artifact is the exploration substrate; this task is operator-dialogue-bound, not spike-bound. Per Inception Discipline rule 3 (don't write build artifacts before GO):

1. **Operator dialogue** (open) — operator picks among Candidates A/B/C/D in `docs/reports/T-2137-multi-option-ac-inception-spawn.md` §Scope question. Three open scope questions documented in the artifact (direction, spawn-type, retrofit).
2. **Sibling-task scan** (deferred until A1 contested) — if operator wants to validate A1's "recurring shape" claim, agent scans `.tasks/` for `[REVIEW]` ACs containing `A/B/C`, `option (A|B|C)`, or `pick (one|of)` patterns.
3. **Recommendation hardening** — once direction is picked, recommendation in this task body is updated from DEFER to GO|NO-GO|DEFER on the picked candidate, V-slices are NOT pre-filed (don't repeat T-2101 V1..V5 stalled-list anti-pattern).
4. **Spawn first build slice** — operator approves spawn, agent files one (1) build task for the picked candidate, parks the rest.

## Technical Constraints

- **CLI/Web parity required** (T-1259, T-1671 precedent — inception decide and arc close both refuse under `$CLAUDECODE=1`; spawn-from-choice must follow the same pattern).
- **Additive-only on existing tasks** — current `[REVIEW] Choose A/B/C` ACs must remain valid; this inception does not propose a forced migration.
- **AC-parser blast radius** — Candidate A (new `[CHOICE]` AC kind) touches `agents/task-create/update-task.sh` AC counter, `lib/inception.sh` strip-and-count helpers, P-010 completion gate, the reviewer agent's static scan (`agents/audit/reviewer/static_scan.py`), and Watchtower's review-surface rendering. Operator should weigh that before picking A.
- **Backwards compatibility with T-2101** — the chosen shape must coexist cleanly with T-2101's `--feedback` flag once T-2101 V-slices ship; both fields land in the same Watchtower form.

## Scope Fence

**IN scope (this inception):**
- Decide whether the framework should support a structured multi-option-AC → spawn pattern
- If yes: pick one of Candidates A/B/C/D from the research artifact
- Answer the three open scope questions (direction, spawn-type, retrofit) before any build slice is filed
- Sibling parity with T-2101 (free-text feedback) — both should land in the same Watchtower form

**OUT of scope (handle elsewhere):**
- T-2101 V1..V5 build slices (already-GO'd separately; user explicitly DEFERRED them in this turn's AskUserQuestion)
- arc-008 Q1/Q2/Q3 (template philosophy, frictionless instructions, reviewer pre-flight — separate inceptions in arc-008)
- Retro-fitting historical `[REVIEW] Choose A/B/C` ACs (decide retro after GO; do NOT retro-fit pre-emptively)
- Building any of the candidates before operator picks direction (Inception Discipline rule 3)

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

**GO if (per picked candidate):**
- Operator picks one of Candidates A/B/C (A=`[CHOICE]` AC kind, B=Watchtower form, C=convention-only)
- Spawn-type (always-inception vs sometimes-build) is decided
- Retrofit policy is decided (new-only vs all)
- First build slice for the picked candidate is ready to file as a sibling task — not pre-filed before the decision

**NO-GO if:**
- Operator picks Candidate D (status quo) — close-by-event pattern is considered acceptable
- T-2055 (CTL-029 detector) is judged sufficient to catch the symptom without addressing the cause
- Existing T-2101 free-text channel is considered sufficient for the multi-option case too (operator picks via prose, agent files spawn manually)

**DEFER if:**
- Operator wants T-2101 V-slices to ship first so the new pattern lands inside the already-decided Watchtower form
- Operator is unsure between Candidates A and B and wants a smaller spike before commitment

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

This inception captures a structural gap surfaced by T-1776's close: Human AC #H1 presented three options (A/B/C — TermLink primitive vs shell adapter vs change default.yaml) but the operator's choice was never structurally captured — it lived in chat, the build (T-1797) referenced T-1776 by commit text, and T-1776 sat completable-but-not-completed for 22 days (cleaned up under 625557f1+9f08aa42 this session). The pattern recurs: any AC asking 'pick A or B or C' is doing the work of an inception inside a checkbox. Filed under arc-008 (inception-review-loop) as a sibling to T-2101 (operator-feedback channel) and the listed Q1/Q2/Q3 questions. Recommendation is DEFER because the dialogue must validate the scope before any design space exploration — verbatim operator ask: 'we want an inline method to provide feedback for the review … in this case we just need to give an option a,b,c which actually should surface with an inception'.

**Evidence:**
- T-1776 22-day CTL-029 latency: filed 2026-05-09 (`703f3d34`), option A chosen + shipped via T-1797 (`df468c2f`) 3 days later, prevention via T-1798 (`cf480359`), parent finally closed 2026-05-31 (`625557f1` + `9f08aa42`). All four commits messages name T-1776; none of them ticked H1.
- Full research artifact: `docs/reports/T-2137-multi-option-ac-inception-spawn.md` (created before this body per Inception Discipline C-001) — contains the Dialogue Log with operator's verbatim ask, the four candidates A/B/C/D, and the three open scope questions.
- T-2101 sibling already-GO'd (2026-05-30T07:38:12Z) — `--feedback <text>` flag for free-text operator alterations; V-slices listed in the Recommendation never filed (`grep -lE "T-2101-V" .tasks/` returns empty).
- T-2055 (CTL-029 detector) — completable-but-not-completed catch class; the symptom-side gate this inception's structural fix would obsolete.
- L-262 (T-1443): *"Frictionless feedback UX is load-bearing for any system depending on a learning loop"*.
- L-016 (T-1324): *"Inception decide must tick its own authorizing Human AC"* — the canonical "decision must leave a structural mark" precedent.

**Operator action requested:** read the research artifact, pick one of Candidates A/B/C/D, answer the three open scope questions, then decide via Watchtower at `/inception/T-2137`. Recommendation in this task body will be re-written from DEFER to GO|NO-GO|DEFER on the picked candidate before the decision lands.

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

### 2026-05-31T10:29:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-31T10:29:51Z — status-update [task-update-agent]
- **Change:** tags: +inception-spawn
