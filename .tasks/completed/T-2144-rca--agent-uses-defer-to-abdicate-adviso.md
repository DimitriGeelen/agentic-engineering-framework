---
id: T-2144
name: "RCA — agent uses DEFER to abdicate advisory duty when evidence is complete
  (T-2143 meta-failure, T-679 same family)"
description: >
  Inception: RCA — agent uses DEFER to abdicate advisory duty when evidence is complete
  (T-2143 meta-failure, T-679 same family)

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [arc-008, rca, advisory-model, defer-as-hedge, inception]
components: []
related_tasks: [T-2143, T-2139, T-2138, T-679, T-1878, T-1947]
arc_id: inception-review-loop
created: 2026-05-31T15:50:04Z
last_update: 2026-05-31T17:09:34Z
date_finished: 2026-05-31T17:09:34Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-31T15:50:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-31T16:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2144: RCA — agent uses DEFER to abdicate advisory duty when evidence is complete (T-2143 meta-failure, T-679 same family)

## Problem Statement

I filed T-2143 (the routing-recursion RCA inception) with `Recommendation: DEFER` despite having a complete research artifact (5-Whys, 4-candidate matrix with effort/coverage analysis, dialogue log, bigger-picture mapping). Operator caught it in one question — *"why do you reccomed defer ??"* — and the real recommendation (GO Candidate D) surfaced in chat within ~3 paragraphs. The on-disk advisory and the in-chat advisory diverged.

This is a **second-layer recursion of T-679** (origin: agent leaves blank decision for human to fill). T-679 = blank decision. T-2144 = decision-shaped placeholder that *looks* like a recommendation but isn't.

The hedge phrase that gave it away: *"The structural decision is an operator call, not an agent call."* Wrong. The decision is the operator's; **the recommendation is the agent's**. Conflating the two is the failure mode the advisory model exists to prevent.

**For whom:** the agent author of any inception task. **Why now:** operator caught the recursion in real time, immediately following T-2143's filing, and asked for a structural RCA + remediation + bigger-picture fit.

**Full evidence + 5-Whys + candidates:** `docs/reports/T-2144-defer-as-hedge-rca.md`.

## Assumptions

1. T-2143's DEFER recommendation was a hedge, not a knowledge gap. (Tested — the real recommendation surfaced in chat in ~3 paragraphs from materials already on disk, no new evidence needed.)
2. T-679 and T-2144 are the same family of failure at different layers. (Working hypothesis — T-679 = blank decision; T-2144 = decision-shaped placeholder. Both violate "you are the advisory.")
3. The framework has no detector reading `Recommendation:` field state alongside evidence indicators. (Verified — placeholder detector catches missing text, not "rationale present but recommendation hedged.")
4. DEFER-as-hedge is structurally identifiable from task body shape (workflow_type=inception, Recommendation=DEFER, evidence artifact present, candidates section populated, dialogue log present). (Working hypothesis — would be the static-scan pattern shipped under leg B.)
5. T-2143 and T-2144 share the structural pattern "agent emits token that passes structural validation while semantic content fails advisory model." (Working hypothesis — supports the bigger-picture mapping in the research artifact.)

## Exploration Plan

1. **Evidence walk** — DONE in research artifact. T-2143's filed Recommendation quoted verbatim; the in-chat recommendation that surfaced under operator pushback also quoted.
2. **5-Whys to root cause** — DONE. Bottoms out at: confidence-calibration failure overriding the advisory rule because the cost of confident-wrong feels asymmetric to hedged-correct.
3. **Bigger-picture mapping** — DONE. T-2144 is the 6th class in `inception-review-loop` arc, sibling to T-2143. Three-layer ladder: link-construction (T-2030 etc.) → AC routing (T-2143) → advisory recommendation (T-2144). All three share the "structurally valid token, semantically empty content" pattern.
4. **Candidate generation** — DONE. A (revise T-2143's recommendation in place), B (reviewer static-scan for `defer-as-hedge`), C (CLAUDE.md anti-pattern paragraph), D (combo).
5. **Spike (if operator picks B or D)** — corpus walk: grep `.tasks/completed/T-*-inception-*.md` and `.tasks/active/` for `Recommendation:** DEFER` combined with evidence artifacts. Would size the class and surface override candidates.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN scope:**
- RCA artifact (root cause + 5-Whys + bigger-picture context as T-2143 sibling).
- Three-leg remediation candidate D with explicit leg-by-leg rationale.
- Inception decision (GO/NO-GO).

**OUT of scope (would be child tasks if GO):**
- Actually revising T-2143's Recommendation on disk (leg A — child task).
- Actually shipping the `defer-as-hedge` reviewer rule (leg B — child task, possible sibling of T-2140's V2 catalogue work).
- Actually editing CLAUDE.md §Presenting Work for Human Review (leg C — child task, possible sibling of T-2141's V3 doc sweep).
- Corpus walk for past DEFER-as-hedge incidents (leg B's spike, if operator picks B or D).

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

**GO if:**
- Operator agrees T-2143's DEFER was a hedge (not a genuine evidence gap) AND picks at least leg A (revise T-2143's recommendation in place).
- Operator picks Candidate D (A + B + C combo) — full closure, mirrors T-2138's GO shape.
- Operator picks any non-empty subset of {A, B, C} — partial closure with explicit acknowledgement of which leak remains.

**NO-GO if:**
- Operator judges T-2144 over-engineering: the class might be a one-off (only 2 documented incidents: T-679 + this one). Acceptable position; T-2143 remediation alone may cover enough of the surface.
- Operator prefers to keep DEFER's current latitude and address each instance via direct chat pushback (no structural rail). The advisory model holds via human review only.

**No DEFER option here.** Filing T-2144 with DEFER would be the same antipattern this inception names. The evidence is complete: research artifact written, three legs identified, effort estimated, bigger-picture mapped. Either GO with a subset, or NO-GO. The agent recommends GO Candidate D.

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

**Recommendation:** GO — Candidate D (A + B + C combo).

**Rationale:**

T-2144 names a second-layer recursion of T-679 (blank-decision pattern): T-679 = agent leaves decision blank; T-2144 = agent fills with DEFER-as-hedge that *looks* like a recommendation. Both violate "you are the advisory" but at different surfaces. The class is now documented at 2 incidents (T-679 + this) which by `inception-review-loop` arc precedent (T-1878, T-1947, T-2138 each shipped at 1-2 incidents) warrants a structural rail.

Three-leg remediation matches the proven shape of T-2138's GO (Candidate E + B + Q3-both) and T-2143's proposed Candidate D:

- **Leg A — Revise T-2143's Recommendation in place.** Edit T-2143 to state GO Candidate D with the leg-by-leg rationale already surfaced in chat. ~5 min. Closes the **current** symptom — operator currently looking at /inception/T-2143 with a hedge as the recommendation; leaving it inconsistent with what I told you in chat is operational rudeness.

- **Leg B — Add `defer-as-hedge` reviewer detector.** Pattern: workflow_type=inception AND `Recommendation:** DEFER` AND research artifact reference present AND artifact contains (5-Whys OR ≥3-candidate matrix OR dialogue log) AND `Rationale:` length >300 chars → CONCERN. ~2-3h with bats fixtures + override entries for corpus. Possible co-shipment with T-2140's V2 catalogue work. Closes the **next** incident — T-679 + T-2144 = 2 documented rounds; without B the next inception is one confidence-wobble from a hedge.

- **Leg C — Extend CLAUDE.md §Presenting Work for Human Review.** Add explicit anti-pattern paragraph distinguishing DEFER-as-no-evidence (legitimate) from DEFER-as-hedge (failure mode). ~30 min. Closes the **author-time** awareness gap — B catches at scan-time, C teaches at write-time, mirrors T-1878 + T-1947 pattern.

Why D over A alone: A is local-fix; the class is now structurally documented, treating it as one-off bets it won't recur. Why D over NO-GO: NO-GO leaves the routing class undocumented and unfenced; the recursion's existence is itself evidence the class isn't self-correcting via agent discipline.

**Evidence:**

- Research artifact: `docs/reports/T-2144-defer-as-hedge-rca.md` (full 5-Whys, T-679 family analysis, leg-by-leg rationale, dialogue log).
- T-2143 commit chain: `d182f3f0` (the inception filing with DEFER — the in-disk symptom). The in-chat correction surfaced when operator asked "why do you reccomed defer ??".
- T-679 origin documented in CLAUDE.md §Presenting Work for Human Review (the rule that says "always tell them what you recommend and why" — exactly the rule I violated).
- Parent arc: `.context/arcs/inception-review-loop.yaml` — T-2144 is the 6th class added to the arc, sibling to T-2143.
- Related routing/advisory tasks: T-1878 (`docs/reports/T-1878-routing-default-bias.md`), T-1947 (reviewer prose-mismatch detector), T-1811 (three-prefix table).

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

**Rationale**: T-2144 names a second-layer recursion of T-679 (blank-decision pattern): T-679 = agent leaves decision blank; T-2144 = agent fills with DEFER-as-hedge that *looks* like a recommendation. Both violate "you are the advisory" but at different surfaces. The class is now documented at 2 incidents (T-679 + this) which by `inception-review-loop` arc precedent (T-1878, T-1947, T-2138 each shipped at 1-2 incidents) warrants a structural rail.

Three-leg remediation matches the proven shape of T-2138's GO (Candidate E + B + Q3-both) and T-2143's proposed Candidate D:

**Date**: 2026-05-31T17:09:34Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-31T15:50:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-31T17:09:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** T-2144 names a second-layer recursion of T-679 (blank-decision pattern): T-679 = agent leaves decision blank; T-2144 = agent fills with DEFER-as-hedge that *looks* like a recommendation. Both violate "you are the advisory" but at different surfaces. The class is now documented at 2 incidents (T-679 + this) which by `inception-review-loop` arc precedent (T-1878, T-1947, T-2138 each shipped at 1-2 incidents) warrants a structural rail.

Three-leg remediation matches the proven shape of T-2138's GO (Candidate E + B + Q3-both) and T-2143's proposed Candidate D:

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b01c55ab
- **Timestamp:** 2026-05-31T17:09:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-31T17:09:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
