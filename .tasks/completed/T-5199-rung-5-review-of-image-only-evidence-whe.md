---
id: T-5199
name: "Rung-5 review of image-only evidence: when only one seat kind can read images,
  the panel is always incomplete and escalates to the operator even after a vision-capable
  green (832 field report, be.54)"
description: >
  Inception: Rung-5 review of image-only evidence: when only one seat kind can read
  images, the panel is always incomplete and escalates to the operator even after
  a vision-capable green (832 field report, be.54)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-11-17T08:44:57Z
last_update: 2026-11-17T16:04:08Z
date_finished: 2026-11-17T16:04:08Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-11-17T15:05:22Z'
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
  - ts: '2026-11-17T15:15:24Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=131,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5199: Rung-5 review of image-only evidence: when only one seat kind can read images, the panel is always incomplete and escalates to the operator even after a vision-capable green (832 field report, be.54)

## Problem Statement

832 reported on be.54 that high-impact (rung-5) criteria whose evidence is an image never close through the reviewer panel. One vision-capable seat returns green, the other seats cannot read the image and return not-evaluated, and the ledger needs at least 2 evaluating green seats from distinct vendors (MIN_EVALUATING_SEATS, lib/verdict_ledger.py:205). So the result escalates to the operator every time, even when the only seat that could look says green. Research: docs/reports/T-5199-image-only-rung5-evidence.md.

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

- **IW-1: Is "two independent vendors must see it" still the right bar when only one vendor on a host can see images?**
  confidence: 3
  disposition: answered
  rationale: Yes. Operator, 2026-11-17: "Proceed as suggested". Image-only criteria are the hardest to check, so one seat's eyes are not enough (research artifact, Candidate C rejected).
- **IW-2: Is 832's case really "only one vision kind exists", or is it the planner seating blind kinds on image evidence that is not a page (the vision gate in lib/reviewer/judge_cli.py:1330 only fires for render/page criteria)?**
  confidence: 2
  disposition: answered
  rationale: Both apply. The judge excludes kinds declared `vision: false` only for render/page criteria (judge_cli.py:1326-1336), and undeclared kinds never. 832's host fields one vision kind (their message 4c8a10a0, run-t-893-d519ae5e7a). The build widens the exclusion to any criterion whose evidence is images, and to unknown kinds.
- **IW-3: When the bar cannot be met on a host, what should happen: escalate as today, close at a lower rung with a STEP-DOWN note, or something else?**
  confidence: 3
  disposition: answered
  rationale: Escalate as today, but the refusal names how many vision kinds the host has and how to add one (`fw reviewer probe-vision`). Operator chose (a), 2026-11-17.

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

**Recommendation:** GO (candidates A + B; C and D rejected)

**Rationale:**

Keep the two-vendor bar for image evidence. Fix what is actually wrong: the planner still seats reviewers that cannot read images when a criterion's evidence is an image but not a page, and it never excludes kinds whose vision is undeclared. When a host cannot field two vision vendors, the criterion keeps escalating to the operator, but the refusal says how many vision kinds the host has and how to add one. The operator agreed on 2026-11-17 ("Proceed as suggested" to yes / yes / (a)).

**Evidence:**

- `MIN_EVALUATING_SEATS = 2` at lib/verdict_ledger.py:205; a `not-evaluated` seat neither blocks nor counts (lines 3580-3650).
- The vision exclusion fires only for render/page criteria, and only for `vision: false` (lib/reviewer/judge_cli.py:1326-1336).
- Vision kinds on AEF's host are claude, codex and antigravity (policy/review-backends.yaml), so a full vision panel is possible here.
- 832's host fields one vision kind (sidecar 4c8a10a0; their T-893 AC1, run-t-893-d519ae5e7a).
- Research: docs/reports/T-5199-image-only-rung5-evidence.md

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

**Rationale**: Keep the two-vendor bar for image evidence. Fix what is actually wrong: the planner still seats reviewers that cannot read images when a criterion's evidence is an image but not a page, and it never excludes kinds whose vision is undeclared. When a host cannot field two vision vendors, the criterion keeps escalating to the operator, but the refusal says how many vision kinds the host has and how to add one. The operator agreed on 2026-11-17 ("Proceed as suggested" to yes / yes / (a)).

**Date**: 2026-11-17T16:04:08Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-17T08:45:22Z — status-update [task-update-agent]
- **Change:** horizon: now → next

### 2026-11-17T15:05:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-11-17T16:04:08Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Keep the two-vendor bar for image evidence. Fix what is actually wrong: the planner still seats reviewers that cannot read images when a criterion's evidence is an image but not a page, and it never excludes kinds whose vision is undeclared. When a host cannot field two vision vendors, the criterion keeps escalating to the operator, but the refusal says how many vision kinds the host has and how to add one. The operator agreed on 2026-11-17 ("Proceed as suggested" to yes / yes / (a)).

### 2026-11-17T16:04:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e3fa94e2
- **Timestamp:** 2026-11-17T16:04:10Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Scope:** static anti-pattern scan; PASS means no anti-pattern was found, not that the criteria hold
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-51f4e851
- **Timestamp:** 2026-11-17T16:04:10Z
- **Overall:** CONFIRMED
- **Claims:** 1

| Claim | Type | Status |
|-------|------|--------|
| `T-893` | task | ✓ pass |
