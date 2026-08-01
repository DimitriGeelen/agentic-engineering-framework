---
id: T-2715
name: "first-run experience: why four green install surfaces missed a blocked user"
description: >
  Inception: first-run experience: why four green install surfaces missed a blocked
  user

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-01T10:01:22Z
last_update: '2026-08-01T10:15:06Z'
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
  - ts: '2026-08-01T10:03:36Z'
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
  - ts: '2026-08-01T10:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2715: first-run experience: why four green install surfaces missed a blocked user

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

Full context, findings and dialogue log: `docs/reports/T-2715-first-run-experience.md`.

- **IW-1: What isolation mechanism gives a genuinely fresh machine per run?**
  confidence: 3
  disposition: answered
  rationale: D-1 — two tiers, Docker (fast loop) + VirtualBox (release gate); host verified 2026-08-01 (Docker 29.6.2, VBox 7.0.16 with vboxdrv loaded alongside kvm_amd, /dev/kvm present)

- **IW-2: Which install path do we exercise — greenfield only, or also upgrade of a legacy vendored consumer?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — BOTH, greenfield first (prove the harness on the cheap path, then add the legacy-consumer upgrade that actually blocked Mehdi); needs a fixture consumer frozen pre-T-2232

- **IW-3: Does the worker self-heal, or halt on first error?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — BOTH modes, HEAL-first (agent had leaned halt-first and was wrong: with rigorous repair capture, heal walks the whole chain and surfaces every defect in one run, while halt stops at the first; halt's virtue is unambiguous attribution, which matters when confirming fixes, not when finding bugs). Metric is repair count, not pass/fail (F-3)

- **IW-4: What is the pass oracle, given doctor cannot judge itself?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — BEHAVIOURAL verdict decides (first governed commit exists AND gate demonstrably refuses an ungoverned edit), doctor captured ADVISORY-only alongside. Stronger than the agent's proposal: doctor disagreeing with observed reality becomes a finding rather than a silent pass. Fails correctly in the T-2709 case (hooks resolving to nothing while doctor reported "25 hooks, all portable")

- **IW-5: Is fix-the-installer and improve-the-prompt one arc or two?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — THREE arcs: (A) harness + installer correctness, (B) README prompt quality, (C) onboarding scenario redesign. Each needs its own G-062 headline mechanic and demo artefact; agent had leaned one/two, operator took the cleanest closure criteria over lowest ceremony

- **IW-6: What is the run budget, serial or parallel?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — 1 run per configuration first (4 runs: 2 paths × 2 modes), then scale on what the findings show. Rationale: the first round will hit reproduce-every-time defects, and statistical power buys nothing until we know whether failures are deterministic or variable

- **IW-7: Who answers the prompt's `[ASK]` points in an unattended run?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — SCRIPTED RESPONDER with the answering policy as an explicit test variable (always-yes / wrong-directory-name / clarifying-question-back). Keeps runs unattended while making [ASK] behaviour measured rather than bypassed. Rejected auto-confirm specifically because STEP 2's [ASK] guards a piped installer and waving it through trains the harness to treat a safety gate as noise

- **IW-8: Which ref does the worker install from — public GitHub mirror or local master?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — PUBLIC MIRROR always (user's actual reality, staleness included); local master available as a manual debug override for fix-confirmation but never a test configuration, keeping the matrix at 4. Each run MUST record the mirror-served SHA so propagation lag (T-1594) is distinguishable from regression

- **IW-9: When a run surfaces a bug, does this arc fix it or file it?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — FILE AND CONTINUE. Every finding becomes its own task with ACs, RCA and regression test, homed to whichever of the three arcs owns it. Keeps the harness arc fenced at "build the instrument, produce the diagnosis" so it can actually close. Evidence: today's four defects each got their own task/RCA, which is the only reason T-2711 was recognisable as a THIRD instance of its shape

- **IW-10: What ends the arc — N consecutive clean runs, or a fixed run count?**
  confidence: 2
  disposition: answered
  rationale: operator 2026-08-01 — NEITHER. Use the BVP mechanism: work arc A until all HV/HC and HV/LC tasks are complete, then move to arc B, then C. Requires arc-scoped value drivers created UPFRONT (operator acknowledged). Enables incremental delivery + learn/iterate between arcs. See D-5. Residual: this is a PROGRESS criterion — G-062 still requires the headline mechanic to fire with a demo artefact (IW-18), and the HV set grows under file-and-continue (IW-19)

- **IW-18: Does HV-complete substitute for, or compose with, the G-062 headline-mechanic demo?**
  confidence: 2
  disposition:
  rationale: completing every HV task could be entirely substrate; §ACD names substrate-vs-deliverable conflation as the failure. Agent position: they COMPOSE — HV-complete says when to close, the demo says what proves it

- **IW-19: Under file-and-continue, is "all HV complete" measured against the task set at arc start, or as it evolves?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — EVOLVING, bounded by QUADRANT not by snapshot. Every newly discovered task/bug is BVP-estimated on arc assignment; HV/HC or HV/LC → in scope for this arc, anything else → does not gate closure. Arc-next stepping (BVP-ordered) manages the remainder. Intent: important bugs and high-value features get executed, low-value discovery never blocks. Coherent with IW-3: heal mode walks the whole chain per run, so HV-dryness is meaningful rather than an artifact of stopping at defect one. **Derived requirement (see IW-21): the estimation must be WIRED IN at arc-assignment time, not left to discipline**

- **IW-21: How is BVP estimation wired in at arc-assignment time?**
  confidence: 1
  disposition: RESOLVED — recalc-then-pick primitive + exit-workflow recalc gate (operator 2026-08-01)
  rationale: operator named this the key challenge for D-5/IW-19. **Premise corrected during the grill** (agent had it wrong twice): (a) the estimator IS already arc-aware — T-2357 `_arc_scoped_drivers_for_task()` at estimator.py:125 resolves `arc_id:` → arc YAML → APPROVED `scoped_drivers:`, proposed ones deliberately do not fire; (b) re-estimation DOES exist — the `bvp-estimator-sweep-15m` cron (T-1923) is deployed at `/etc/cron.d/agentic-audit-999-*` and live (fired 21:00 on 2026-08-01). Agent's first check used `crontab -l` — WRONG OBJECT, reported clean, nearly filed a false drift finding. Same defect class as the whole inception.
    The REAL gap is narrower: the sweep's trigger is AGE (>24h `_proposed_is_stale`), not arc assignment. Assign a task to an arc while its score is fresh and the sweep skips it — arc-scoped scoring arrives up to a day late, and the quadrant IS the scope decision. Second hole: `if fm.get("bvp_scores"): continue` means a human-CONFIRMED task moved between arcs never re-scores. Third: `rubric_sha` is the sha of the rubric FILE, module-cached, identical for every task — so nothing records WHICH drivers a proposal was computed against, i.e. there is no stored evidence of arc drift to detect.
    **Operator mechanism (adopted, supersedes all four agent-proposed trigger seams):** recompute at the DECISION POINT rather than watching for write events. Path-agnostic by construction — indifferent to whether `arc_id` was set by hook, by `fw arc tag`, or by hand-editing frontmatter, because it compares state instead of subscribing to events. Three parts:
    1. **`recalc-then-pick` primitive** — on agent completion of any arc task: recalc all arc tasks (arc-scoped drivers included), then pick next HV/HC or HV/LC. Empty result IS the exit condition; no separate close-readiness heuristic, no polling. Subsumes the `/resume` recalc (session start is just another "what's next in this arc?"). Gap named: fires only on AGENT completion — human-closed last task or tasks re-scoped out of the arc trigger nothing, so `fw arc close` must re-run the same check as backstop (15-min sweep optional).
    2. **Exit workflow is a GATE, not a formality** — step 1 recalc, step 2 check quadrants; any task in HV/HC or HV/LC → RETURN TO ARC, do not close. Re-entrant: work the returned tasks, completion trigger re-fires, converges (a score only moves when task body or arc drivers actually change, so it cannot oscillate). MUST report WHICH tasks re-surfaced and WHY (which driver moved them, from what) — an unexplained bounce-back from closure trains `--force`, which defeats the mechanism.
    3. **Priority flag replaces human-confirmed scores** — see IW-22.
    See IW-22 (flag design) and IW-23 (placement: this is arc-RUNNING infrastructure, not first-run-experience work).

- **IW-22: Priority flag replaces human-confirmed `bvp_scores:`?**
  confidence: 4
  disposition: ADOPTED with two additions (operator 2026-08-01)
  rationale: **SCOPE — BVP scoring is NOT retired.** It becomes MORE load-bearing: under this decision the estimator's score is the only score and is always fresh. Exactly ONE field is replaced — `bvp_scores:`, the human-confirmed per-driver 0-5 map set by hand via `fw bvp confirm` (T-1924). Untouched: the estimator, `bvp_scores_proposed:`, `cost_estimate:`, value drivers, arc-scoped drivers, quadrants, `fw bvp rank`, auto-promote. Measured 2026-08-01 across active+completed: `bvp_scores_proposed:` on 2519 tasks, `bvp_scores:` on 0.
    operator proposal — scoring is ALWAYS agent-driven; the human raises a flag ("do this now" / "treat as high value") instead of setting per-driver numbers. Assessed as strictly better shape than the T-1924 confirmed-score boundary: (a) removes the `if fm.get("bvp_scores"): continue` short-circuit entirely, so recalc always runs and every task always carries a current score — a real invariant, not a conditional one; (b) moves sovereignty from ARITHMETIC ("D2 is a 4") to INTENT ("this is in scope"), which is the axis humans are actually reliable on — IW-20 already conceded this in practice; (c) a flag survives recalc by construction because it is not a score. The replaced field is unused in practice but not harmless: the moment anyone DID set `bvp_scores:`, that task's score would freeze permanently. The flag gives the same override without freezing anything.
    **Addition 1 — direction.** The proposed flag only pushes a task UP. A push-DOWN is also needed ("estimator thinks this is high value, I disagree, do not hold the arc open for it"); without it an over-scoring estimator can keep an arc open indefinitely and the only escape is `--force`.
    **Addition 2 — rationale field.** Set when the flag is set, so an arc that will not close can answer "why is this blocking?".
    Cost note: the flag settles SCOPE (HV/HC and HV/LC both gate exit, so cost is irrelevant to whether a task is in scope) but cost still orders work WITHIN the arc — estimator supplies it free.
    Consumers to check before implementing: `fw bvp confirm` (T-1924), `fw bvp rank` (T-1919), auto-promote (T-1931), `bvp_scores:` frontmatter contract in CLAUDE.md.

- **IW-23: Where does the arc-exit mechanism live — inside one of the three arcs, or standalone?**
  confidence: 3
  disposition:
  rationale: agent position — this is arc-RUNNING infrastructure. It applies to all three arcs equally and to every arc after them, so filing it inside the install-testing arc would miscategorise it. Second position: strong candidate for a designer-corpus map (`aef-arc-exit`) plus a conformance rail against the implementing code, same pattern as `aef-task-lifecycle` (T-2624) — the workflow has real branching (recalc → any HV? → refuse vs proceed → flags → close gates), which maps express well and prose does not. Blocked on: the three arcs do not exist yet (D-5), and this mechanism gates their closure, so it plausibly sequences FIRST.

- **IW-20: Who scores, given zero tasks currently carry confirmed bvp_scores?**
  confidence: 2
  disposition:
  rationale: operator 2026-08-01 — PROPOSED (estimator) scores drive quadrant placement; human confirms EXCEPTIONS only (boundary cases, agent-flagged disputes, on-sight disagreement). Keeps arc progression unblocked without retiring the T-1924 sovereignty boundary. Known trade: execution order is effectively set by an estimator whose output is weak on thin bodies (T-2715 all-2s "no-signal" at 10:03 on a template body) — reinforces IW-21, estimation must re-fire once the body exists

- **IW-11: Which persona — agent-assisted only, or also a human typing README commands by hand?**
  confidence: 1
  disposition: OPEN — posed 2026-08-01, operator moved on without ruling; agent lean recorded below, NOT a decision
  rationale: **Premise checked and corrected.** Original wording said "README prompt presumes an agent" — the README ships BOTH personas as first-class sections: §"Get started — hand a prompt to your coding agent" (line 53, two paste-blocks A/B) and §"See it work in five minutes" (line 349, a bash block a human types by hand). So this is not about inventing a by-hand persona; one of the two shipped paths has never been tested. **Concrete defect found while checking:** the five-minute path's step 2 (`fw init` on an empty dir → greenfield) silently seeds T-001..T-005, then step 4 tells the human to create a sixth unrelated task (`fw work-on "Add authentication"`). The section never mentions the onboarding tasks exist — a by-hand human gets the scenario installed behind their back, walks past it, and reaches `fw audit` with five untouched tasks in `active/`. Invisible to an agent-only test, because the agent reads `active/`, sees T-001 and works it. **Agent lean: separate scenarios** — the two personas fail DIFFERENTLY, not at different rates: an agent hitting an ambiguous prompt re-reads CLAUDE.md and recovers silently, and that silent recovery is what hides the defect. Counter-argument against the lean, held open: two scenarios is two maintenance surfaces, and the by-hand path may be better FIXED (one line about the seeded tasks) than TESTED.

- **IW-12: How are findings classified?**
  confidence: 1
  disposition:
  rationale: **Premise corrected — four classification surfaces already exist, and the question is which one a first-run finding lands in, not what to invent.** Original wording proposed a fresh taxonomy (installer bug / prompt ambiguity / environment / agent error) without checking for existing ones. Measured 2026-08-01: (1) **learnings.yaml — 567 entries, 2026-04-13 → 2026-08-01, ALIVE**; (2) **concerns.yaml — 79 gaps, 9 status values (resolved 28, closed 18, mitigated 18, watching 5, open 4, …), ALIVE**; (3) **inbox.yaml observations — free-form `tags:` (bug / improvement / empty), 15 pending triage, WEAK**; (4) **patterns.yaml `failure_patterns` + the Error Escalation Ladder A/B/C/D — 11 entries, last touched 2026-03-23 (4+ months stale), 6 of 11 carry NO `escalation_step` at all, `occurrences_at_step` is 0 on every one that does, and `last_escalated` is null across the board — the ladder has NEVER escalated once, DEAD**. The fourth is the one that matters: the Escalation Ladder is doctrine in CLAUDE.md, it is the framework's official answer to "classify failures and respond proportionally", and it is not running. Note the axis mismatch too — A/B/C/D classifies the RESPONSE (don't repeat / improve technique / improve tooling / change ways of working); the proposed taxonomy classifies the CAUSE (installer / prompt / environment / agent). Orthogonal, so a "C" tells you to fix tooling but never whose. **Real risk: adding a fifth register makes five, one of them dead.**

- **IW-13: Who is the student — the human or the agent?**
  confidence: 2
  disposition:
  rationale: F-7 — T-001 is owner:agent with 4/4 Agent ACs and zero Human ACs; the AC carrying the education ("understand core principle, task system, enforcement tiers") is assigned to the agent, so the human currently learns nothing. **Evidence widened 2026-08-01 (from the IW-17 retraction):** across BOTH seed sets, **10 of 11** onboarding tasks are `owner: agent` — greenfield is 4/5 (only T-002 "define project goals" is human), existing-project is **6/6**. So option B's onboarding has no human-owned task at all. The pattern is not one mis-assigned task; it is the default.

- **IW-14: Prologue or interleaved curriculum?**
  confidence: 2
  disposition:
  rationale: operator wants "gradual deepening discovery", which is structurally incompatible with 5 front-loaded tasks completed before real work begins

- **IW-15: Does the scenario CONTAIN explanations or ROUTE to them?**
  confidence: 2
  disposition:
  rationale: operator's own T-2622 precedence decision (MD thins to principles+pointers, detail lives in maps) implies routing; embedding creates a second source of truth that drifts from CLAUDE.md/FRAMEWORK.md

- **IW-16: What exactly is deficient about the existing `fw onboarding skip`?**
  confidence: 2
  disposition:
  rationale: F-8 — the verb exists (bin/fw:6284) but is absent from README, lib/init.sh and docs/*.md; may be a discoverability fix rather than a new capability

- **IW-17: Does the existing-codebase path (README option B) get a scenario too?**
  confidence: 3
  disposition:
  rationale: **F-9 RETRACTED 2026-08-01 — the original premise was false.** The directory is `lib/seeds/tasks/existing-project/` (not `existing/`) and holds **6** tasks; `lib/init.sh:507` selects it by that name. The check looked at a path that never existed and reported a capability gap. Fifth instance this session of the inception's own thesis — a check reporting confidently about the wrong object — and the only one that reached the findings at confidence 3. What survives: the two seed sets differ in CONTENT (greenfield has "define project goals" `owner: human`; existing-project has fabric registration + learning capture and no human-owned task at all), so the question is whether option B needs a distinct SCENARIO on top of seeds it already has.

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

**Rationale:**

Grill in progress. Five scope decisions are the operator's and materially change what gets built (which install path, heal-vs-halt, oracle, arc fence, run budget). Evidence gap is real and external: the answers are not derivable from the codebase. Flip to GO once the grill resolves.

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

### 2026-08-01T10:03:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
