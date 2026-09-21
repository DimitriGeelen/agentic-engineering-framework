---
id: T-3400
name: "AC re-baselining: no verb exists for a criterion whose premise is overtaken
  by events (OBS-432)"
description: >
  An acceptance criterion whose literal premise is overtaken by legitimate
  downstream work (a sibling task landing, a count changing) cannot be
  ticked honestly, edited without self-grading, or left unticked without
  stalling a finished task. P-010's checkbox model has no verb for this.
  Promoted from observation OBS-432 (concrete instance: T-3363 AC5).

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: [governance, ac-lifecycle, p-010]
components: []
related_tasks: [T-3363, T-3326]
created: 2026-09-21T14:17:53Z
last_update: 2026-09-21T15:04:40Z
date_finished: 2026-09-21T15:04:40Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-09-21T14:30:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=178,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-21T14:30:22Z'
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

# T-3400: AC re-baselining — no verb exists for a criterion whose premise is overtaken by events

**This is an inception/exploration task** — scoping a design gap, not building anything under this ID.

## Problem Statement

P-010 (the completion gate) counts AC checkboxes and treats each as a static
binary claim. It has no representation for an AC whose literal wording was
correct at filing time but has since been overtaken by legitimate downstream
work — a count that changed because a sibling task landed, not because
anything is wrong. Concrete instance (OBS-432, T-3363 AC5): the AC read "the
6 genuine reds from T-3362 (groups C/D/E/F) are still red after the fix."
Two of those groups' owning tasks (T-3364, T-3365) landed and moved to
`.tasks/completed/`, so the literal count is now wrong — 4 reds remain, not
6 — even though the property the AC exists to test (the isolation fixture
doesn't paper over real failures) is still fully demonstrated.

The agent that hits this has three bad options: (1) tick it, asserting a
now-false literal claim; (2) edit the AC wording, which is grading your own
work against a standard you just moved — T-3363's own Sovereign question
names this shape as improper; (3) leave it unticked forever, which stalls a
finished task and makes the board lie in the other direction. All three are
wrong. For: any agent that hits an AC anchored to a corpus count or a
sibling task's status (T-3326 names the same disease one level up —
verification anchored to mutable state rots). Why now: it's not
hypothetical — it happened this session (T-3363), and the agent had no move
that wasn't a bad one.

## Assumptions

- **A:** A structural verb (not agent discretion) can distinguish "premise
  expired through legitimate downstream work" from "agent wants an easier
  AC" — i.e. the re-baseline event is auditable and cannot be self-granted
  silently. Untested — this is the crux of whichever candidate shape wins.

## Open Questions

- **IW-1: Which candidate shape should the framework adopt — a re-baseline
  verb, or a SUPERSEDED-BY annotation, or something else?**
  confidence: 1
  disposition: deferred
  rationale: Two candidates are named in OBS-432 but neither is designed in
    detail: (a) a re-baseline verb (e.g. `fw task rebaseline-ac T-XXX N
    --reason "..."`) that records who authorised the wording change and why,
    making option 2 from the Problem Statement auditable instead of
    forbidden; (b) an AC annotation like `SUPERSEDED-BY: T-XXX` that P-010
    counts as satisfied-with-provenance without touching the original
    wording at all. (a) changes the claim; (b) leaves the claim intact and
    adds a pointer explaining why it no longer applies. Deferred to the
    Exploration Plan below — this needs a short spike comparing both against
    2-3 real corpus instances, not a decision from the problem statement
    alone.
- **IW-2: Who is authorized to invoke the re-baseline mechanism — only a
  human, or an agent with a sovereignty-rail-style audit trail?**
  confidence: 0
  disposition: deferred
  rationale: Not explored yet. Bears directly on Assumption A — if agents
    can self-invoke it, the audit trail (digest-keyed, human-override-blocks
    re-tick, mirroring the T-1985 reviewer auto-tick sovereignty rail) is
    what keeps it from becoming a laundered self-grading path.

## Exploration Plan

1. **Spike (1-2h):** prototype both candidate shapes (verb vs. annotation)
   against 2-3 real corpus instances of AC-premise drift — start with T-3363
   AC5 itself, then search for 1-2 more via `grep` over `.tasks/{active,
   completed}/*.md` for ACs referencing a sibling task ID or a literal count.
2. **Compare:** which shape is easier to audit, easier for a human to
   understand at a glance in Watchtower, and cheaper to implement against
   `agents/task-create/update-task.sh`'s existing P-010 checkbox-counting
   logic.
3. **Write recommendation** here with the chosen shape, or a third option if
   the spike surfaces one neither named originally.

## Technical Constraints

None — this is a task-file/governance-tooling change (Python/bash in
`agents/task-create/`), no browser/hardware/network constraints apply.

## Scope Fence

**IN scope:** designing the re-baseline mechanism itself (verb or
annotation), its audit trail, and how P-010 counts it.
**OUT of scope:** auditing the existing corpus for every instance of this
pattern (that's a follow-up sweep once the mechanism exists, not a
precondition for designing it); changing P-010's checkbox model for any
other reason than this specific gap.

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

**Recommendation:** GO — scope and design the re-baseline mechanism (spike
both candidate shapes per the Exploration Plan, then pick one).

**Rationale:** This isn't an evidence gap (DEFER would be a hedge here, not
a real disposition) — it's a scoping decision between two already-named
candidates, which is exactly what an inception exists to resolve. The gap is
real and demonstrated (T-3363 AC5 hit it this session, not hypothetically),
the fix is bounded (a task-file convention + a change to
`update-task.sh`'s checkbox-counting logic, not a redesign of P-010), and
leaving it unresolved means the next agent to hit this class faces the same
three bad options.

**Evidence:**
- T-3363 AC5, this session: literal AC text ("6 genuine reds") is stale
  because T-3364/T-3365 landed and moved 2 of the 6 groups to
  `.tasks/completed/`; the property under test is still demonstrated, the
  count is not.
- Sibling gap already named in the corpus: T-3326 ("verification anchored to
  mutable state rots") — same disease, one level up: there the anchor is a
  live corpus count, here it's a sibling task's status.
- Precedent for an auditable agent-adjacent mechanism already exists in this
  framework: the T-1985 reviewer auto-tick sovereignty rail (digest-keyed
  `auto_tick:<task>:<ac_index>:<digest>` entries, human-untick blocks
  re-tick) — whichever shape wins here should study that pattern rather than
  invent audit semantics from scratch.

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

**Rationale**: This isn't an evidence gap (DEFER would be a hedge here, not
a real disposition) — it's a scoping decision between two already-named
candidates, which is exactly what an inception exists to resolve. The gap is
real and demonstrated (T-3363 AC5 hit it this session, not hypothetically),
the fix is bounded (a task-file convention + a change to
`update-task.sh`'s checkbox-counting logic, not a redesign of P-010), and
leaving it unresolved means the next agent to hit this class faces the same
three bad options.

**Date**: 2026-09-21T15:04:39Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-09-21T15:04:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** This isn't an evidence gap (DEFER would be a hedge here, not
a real disposition) — it's a scoping decision between two already-named
candidates, which is exactly what an inception exists to resolve. The gap is
real and demonstrated (T-3363 AC5 hit it this session, not hypothetically),
the fix is bounded (a task-file convention + a change to
`update-task.sh`'s checkbox-counting logic, not a redesign of P-010), and
leaving it unresolved means the next agent to hit this class faces the same
three bad options.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b5313643
- **Timestamp:** 2026-09-21T15:04:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-5e8a6564
- **Timestamp:** 2026-09-21T15:04:41Z
- **Overall:** CONFIRMED
- **Claims:** 5

| Claim | Type | Status |
|-------|------|--------|
| `T-3363` | task | ✓ pass |
| `T-3364` | task | ✓ pass |
| `T-3365` | task | ✓ pass |
| `T-3326` | task | ✓ pass |
| `T-1985` | task | ✓ pass |

### 2026-09-21T15:04:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
