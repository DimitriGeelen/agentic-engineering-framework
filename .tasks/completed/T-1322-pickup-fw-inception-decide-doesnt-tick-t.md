---
id: T-1322
name: "Pickup: fw inception decide doesnt tick the RUBBER-STAMP Record go/no-go decision
  Human AC — tasks stay in active/ forever (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1130. Type: bug-report.

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-18T22:23:27Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-18T22:51:42Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
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
---

# T-1322: Pickup: fw inception decide doesnt tick the RUBBER-STAMP Record go/no-go decision Human AC — tasks stay in active/ forever (from termlink)

## Problem Statement

When `fw inception decide T-XXX go|no-go` records a decision, it appends a Decision block + an Updates entry, and may set `status=work-completed`. But the corresponding `### Human` AC (typically `- [ ] [RUBBER-STAMP] Record go/no-go decision`) remains unchecked. Per the Human-AC rule (T-372/T-373), unchecked Human ACs keep tasks in `.tasks/active/` — so inception tasks are structurally stuck in "partial-complete" despite their sole human AC being literally satisfied by the same command that just succeeded.

Termlink reports 10 inception tasks (T-947 through T-959) stuck this way after `decide` was recorded. This is a direct contributor to G-008 ("64 tasks stuck in partial-complete").

Source: termlink T-1130 pickup (P-039).

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

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
- [x] Problem statement validated (lib/inception.sh do_inception_decide writes Decision block but doesn't tick the [RUBBER-STAMP] human AC)
- [x] Assumptions tested (template default human AC for inception tasks is "[ ] [REVIEW] Review exploration findings and approve go/no-go decision")
- [x] Recommendation written with rationale (GO — surgical edit; build deferred to next session due to edge cases + budget pressure)

### Human
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

## Recommendation

**Recommendation:** GO

**Rationale:** Concrete bug with structural consequence — `decide` is the action the AC describes, so leaving the box unchecked is incoherent. Termlink shows the impact (10+ tasks stuck, contributing to G-008). Fix is surgical: in `do_inception_decide`, after writing the Decision block, scan the `### Human` section for an AC whose text matches `[RUBBER-STAMP].*decision` or `[REVIEW].*go/no-go decision`, and tick it. Idempotent — already-checked boxes are unchanged. **Build deferred to next session** — context budget at 78% in this session, and the fix has edge cases (matching the right AC text, not over-matching, handling multiple Human ACs) that benefit from fresh attention.

**Evidence:**
- `lib/inception.sh:do_inception_decide` writes Decision block + status update but never modifies the Acceptance Criteria section
- Default inception template ships with `[ ] [REVIEW] Review exploration findings and approve go/no-go decision` as the human AC
- Termlink reports 10 stuck tasks (T-947 through T-959)
- G-008 ("64 tasks stuck in partial-complete") is the structural symptom of this missed tick
- Risk near zero — only ticks the box if it matches the predicate; idempotent

**Build plan (T-1324, next session):**
1. After Decision block write, locate `### Human` section in the task file
2. Find unchecked ACs matching `[RUBBER-STAMP].*[Rr]ecord.*decision` OR `[REVIEW].*go/no-go decision`
3. Replace `- [ ]` with `- [x]` for matched lines (line-level, idempotent)
4. Re-run the work-completed gate so the task auto-finalizes if all other ACs pass
5. Bats regression: create inception task with template, run `decide go`, verify AC ticked + task moved to completed/

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

**Rationale**: Recommendation: GO

Rationale: Concrete bug with structural consequence — `decide` is the action the AC describes, so leaving the box unchecked is incoherent. Termlink shows the impact (10+ tasks stuck, contributing to G-008). Fix is surgical: in `do_inception_decide`, after writing the Decision block, scan the `### Human` section for an AC whose text matches `[RUBBER-STAMP].decision` or `[REVIEW].go/no-go decision`, and tick it. Idempotent — already-checked boxes are unchanged. Build deferred to next session — context budget at 78% in this session, and the fix has edge cases (matching the right AC text, not over-matching, handling multiple Human ACs) that benefit from fresh attention.

Evidence:
- `lib/inception.sh:do_inception_decide` writes Decision block + status update but never modifies the Acceptance Criteria section
- Default inception template ships with `[ ] [REVIEW] Review exploration findings and approve go/no-go decision` as the human AC
- Termlink reports 10 stuck tasks (T-947 through T-959)
- G-008 ("64 tasks stuck in partial-complete") is the structural symptom of this missed tick
- Risk near zero — only ticks the box if it matches the predicate; idempotent

Build plan (T-1324, next session):
1. After Decision block write, locate `### Human` section in the task file
2. Find unchecked ACs matching `[RUBBER-STAMP].[Rr]ecord.decision` OR `[REVIEW].go/no-go decision`
3. Replace `- [ ]` with `- [x]` for matched lines (line-level, idempotent)
4. Re-run the work-completed gate so the task auto-finalizes if all other ACs pass
5. Bats regression: create inception task with template, run `decide go`, verify AC ticked + task moved to completed/

**Date**: 2026-04-18T22:51:42Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T22:31:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:51:42Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: Concrete bug with structural consequence — `decide` is the action the AC describes, so leaving the box unchecked is incoherent. Termlink shows the impact (10+ tasks stuck, contributing to G-008). Fix is surgical: in `do_inception_decide`, after writing the Decision block, scan the `### Human` section for an AC whose text matches `[RUBBER-STAMP].decision` or `[REVIEW].go/no-go decision`, and tick it. Idempotent — already-checked boxes are unchanged. Build deferred to next session — context budget at 78% in this session, and the fix has edge cases (matching the right AC text, not over-matching, handling multiple Human ACs) that benefit from fresh attention.

Evidence:
- `lib/inception.sh:do_inception_decide` writes Decision block + status update but never modifies the Acceptance Criteria section
- Default inception template ships with `[ ] [REVIEW] Review exploration findings and approve go/no-go decision` as the human AC
- Termlink reports 10 stuck tasks (T-947 through T-959)
- G-008 ("64 tasks stuck in partial-complete") is the structural symptom of this missed tick
- Risk near zero — only ticks the box if it matches the predicate; idempotent

Build plan (T-1324, next session):
1. After Decision block write, locate `### Human` section in the task file
2. Find unchecked ACs matching `[RUBBER-STAMP].[Rr]ecord.decision` OR `[REVIEW].go/no-go decision`
3. Replace `- [ ]` with `- [x]` for matched lines (line-level, idempotent)
4. Re-run the work-completed gate so the task auto-finalizes if all other ACs pass
5. Bats regression: create inception task with template, run `decide go`, verify AC ticked + task moved to completed/

### 2026-04-18T22:51:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bc42c7de
- **Timestamp:** 2026-06-02T14:56:41Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Problem statement validated (lib/inception.sh do_inception_decide writes Decision block but doesn't tick the [RUBBER-STAMP] human AC)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/inception.sh in: Problem statement validated (lib/inception.sh do_inception_decide writes Decision block but doesn't tick the [RUBBER-STAMP] human AC)`
