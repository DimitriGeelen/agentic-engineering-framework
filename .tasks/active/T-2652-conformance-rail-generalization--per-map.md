---
id: T-2652
name: "Conformance rail generalization — per-map canonical sources for the 4 unrailed
  corpus maps"
description: >
  Inception: Conformance rail generalization — per-map canonical sources for the 4
  unrailed corpus maps

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-28T09:30:51Z
last_update: 2026-07-28T09:32:37Z
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
  - ts: '2026-07-28T09:32:38Z'
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

# T-2652: Conformance rail generalization — per-map canonical sources for the 4 unrailed corpus maps

## Problem Statement

T-2621 shipped the first map-conformance rail (aef-task-lifecycle vs
status-transitions.yaml, green in daily audit). The other four corpus maps
(aef-inception-flow, aef-session-lifecycle, aef-dispatch-loop, aef-audit-cron)
are stuck at transitional-subordinate authority stage solely because no rail
exists for them — and the T-2621 checker cannot serve them: it is hard-wired to
one canonical source that fits only one map. This inception answers: what does
each remaining map conform against, how does the checker generalize, and which
maps should not seek a rail at all. For: the T-2619 cascading-detail program
(maps hold detail, CLAUDE.md thins to principles). Why now: T-2621's Evolution
log explicitly deferred the generalization; the rail is the critical path for
4/5 maps.

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

- **IW-1: Where does the conforms-against declaration live — in the map (aef:meta on the process element), a framework-side registry (map_id → extractor+source), or both?**
  confidence: 1
  disposition: open
  rationale: registry needs zero schema change; in-map pointer is designer-visible and travels with bytes — 832's schema view needed before choosing

- **IW-2: One generic checker with per-source extractors, or per-map bespoke checkers?**
  confidence: 1
  disposition: open
  rationale: T-2621's carrier-collapse fits only "states + transition table" shapes; source inventory will show whether the other machines share that shape

- **IW-3: Which of the 4 maps have a real enforced machine worth conforming against — and which are genuinely descriptive (rail would be theater)?**
  confidence: 0
  disposition: open
  rationale: a green rail against advisory prose implies authority the code doesn't back; per-map enforcement test pending

- **IW-4: What is the carrier convention for non-task-status states (decision outcomes, budget levels) — namespace the existing aef:meta state= attribute, a new attribute, or per-extractor interpretation?**
  confidence: 1
  disposition: open
  rationale: inception map already carries state=go/state=closed which the current checker would misread as task statuses if pointed at it

## Exploration Plan

1. **Source inventory (this session, ~30 min):** for each of the 4 maps, read
   the map via `fw corpus explain` + the enforcement code its notes reference;
   fill the per-map table in docs/reports/T-2652 (candidate source, enforced
   where, shape fit).
2. **832 schema dialogue (rail, async):** post IW-1/IW-4 to the DM rail —
   whether the designer schema should carry a conforms-against pointer and how
   non-status states should be annotated is their contract surface.
3. **Synthesis:** dispose IWs, write GO/NO-GO recommendation with per-map
   verdicts (rail / no-rail-by-design) and slice list if GO.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** design decision only — per-map canonical sources, checker
generalization shape, carrier convention for non-status states, which maps get
rails. Research artifact + rail dialogue with 832.
**OUT:** building any rail (build children post-GO); the T-2619 graduation
decision itself (operator-owned, per-map, after its rail is green); any map
edits (pair-draft rounds are their own ritual); 832-side schema
implementation.

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
- ≥2 of the 4 maps have a demonstrably enforced canonical source (code-backed,
  not advisory prose) whose comparison is mechanically extractable
- A single generalization shape (registry or in-map pointer + extractor
  contract) covers all rail-worthy maps without forking the designer schema
  unilaterally

**NO-GO if:**
- Source inventory shows the other maps' machines are advisory prose or
  scattered enforcement with no stable canonical artifact (rail would be
  theater — keep descriptive-only stage honestly)
- Generalization requires an 832-side schema change they decline or that
  breaks round-trip compatibility with the pinned designer version

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

Filing-time stub: evidence gathering starts now (source inventory per map + design dialogue with 832 on a machine-readable conforms-against pointer); recommendation will be replaced with GO/NO-GO before operator handoff.

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-28T09:32:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
