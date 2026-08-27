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
last_update: '2026-08-02T10:15:06Z'
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
  - ts: '2026-08-02T10:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=8 
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
  disposition: answered — **RESOLVED — COMPOSE, plus demo capture moves MID-FLIGHT (operator 2026-08-02, both parts).** HV-complete is the TRIGGER (when it is time to close); the demo is the PERMISSION (whether you may). HV-complete may never substitute. Second half is a change, not a confirmation: demo evidence is captured **when the headline mechanic actually fires during the work**, not assembled at closing time.
  rationale: completing every HV task could be entirely substrate; §ACD names substrate-vs-deliverable conflation as the failure. **Premise measured 2026-08-02 (F-11) — both §ACD layers are real code in `lib/arc.sh`, but only one has ever run.** Layer A (`_arc_validate_headline_mechanic`:227 — length bounds, observable-action check, substrate-phrasing rejection) is battle-tested: **14 of 14 arcs carry a `headline_mechanic`**. Layer B (`_arc_validate_demo_path`:256 / `_arc_validate_demo_url`:298 — existence, ≥256 bytes, extension allowlist, arc-id/task-id reference check) has **never executed**: 0 arcs closed ever (12 in-progress, 1 draft), no `status: closed` in the git history of `.context/arcs/`, and `.context/audits/arc-bypass.jsonl` **does not exist as a file** — `--demo none` has never been used. So the code already answers IW-18 in the compose direction (`fw arc close` structurally requires `--demo`), but that answer has been asserted zero times against a real closure. **Third instance in this inception of the complete-engine/never-fired-trigger pattern** (after the Escalation Ladder at IW-12a and the unreached existing-project seed set at F-10); a fourth was found the same day outside the inception (`_lane_owner` decides 0 of 75 lanes, OBS-120). **Why the mid-flight change is the load-bearing half:** HV-complete is countable, mechanical and agent-evaluable; the demo is judgment-bearing and requires a human to look at something. Presented as alternatives at closing time, the countable one wins — CLAUDE.md §ACD already pre-writes the resulting sentences ("substrate is in place", "forward work, not a closure blocker") and lists them as violations, i.e. the framework knows the failure because it has watched it happen four times. With `arc-bypass.jsonl` absent there is **no baseline**, so the first use of `--demo none` would also be the first test of whether its justification gets scrutinised. **Evidence the mid-flight pattern already works:** 3 of 14 arcs (arc-009, orchestrator-rethink, parallel-execution-aef) hold populated `demo_evidence` while still in-progress — captured when the mechanic fired, not at closure. A closure-time demo is the one that gets waived, because by then the work feels finished and the artefact feels like paperwork; mid-flight it is just recording that something worked.

- **IW-19: Under file-and-continue, is "all HV complete" measured against the task set at arc start, or as it evolves?**
  confidence: 3
  disposition: answered
  rationale: operator 2026-08-01 — EVOLVING, bounded by QUADRANT not by snapshot. Every newly discovered task/bug is BVP-estimated on arc assignment; HV/HC or HV/LC → in scope for this arc, anything else → does not gate closure. Arc-next stepping (BVP-ordered) manages the remainder. Intent: important bugs and high-value features get executed, low-value discovery never blocks. Coherent with IW-3: heal mode walks the whole chain per run, so HV-dryness is meaningful rather than an artifact of stopping at defect one. **Derived requirement (see IW-21): the estimation must be WIRED IN at arc-assignment time, not left to discipline**

- **IW-21: How is BVP estimation wired in at arc-assignment time?**
  confidence: 1
  disposition: answered — RESOLVED — recalc-then-pick primitive + exit-workflow recalc gate (operator 2026-08-01)
  rationale: operator named this the key challenge for D-5/IW-19. **Premise corrected during the grill** (agent had it wrong twice): (a) the estimator IS already arc-aware — T-2357 `_arc_scoped_drivers_for_task()` at estimator.py:125 resolves `arc_id:` → arc YAML → APPROVED `scoped_drivers:`, proposed ones deliberately do not fire; (b) re-estimation DOES exist — the `bvp-estimator-sweep-15m` cron (T-1923) is deployed at `/etc/cron.d/agentic-audit-999-*` and live (fired 21:00 on 2026-08-01). Agent's first check used `crontab -l` — WRONG OBJECT, reported clean, nearly filed a false drift finding. Same defect class as the whole inception.
    The REAL gap is narrower: the sweep's trigger is AGE (>24h `_proposed_is_stale`), not arc assignment. Assign a task to an arc while its score is fresh and the sweep skips it — arc-scoped scoring arrives up to a day late, and the quadrant IS the scope decision. Second hole: `if fm.get("bvp_scores"): continue` means a human-CONFIRMED task moved between arcs never re-scores. Third: `rubric_sha` is the sha of the rubric FILE, module-cached, identical for every task — so nothing records WHICH drivers a proposal was computed against, i.e. there is no stored evidence of arc drift to detect.
    **Operator mechanism (adopted, supersedes all four agent-proposed trigger seams):** recompute at the DECISION POINT rather than watching for write events. Path-agnostic by construction — indifferent to whether `arc_id` was set by hook, by `fw arc tag`, or by hand-editing frontmatter, because it compares state instead of subscribing to events. Three parts:
    1. **`recalc-then-pick` primitive** — on agent completion of any arc task: recalc all arc tasks (arc-scoped drivers included), then pick next HV/HC or HV/LC. Empty result IS the exit condition; no separate close-readiness heuristic, no polling. Subsumes the `/resume` recalc (session start is just another "what's next in this arc?"). Gap named: fires only on AGENT completion — human-closed last task or tasks re-scoped out of the arc trigger nothing, so `fw arc close` must re-run the same check as backstop (15-min sweep optional).
    2. **Exit workflow is a GATE, not a formality** — step 1 recalc, step 2 check quadrants; any task in HV/HC or HV/LC → RETURN TO ARC, do not close. Re-entrant: work the returned tasks, completion trigger re-fires, converges (a score only moves when task body or arc drivers actually change, so it cannot oscillate). MUST report WHICH tasks re-surfaced and WHY (which driver moved them, from what) — an unexplained bounce-back from closure trains `--force`, which defeats the mechanism.
    3. **Priority flag replaces human-confirmed scores** — see IW-22.
    See IW-22 (flag design) and IW-23 (placement: this is arc-RUNNING infrastructure, not first-run-experience work).

- **IW-22: Priority flag replaces human-confirmed `bvp_scores:`?**
  confidence: 4
  disposition: answered — ADOPTED with two additions (operator 2026-08-01)
  rationale: **SCOPE — BVP scoring is NOT retired.** It becomes MORE load-bearing: under this decision the estimator's score is the only score and is always fresh. Exactly ONE field is replaced — `bvp_scores:`, the human-confirmed per-driver 0-5 map set by hand via `fw bvp confirm` (T-1924). Untouched: the estimator, `bvp_scores_proposed:`, `cost_estimate:`, value drivers, arc-scoped drivers, quadrants, `fw bvp rank`, auto-promote. Measured 2026-08-01 across active+completed: `bvp_scores_proposed:` on 2519 tasks, `bvp_scores:` on 0.
    operator proposal — scoring is ALWAYS agent-driven; the human raises a flag ("do this now" / "treat as high value") instead of setting per-driver numbers. Assessed as strictly better shape than the T-1924 confirmed-score boundary: (a) removes the `if fm.get("bvp_scores"): continue` short-circuit entirely, so recalc always runs and every task always carries a current score — a real invariant, not a conditional one; (b) moves sovereignty from ARITHMETIC ("D2 is a 4") to INTENT ("this is in scope"), which is the axis humans are actually reliable on — IW-20 already conceded this in practice; (c) a flag survives recalc by construction because it is not a score. The replaced field is unused in practice but not harmless: the moment anyone DID set `bvp_scores:`, that task's score would freeze permanently. The flag gives the same override without freezing anything.
    **Addition 1 — direction.** The proposed flag only pushes a task UP. A push-DOWN is also needed ("estimator thinks this is high value, I disagree, do not hold the arc open for it"); without it an over-scoring estimator can keep an arc open indefinitely and the only escape is `--force`.
    **Addition 2 — rationale field.** Set when the flag is set, so an arc that will not close can answer "why is this blocking?".
    Cost note: the flag settles SCOPE (HV/HC and HV/LC both gate exit, so cost is irrelevant to whether a task is in scope) but cost still orders work WITHIN the arc — estimator supplies it free.
    Consumers to check before implementing: `fw bvp confirm` (T-1924), `fw bvp rank` (T-1919), auto-promote (T-1931), `bvp_scores:` frontmatter contract in CLAUDE.md.

- **IW-23: Where does the arc-exit mechanism live — inside one of the three arcs, or standalone?**
  confidence: 3
  disposition: answered — **RESOLVED — STANDALONE, option (b) (operator 2026-08-02), sequenced BEFORE the arcs it gates.** Same principle the operator applied to IW-12 an hour earlier (register enforcement is not first-run work, do not smuggle it into the onboarding arcs): arc-exit governs when EVERY arc closes — four of them as of IW-12's ruling, not three — so filing it inside one would make the referee a deliverable of one of the players. **Practical consequence: it must exist before those arcs can finish, since it is what closes them.**
  **Definition, now filled in by IW-18's ruling** (it was a placeholder when IW-23 was posed): recalculate the arc's task scores so "high value" is current rather than stale → any HV tasks still open? → if yes, refuse → if no, check a demo artefact exists → close. Consistent with F-11's measurement that no arc has ever closed: nothing implements this today.
  **Open sub-choice deliberately NOT decided here (build-shape, belongs after go/no-go):** strong candidate for a designer-corpus map (`aef-arc-exit`) plus a conformance rail on the T-2624 `aef-task-lifecycle` pattern — the workflow has real branching (recalc → any HV? → refuse vs proceed → demo present? → close) which maps express well and prose does not.
  **Presentation note:** the agent's first framing of this question led with the deciding principle and the map sub-choice without stating what the arc-exit mechanism IS; the operator asked *"huh what am i deciding for?"* — a fair hit. Shorthand established many turns earlier had stopped being self-explanatory. Re-posed concretely (what it does, that it does not exist, (a) inside an arc vs (b) standalone) and answered immediately.
  rationale: agent position — this is arc-RUNNING infrastructure. It applies to all three arcs equally and to every arc after them, so filing it inside the install-testing arc would miscategorise it. Second position: strong candidate for a designer-corpus map (`aef-arc-exit`) plus a conformance rail against the implementing code, same pattern as `aef-task-lifecycle` (T-2624) — the workflow has real branching (recalc → any HV? → refuse vs proceed → flags → close gates), which maps express well and prose does not. Blocked on: the three arcs do not exist yet (D-5), and this mechanism gates their closure, so it plausibly sequences FIRST.

- **IW-20: Who scores, given zero tasks currently carry confirmed bvp_scores?**
  confidence: 2
  disposition: answered (bookkeeping fix 2026-08-02 — the operator's 2026-08-01 ruling was recorded in `rationale:` but the `disposition:` field was left blank, so it read as OPEN in the completeness sweep)
  rationale: operator 2026-08-01 — PROPOSED (estimator) scores drive quadrant placement; human confirms EXCEPTIONS only (boundary cases, agent-flagged disputes, on-sight disagreement). Keeps arc progression unblocked without retiring the T-1924 sovereignty boundary. Known trade: execution order is effectively set by an estimator whose output is weak on thin bodies (T-2715 all-2s "no-signal" at 10:03 on a template body) — reinforces IW-21, estimation must re-fire once the body exists

- **IW-11: Which persona — agent-assisted only, or also a human typing README commands by hand?**
  confidence: 1
  disposition: answered — **RESOLVED — SEPARATE SCENARIOS, one per persona (operator 2026-08-02, "agreed", confirming the agent lean after the end-to-end reproduction below).** The two personas fail DIFFERENTLY, and the by-hand failure is structurally invisible to the agent-assisted test.
  rationale: **Premise checked and corrected.** Original wording said "README prompt presumes an agent" — the README ships BOTH personas as first-class sections: §"Get started — hand a prompt to your coding agent" (line 53, two paste-blocks A/B) and §"See it work in five minutes" (line 349, a bash block a human types by hand). So this is not about inventing a by-hand persona; one of the two shipped paths has never been tested. **Concrete defect found while checking:** the five-minute path's step 2 (`fw init` on an empty dir → greenfield) silently seeds T-001..T-005, then step 4 tells the human to create a sixth unrelated task (`fw work-on "Add authentication"`). The section never mentions the onboarding tasks exist — a by-hand human gets the scenario installed behind their back, walks past it, and reaches `fw audit` with five untouched tasks in `active/`. Invisible to an agent-only test, because the agent reads `active/`, sees T-001 and works it. **Agent lean: separate scenarios** — the two personas fail DIFFERENTLY, not at different rates: an agent hitting an ambiguous prompt re-reads CLAUDE.md and recovers silently, and that silent recovery is what hides the defect. Counter-argument against the lean, held open: two scenarios is two maintenance surfaces, and the by-hand path may be better FIXED (one line about the seeded tasks) than TESTED.
  **REPRODUCED END-TO-END 2026-08-02 — the five-minute path is not merely untested, it is a reproducible DEAD END, and it lands in the same deadlock as F-10 by a completely different route.** Ran the README's own sequence verbatim in an isolated scratch project: (1) `fw init .` on an empty dir → seeds T-001..T-005, which the five-minute section never mentions; (2) `fw work-on "Add authentication" --type build` → creates T-006, focus moves to it; (3) an agent Write on `app.py` → **T-532 gate exits 2, BLOCKED**, listing all five untouched onboarding tasks including T-002 (`owner: human`, `tags: [onboarding, inception]`, requiring an inception decision the agent is structurally forbidden to record under `$CLAUDECODE=1`). So F-10 reaches the deadlock via MISCLASSIFICATION; the five-minute path reaches the identical deadlock because **the README instructs the user straight into it**. Two independent routes, one destination — which raises the deadlock from "a defect in the detector" to "the default outcome of the documented happy path". **Why an agent-only test cannot surface this:** the agent reads `active/`, sees T-001 at the top, and works it — the walkthrough's step 4 (create an unrelated task) is exactly what an agent would never do unprompted. The by-hand persona is the only one that produces the sequence. **This retires the counter-argument against the agent's lean:** the by-hand path is not a maintenance-cost question about an untested surface, it is a surface with a reproduced failure that the tested surface structurally cannot reach. **Method note — two wrong objects in one measurement, both caught before reporting:** the first attempt passed `CLAUDE_PROJECT_DIR` and read the FRAMEWORK's focus (reported "Active task T-2715 is inception", exit 0 — a clean pass about the wrong project), and the exit code was captured after a pipe rather than from the hook. `check-active-task.sh:49-57` re-anchors PROJECT_ROOT from the stdin `cwd` field (T-2463/T-2465, OBS-080), so the payload must carry `cwd`. Corrected run reproduces reliably. Tenth and eleventh instances this session of the inception's own thesis.

- **IW-12: How are findings classified?**
  confidence: 1
  disposition: answered — **RESOLVED — REFRAMED BY OPERATOR (2026-08-02). No fifth register, and the question is not "which surface do first-run findings land in" but "how do we strengthen / enforce the surfaces that are not effective right now."** Operator's correction, verbatim in substance: *"didn't we conclude the mechanism/pattern rationale holds? In that case the question should be how do we enhance, strengthen, enforce the surfaces that are not effective right now."* Accepted — the agent's option list re-opened IW-12a's settled conclusion by offering "accept patterns.yaml stays dead" and "add a fifth register" as live choices. **Split ruled by operator: the DIAGNOSIS stays in this inception; the MECHANISM becomes a separate arc.** Rationale for the split: register enforcement is not first-run-experience work — it has nothing to do with installers, and smuggling it into the onboarding arcs would miscategorise it (same reasoning as IW-23's arc-running-infrastructure position).
  **DIAGNOSIS — surface 4 (patterns.yaml / Escalation Ladder), DEAD: the trigger has NO PRODUCER.** Grepped every write path for `status: issues` across `lib/ agents/ bin/ web/`. Every hit is a READER: `audit.sh:3530,4116` gate on it, `agents/healing/lib/diagnose.sh:98` refuses without it, `web/blueprints/core.py:41,266` render it, `active-task-scan.py:39` lists it as valid, and `update-task.sh:1716` REACTS to it by launching healing. **Nothing sets it.** The only producer is a human or agent voluntarily typing `--status issues`. That makes it a voluntary confession channel with the three properties that guarantee emptiness: it is extra work, it makes the task look worse, and it blocks nothing. Result: 0 of 2416 tasks. The ladder is not broken — it is waiting on an input nobody has an incentive to produce. **And the framework already witnesses real failures mechanically, then discards them:** `update-task.sh:1037` prints `ERROR: Cannot complete — N/M verification(s) failed` and refuses. That is a genuine failure event at a known moment with the failing command in hand, observed rather than self-reported, and nothing consumes it. **Enforcement direction: stop asking, start observing** — derive the trigger from events already witnessed (P-011 verification failure at close; gate bypasses already logged to `.gate-bypass-log.yaml`; Tier-0 / hook blocks). None require an agent to volunteer anything, and all three are literally the "failures are learning events" of Directive 1 (Antifragility).
  **DIAGNOSIS — surface 3 (inbox.yaml observations), WEAK: the signal never changes state.** Free-form `tags:`, 16 pending, and that count is printed in EVERY handover ("Observation inbox: 16 pending"). Surfaced continuously and ignored long enough to read as furniture — **L-527** exactly: a rule that gets tuned out is weaker than no rule, because its silence stops meaning anything. A count that only ever rises in a status line is not a signal. Enforcement direction: it must gate something or decay — a pending observation untriaged for N days should escalate or expire, so the number carries information about CHANGE rather than accumulation.
  **Surfaces 1 and 2 (`learnings.yaml` 567 entries, `concerns.yaml` 79 gaps) need no work — both alive, and this session routed every finding through them without inventing anything** (OBS-118/119/120, L-530, L-531 + task captures). That is the empirical proof no fifth register is needed.
  **DEFERRED TO THE NEW ARC (not decided here):** the axis mismatch remains unresolved — A/B/C/D classifies the RESPONSE (don't repeat / improve technique / improve tooling / change ways of working) while a cause-taxonomy classifies the CAUSE, so a "C" says fix tooling but never whose. Whether the revived ladder needs a cause axis alongside the response axis is arc scope.
  rationale: **Premise corrected — four classification surfaces already exist, and the question is which one a first-run finding lands in, not what to invent.** Original wording proposed a fresh taxonomy (installer bug / prompt ambiguity / environment / agent error) without checking for existing ones. Measured 2026-08-01: (1) **learnings.yaml — 567 entries, 2026-04-13 → 2026-08-01, ALIVE**; (2) **concerns.yaml — 79 gaps, 9 status values (resolved 28, closed 18, mitigated 18, watching 5, open 4, …), ALIVE**; (3) **inbox.yaml observations — free-form `tags:` (bug / improvement / empty), 15 pending triage, WEAK**; (4) **patterns.yaml `failure_patterns` + the Error Escalation Ladder A/B/C/D — 11 entries, last touched 2026-03-23 (4+ months stale), 6 of 11 carry NO `escalation_step` at all, `occurrences_at_step` is 0 on every one that does, and `last_escalated` is null across the board — the ladder has NEVER escalated once, DEAD**. The fourth is the one that matters: the Escalation Ladder is doctrine in CLAUDE.md, it is the framework's official answer to "classify failures and respond proportionally", and it is not running. Note the axis mismatch too — A/B/C/D classifies the RESPONSE (don't repeat / improve technique / improve tooling / change ways of working); the proposed taxonomy classifies the CAUSE (installer / prompt / environment / agent). Orthogonal, so a "C" tells you to fix tooling but never whose. **Real risk: adding a fifth register makes five, one of them dead.**

  **IW-12a (operator 2026-08-01, before dismissing the ladder): is the ladder's RATIONALE correct, and if so what enforces it?** Measured rather than assumed. **The rationale is sound and the implementation is complete — the trigger is what never fires.** Full chain verified present: `update-task.sh:1714-1716` auto-triggers healing on `--status issues|blocked`; `agents/healing/lib/diagnose.sh:60` does FP-XXX pattern lookup; `diagnose.sh:156` prints "SUGGESTED RECOVERY (Error Escalation Ladder)"; `lib/resolve.sh:77-86` allocates and writes new FP entries; `lib/patterns.sh:23-46` parses them. Every link is built. **`status: issues` count across 2416 completed + all active: ZERO. `status: blocked`: ZERO.** The engine has never been invoked because the gate condition has never once occurred. 18 completed tasks mention issues in their bodies — the failures happened, the status transition did not. **So the ladder is not dead doctrine; it is a working engine behind a door nobody opens.** Diagnosis of WHY the door stays shut: setting `issues` is a deliberate extra step with no forcing function, and it is strictly costly to the agent (it interrupts flow, and the agent already knows the fix). The natural agent behaviour on hitting a problem is fix-and-continue or file-a-new-task, both of which leave status at `started-work` throughout. **Corollary for the ladder's rationale:** the counting model (escalate on recurrence of the same pattern) also requires a matching step — recognising "this is FP-007 again" — that nothing performs; meanwhile G-019 grew a SECOND escalation mechanism that fires on blindness-duration and on a SINGLE incident, explicitly contradicting the counting trigger, and that one is alive (79 concerns). The live mechanism displaced the counted one. Enforcement question therefore is not "revive the ladder" but "what makes the transition happen without depending on agent discipline" — the same structural-vs-disciplinary distinction the framework's own D-step produced.

- **IW-13: Who is the student — the human or the agent?**
  confidence: 2
  disposition: answered — RESOLVED — BOTH, with DIFFERENT curricula (operator 2026-08-02, option 3). Agent learns mechanics (task system, gates, verbs) — the existing 38 Agent ACs are not wrong for that half. Human learns **decision surfaces and recovery** — approvals, review, sovereignty verbs, and what to do when it breaks. That second curriculum does not currently exist in any form: 1 Human AC across 11 tasks, and it is QA on agent output rather than education. Origin case is decisive: Mehdi did not need task mechanics, he needed to know what to do when the install failed. Rejected: (1) human-only — would make every onboarding sit at partial-complete awaiting a human, which is the friction `fw onboarding skip` already exists to escape; (2) agent-only — incompatible with the operator's "gradual deepening discovery", which presumes the human learns over time; (4) nobody/smoke-test — would concede F-5's collapse of goals 2 and 3 rather than resolve it. **Consequence for IW-14:** two curricula means two schedules, so "prologue vs interleaved" must now be answered per-curriculum, not once.
  **AMENDED 2026-08-02 (operator): the human curriculum is TRAINING, not TESTING — it must NOT use Human ACs.** Operator's correction, verbatim in substance: *"why do we need human ACs — it's training, does not per se need to be a test, it is to support and help learn, not to gatekeep."* Accepted, and it corrects a design error on the agent's side: Human ACs are a VERIFICATION instrument (they exist so unverified deliverables cannot ship). Training is a SUPPORT instrument. Reaching for Human ACs imported gatekeeping semantics into something that should never gate. **Supporting evidence found while checking:** greenfield T-001's entire `## Context` is one sentence — *"First task for <project>. Read CLAUDE.md to understand the framework, verify installation, and prepare for project definition."* It does not teach; it POINTS at CLAUDE.md (a ~1000-line agent operating manual) and then has the agent tick `- [ ] Read CLAUDE.md — understand core principle, task system, enforcement tiers`. So the agent was designing a test for a course that does not exist. **What this dissolves:** the IW-14 deadlock disappears entirely — nothing waits on a human tick, `fw onboarding skip` stops being a dual-purpose escape, and no new project freezes on human availability. **What it re-opens:** the human curriculum's success measure can no longer be completion. It is BEHAVIOURAL — the origin case is Mehdi being unable to self-heal, so the measure is "could the human recover", never "did the human finish the course." **Residual risk to design against (F-8 precedent):** optional support that is not deliberately surfaced is indistinguishable from support that does not exist — `fw onboarding skip` already exists at bin/fw:6284 and is undiscoverable. Removing the gate therefore RAISES the burden on the surfacing mechanism rather than lowering it.
  rationale: F-7 — T-001 is owner:agent with 4/4 Agent ACs and zero Human ACs; the AC carrying the education ("understand core principle, task system, enforcement tiers") is assigned to the agent, so the human currently learns nothing. **Evidence widened 2026-08-01 (from the IW-17 retraction):** across BOTH seed sets, **10 of 11** onboarding tasks are `owner: agent` — greenfield is 4/5 (only T-002 "define project goals" is human), existing-project is **6/6**. **Counted at AC level 2026-08-02, which is sharper still: 38 Agent ACs vs 1 Human AC across all 11 seeded tasks.** The single Human AC is greenfield T-002's `[REVIEW] Problem statement is clear and scoped` — and note what it asks: it is QA on the AGENT'S output (read the artifact the agent wrote, check it explains what the project does), not education about the framework. existing-project has **zero** `### Human` blocks across all 6 tasks. So the ratio is 38:1, and the 1 is not teaching. (Method note: the first count returned 4 because an `awk` range ran across a multi-file glob as one stream and leaked past the file boundary — recounted per-file. Seventh instance this session of a measurement whose subject was not what the sentence named; caught in flight.) **The literal shape of the defect:** the AC that says "understand core principle, task system, enforcement tiers" is ticked by the agent, after the agent reads CLAUDE.md.

- **IW-14: Prologue or interleaved curriculum?**
  confidence: 2
  disposition: answered — **RESOLVED — PER-CURRICULUM SPLIT + a new invariant (operator 2026-08-02, "ok" on the agent recommendation).** (a) **Human curriculum: INTERLEAVED, ungated, point-of-need** — forced by IW-13's amendment; ungated training cannot be a prologue because nothing holds it in place, so point-of-need is the only available shape, which is exactly what the D-8 teach-note designs. (b) **Agent curriculum: KEEP THE PROLOGUE** — it is mechanics, every task is agent-completable, and it legitimately precedes real work. (c) **NEW INVARIANT — nothing `owner: human` or agent-unresolvable may sit in the gated onboarding set.** That is what converts a prologue into a trap, and it is mechanically checkable at seed time.
  **Why the invariant is the load-bearing part.** The prologue is not what breaks. Both of the sharpest defects found on 2026-08-02 run through the T-532 gate — F-10 (misclassified .NET/C++/Ruby/PHP/Gradle/flat-layout user) and IW-11 (the README five-minute walkthrough, reproduced end-to-end) — yet the gate is doing its job in both. What breaks is that **exactly one** human-owned, agent-unresolvable task sits inside the gated set: greenfield `T-002`, `owner: human`, `tags: [onboarding, inception]`, whose Agent ACs require `fw inception decide` and whose `[REVIEW]` Human AC only the operator can tick. Measured: it is the ONLY `owner: human` task across all 11 seeds (greenfield 4/5 agent, existing-project 6/6 agent). **One task, two independent deadlocks.** The invariant would have prevented both without touching the gate.
  **Supersedes the pre-amendment rationale below**, which was written when IW-13 still implied the human curriculum would carry `### Human` ACs. That premise was overturned by the operator's training-not-testing correction, and with it the deadlock this question originally described.
  rationale: operator wants "gradual deepening discovery", which is structurally incompatible with 5 front-loaded tasks completed before real work begins. **Premise verified and it is STRONGER than stated — the prologue is not a convention, it is a hard PreToolUse gate.** `agents/context/check-active-task.sh:443-480` (Policy T-532, Onboarding Enforcement Gate) exits 2 on any Write/Edit whose active task is not onboarding-tagged, while any `.tasks/active/` task tagged `onboarding` is not `work-completed`. Confirmed live: all 11 seed tasks carry `tags: [onboarding]` in their first 20 lines, so the detector matches. `post-compact-resume.sh:138` states it plainly — "Setup tasks must complete before other work." Escape is the marker file `.context/working/.onboarding-complete` or `fw onboarding skip`. **DERIVED CONSTRAINT from IW-13's resolution (operator chose BOTH curricula, 2026-08-02):** the human curriculum will carry `### Human` ACs, which by construction the agent cannot tick. If those tasks are onboarding-tagged, T-532 blocks **all** real work in a brand-new project until the human personally completes their course — and the only escape, `fw onboarding skip`, skips BOTH curricula at once. So "prologue for both" is not merely slow, it deadlocks the project on human availability, and the pressure valve discards the agent's mechanics curriculum as collateral. This is a structural conflict between IW-13's answer and the shipped gate, not a preference between teaching styles.

- **IW-15: Does the scenario CONTAIN explanations or ROUTE to them?**
  confidence: 2
  disposition: answered — **RESOLVED — ROUTE (ratified by T-2622 precedence, not chosen here), destination = the promoted corpus maps, with a three-part sequencing ruled by the operator 2026-08-02.** (1) **Note self-sufficiency is an immediate, unblocked constraint:** the teach note must be self-sufficient for the immediate ACTION and route only for the WHY — so a blocked human is never sent to "go read a diagram" instead of being told the fix. Adopted now. (2) **The map-register fix is the actual solution and is 832-gated:** the existing map notes are engineer-register (tier0's reads *"PreToolUse hook fires on every Bash tool_input.command — this is the trigger surface, not opt-in"*), which is not human-learner language, so a routed newcomer lands on implementer prose. Resolution depends on 832's audience ruling, batched on their T-189 for their operator. (3) **Fallback held in reserve:** if that ruling returns "one field, audience DECLARED" (their stated lean), rewriting our own map notes in learner register becomes the only remaining lever, and we would have to decide per-map which audience the single field serves.
  **AGENT FRAMING ERROR, corrected by the operator.** The agent presented these as three mutually exclusive options and recommended (1). The operator pushed back — *"why not 1, is this not the better solution?"* — and was right on both counts: **the options are not alternatives** (note self-sufficiency is a property of the NOTE; the register fix is a property of the MAP; doing one does not foreclose the other), and **the register fix is the better solution while note self-sufficiency is not a solution to the register problem at all** — it makes us robust to the mismatch going unfixed. A human who does follow the link still lands on implementer prose. Avoidance presented as design.
  **Caveat recorded, since it changes what "waiting for the ruling" buys:** 832's stated lean (rail 374) is AGAINST the audience-tagged pair — *"one field with its audience DECLARED is the more honest artifact, because it makes the choice visible instead of accidental. Today it has silently picked the implementer, which is your point and I think it is correct."* They would accept a pair only if it ships with an instrument making the two answerable to each other (their proposed condition: *"the newcomer note MUST NOT be derivable by truncating the implementer note"*) — their objection is not that a pair rots but that they cannot DETECT when it has, the same upgrade they made from declared tolerances to executable CARRIES-probes. So the ruling may land as "no pair", which is a real outcome rather than a stall, and would leave the destination problem unambiguously ours (→ fallback 3).
  rationale: operator's own T-2622 precedence decision (MD thins to principles+pointers, detail lives in maps) implies routing; embedding creates a second source of truth that drifts from CLAUDE.md/FRAMEWORK.md. **Premise verified 2026-08-02 — the precedence model is RATIFIED, not merely implied, and it is quoted from `.tasks/completed/T-2622...md:93`:** *"the end-state is cascading detail levels — CLAUDE.md thins to principles + pointers, workflow maps hold the process detail, code enforces. NOT permanent map-subordination... until that map's conformance rail (T-2621 pattern) is green, then the map graduates to detail-authority and the corresponding CLAUDE.md prose is REPLACED by a reference to the map."* So "route" is already the ratified answer; what IW-15 actually has to settle is the DESTINATION. **Measured: routing a human to CLAUDE.md would be routing them into the wrong document.** CLAUDE.md is 1280 lines / 15,565 words of agent operating manual (FRAMEWORK.md 375/2,636; README 854/5,565; docs/*.md 14 files). **The right destination already exists and mostly already covers the IW-13 human curriculum.** Six promoted corpus maps: `aef-tier0-escalation`, `aef-task-lifecycle`, `aef-session-lifecycle`, `aef-inception-flow`, `aef-audit-cron`, `aef-dispatch-loop`. The first four are decision-surface + recovery material — exactly what IW-13 assigned to the human — and only the last two are agent-facing. `fw corpus explain aef-tier0-escalation` was run and returns a readable walkthrough (title, version, provenance, Lanes with authority, "Walkthrough (flow order)" with per-node notes); `/designer` renders the same maps visually. **So the human curriculum's destination is not hypothetical and does not need writing from scratch — it needs ROUTING TO, which nothing currently does.** **Tension to design against:** routing a *blocked* human to "go read a diagram" is worse than telling them the fix. The teach note must therefore be self-sufficient for the immediate ACTION and route only for the WHY — which makes the D-8 teach note the new top layer of the T-2622 cascade: note (action) → map (process) → code (enforcement).
  **IW-15a (operator 2026-08-02): does option 4 also POINT to the diagram, and should the diagram/elements be EXTENDED to carry more process explanation?** (1) **Yes — the pointer is not optional in option 4.** Without it the note is `contain` wearing a hybrid label; the pointer is the entire routing half. Concrete shape: `<what happened> · <one-line why> · <exact command to proceed> · fw corpus explain <map-id> (or /designer)`. (2) **Extending the maps is the right instinct, and the carrier question is measurable — it favours a standards move that is 832's to rule on.** Measured across all 12 corpus projects: **`<bpmn:documentation>` — the BPMN spec's own native per-element documentation element — is used ZERO times.** Explanation is instead carried entirely in the custom extension `aef:meta note`, which is used heavily (promoted maps 5-16 notes each: audit-cron 7, dispatch-loop 16, inception-flow 5, session-lifecycle 8, task-lifecycle 9, tier0-escalation 10; drafts 22-69). `fw corpus explain` already renders those notes in the walkthrough, so the rendering path exists and needs no new work. **Three sub-decisions this raises, only the third of which is ours alone:** (a) **CARRIER** — spec-native `bpmn:documentation` (portable to any BPMN tool, currently unused) vs `aef:meta note` (custom, proven, in-toolchain). Directive 4 (Portability — prefer standards) points at the former; this is a dialect-level call and belongs to 832 in their v1.1 batch, not to us unilaterally. (b) **AUDIENCE** — the existing notes are engineer-register, e.g. tier0's *"PreToolUse hook fires on every Bash tool_input.command — this is the trigger surface, not opt-in"*. That is not human-learner register. So does one note field serve two audiences, or do we need audience-tagged notes? This is the T-2143 audience axis reappearing at the map layer. (c) **CONTENT** — the notes on OUR maps are ours to write regardless of how (a) and (b) resolve. **Boundary:** we propose the carrier/audience question on the 832 rail and they rule; we do not extend the dialect unilaterally.

- **IW-16: What exactly is deficient about the existing `fw onboarding skip`?**
  confidence: 2
  disposition: answered — RESOLVED — **NOTHING. F-8 RETRACTED (operator 2026-08-02, agent-suggested).** The verb is correctly surfaced to its actual audience; no bypass work is needed. One filed residual carried to the onboarding-scenario arc (below).
  rationale: **F-8's premise was false on the axis that matters — eighth instance this session of a check reporting confidently about the wrong object.** The original finding measured *documents* (README/FRAMEWORK/docs) and never measured the surface a **blocked reader** actually looks at. Measured 2026-08-02: (a) the T-532 block message itself names it verbatim — `agents/context/check-active-task.sh:475-476` prints *"To skip onboarding (not recommended): fw onboarding skip"* at the exact moment of blocking, with the exact copy-pasteable command and a stance on whether to use it; (b) `fw help` line 58 lists `onboarding <cmd>  Onboarding gate (status|skip|reset)`. That is the best discoverability shape in the framework — point-of-need. Nobody reads README while blocked. **Stakes shrank further under prior rulings:** IW-13-amended (training not testing) + IW-14 leave the human curriculum ungated, so the T-532 gate now holds back only the agent prologue — `skip` is an agent escape from an agent gate, and its discoverability *to agents* is already excellent. **Origin case disconnects it entirely:** the gate fires on Write/Edit *after* `init.sh` seeds tasks; Mehdi's failure was at install time and never reached it, so a discoverability fix on `skip` would not have touched the origin case at any point.
  **RESIDUAL (filed, not built — belongs to the onboarding-scenario arc):** every surface naming `skip` is *agent-facing*; every *human-facing* surface is silent. `lib/init.sh:542` closes the install with *"Onboarding tasks are ready — N tasks will guide you through setup."* Not false, but **incomplete in its consequential half** — those tasks also BLOCK every other edit until done or skipped. The output describes a tutorial; the mechanism is a gate. A human whose agent then stalls has no model for why. Third appearance of the T-2143 audience axis this session, and the same defect class as this inception's thesis sitting in the install output itself. **Scope of the fix:** one clause naming the *gating behaviour*, human-register. The escape verb deliberately stays out of the banner — naming `skip` there advertises the bypass before the human has any reason to want it. **Honesty bound:** this is INFERRED need, not recorded failure — no human is known to have hit it; it is argued from the sentence being wrong, not from an incident, and must be weighted at that level. Natural first instance of the D-8 teach-note shape (`<what happened> · <one-line why> · <what to do>`).

- **IW-17: Does the existing-codebase path (README option B) get a scenario too?**
  confidence: 3
  disposition: answered — **REFRAMED 2026-08-02 — wrong question. Option B already HAS a scenario, and it is the better-designed of the two (6 tasks incl. fabric registration + learning capture, vs greenfield's 5). The defect is that 6 of 7 existing-codebase ecosystems NEVER REACH IT.** See F-10. The question was aimed at CONTENT; the defect is in ROUTING. **RULED (operator 2026-08-02): keep F-10 WHOLE in the onboarding-scenario arc — no standalone bug task split out.** Agent had offered a split (detector-list extension as its own bug task + deadlock structure to the arc); operator declined. Consequence accepted deliberately: the detector fix does not ship ahead of the arc, so .NET/C++/Ruby/PHP/Gradle/flat-layout users stay misclassified until the arc reaches it. Coherent with IW-19 — F-10 is unambiguously HV, so arc-assignment BVP places it in scope rather than deferring it; and coherent with G-019/§scope-root-not-symptom, since fixing the detector alone would leave the two structural legs (human-owned + agent-forbidden T-002; T-532 blocking until complete) intact and the deadlock reachable by any other misclassification.
  **INDEPENDENT CONFIRMATION (832 rail 376, arrived AFTER the operator's ruling):** *"the fix wants to be 'enumerate what IS there and decide', not 'lengthen the list' — a longer list has the same property and a later failure date."* This validates the ruling and falsifies the agent's proposed split: the standalone fast-ship half the agent wanted was **exactly** "lengthen the list", which reproduces the defect's property with a later failure date while looking like a fix. 832 also named the cost profile precisely — *"a silent wrong answer plus a green instrument is strictly worse than a loud failure"* — and observed the exemption has no table at all: *"'not on the list' acquired the meaning 'has no code' without anyone deciding that it should."* **Note for the arc: this class caught the agent twice in one session — once as the thing under investigation, once as the remedy proposed for it.** The fix shape is therefore an ENUMERATION requirement, not a list extension: determine what the directory actually contains and decide from that, so the failure mode is "we looked and were wrong" rather than "we never looked at this ecosystem."
  **F-10 (new finding, empirically demonstrated by running the real `fw init`, not by replicating the loop):** `lib/init.sh:489-502` detects existing code from 7 manifests (`package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `setup.py`) + 3 dir names (`src`, `lib`, `app`). Tested against synthetic projects, ALL of these seeded as **greenfield**: `.csproj`+`.cs` (.NET), `CMakeLists.txt`+`.cpp`, `Makefile`+`.c`, `Gemfile`+`.rb`, `composer.json`+`.php`, `build.gradle`+`.java`, flat `.py` at root. Covered: JS/TS, Python, Go, Rust, Maven-Java. Missed: .NET, C/C++, Ruby, PHP, Gradle-Java, flat layouts. **.NET is not an edge case here** — CLAUDE.md's toolchain-build table lists `*.vbproj`/`*.csproj` → `dotnet build`, and the framework's real consumer `003-NTB-ATC-Plugin` IS a VB.NET plugin. The documented consumer toolchain is invisible to the detector that decides how consumers are onboarded.
  **The cost is a complete deadlock, not a cosmetic mismatch:** (1) user gets greenfield `T-002 "Define goals and architecture"`, `owner: human`, `tags: [onboarding, inception]`; (2) T-002 carries the ONLY `### Human` AC in either seed set (`[REVIEW] Problem statement is clear and scoped`) — human-only by construction; (3) its Agent ACs require `fw inception decide T-002 go`, which `lib/inception.sh` REFUSES under `$CLAUDECODE=1` (T-1259/T-1260) — the agent structurally cannot record it; (4) the T-532 gate blocks all non-onboarding Write/Edit until every onboarding task is `work-completed`, and partial-complete stays in `active/`, so the gate keeps holding; (5) they also never get existing-project's `T-003 register key components in fabric` or `T-006 record first project learning` — the two tasks written for people who have code. **Net: an existing-codebase user in 6/7 ecosystems is blocked by a governance gate on a human-owned "define goals" task for a project that already exists, with `fw onboarding skip` as the only exit. Closest reconstruction in this inception of the origin case.** Retroactively justifies IW-16: `skip`'s point-of-need surfacing is load-bearing precisely because this deadlock is reachable by default.
  **Ninth instance of this inception's thesis — and the FIRST that is in the shipped product rather than in the investigation of it:** a check (`has_code`) reporting confidently "greenfield" about a project that has code.
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

The grill is complete — **23 of 23 open questions disposed, zero blank** — and the evidence gap that justified the filing-time DEFER is closed. Every scope decision the DEFER named (install path, heal-vs-halt, oracle, arc fence, run budget) now has an operator ruling recorded against it, so DEFER would now be a confidence hedge rather than an evidence gap (T-2144/T-2145).

The inception asked why four green install surfaces missed a blocked user. **It has an answer, and the answer generalised past the installer.** The dominant defect class is *a check that reports success about the wrong object* — eleven instances, of which the last two were produced by this investigation's own instruments and caught in flight. Two of the eleven are reproduced end-to-end dead ends in shipped code, reached by independent routes:

- **F-10** — 6 of 7 common ecosystems (.NET, C/C++, Make, Ruby, PHP, Gradle-Java, flat-layout) are seeded as *greenfield*, landing the user on a human-owned task requiring a decision the agent is structurally forbidden to record, behind a gate that blocks all other work.
- **The five-minute path (IW-11)** — the README's own "five minutes" walkthrough reaches the identical block by instruction rather than misclassification.

A third measurement recurred often enough to be the finding rather than a finding: **four separate mechanisms are complete, wired, and have never fired** — the Escalation Ladder (trigger set on 0 of 2416 tasks), the existing-project seed set, the arc-closure demo validator (0 closures ever), and `_lane_owner` (decides 0 of 75 lanes).

**What GO authorises** — five work items, none of which is "fix the installer":

1. **Arc-exit mechanism, standalone and FIRST** (IW-23) — recalc → any HV open? → refuse/proceed → demo present? → close. Gates the closure of everything below, so it precedes them.
2. **Arc: harness + installer** — F-10's fix shaped as *enumerate what is there and decide*, **not** a longer manifest list (832 rail 376; a longer list reproduces the property with a later failure date).
3. **Arc: README prompt quality** — two personas, separate scenarios (IW-11), because the by-hand failure is structurally invisible to the agent-assisted test.
4. **Arc: onboarding scenario redesign** — agent prologue kept, human curriculum interleaved and ungated (IW-13/IW-14), routing to corpus maps rather than embedding (IW-15), plus the new invariant that **nothing `owner: human` or agent-unresolvable may sit in the gated onboarding set**.
5. **Arc: register enforcement** (IW-12) — diagnosis complete here, mechanism separate: the ladder's trigger has no producer, so derive it from failures the framework already witnesses (P-011 close failures, logged gate bypasses, Tier-0 blocks) instead of asking agents to self-report.

All arcs carry G-062 headline mechanics and arc-scoped drivers created upfront (D-5), close on HV-complete **composed with** a demo (IW-18), and capture that demo **mid-flight, when the mechanic fires** — not as a closing ritual.

**Evidence:**

- 23/23 questions disposed; completeness verified mechanically (`disposition:` blank count = 0), after a sweep found 6 open when the agent believed 1 remained.
- **F-10 reproduced** by running the real `fw init` against 7 synthetic projects — all seeded greenfield.
- **Five-minute path (IW-11) reproduced end-to-end**: `fw init` → `fw work-on "Add authentication"` → agent Write → `T-532 exit 2`, five untouched onboarding tasks listed.
- **F-11 measured**: §ACD Layer A proven (14/14 arcs carry `headline_mechanic`); Layer B never executed (0 closures, `arc-bypass.jsonl` absent).
- **F-8 and F-9 both RETRACTED** on measurement — the retraction rate is itself evidence for the dominant class.
- Live registers carried every finding without a new taxonomy: OBS-118 (fixed, T-2717), OBS-119, OBS-120, L-530, L-531.
- Cross-validated with 832 across rails 371-377; they independently supplied the F-10 fix shape and flagged a defect (OBS-120) the agent had under-scoped.

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

**Rationale**: The grill is complete — **23 of 23 open questions disposed, zero blank** — and the evidence gap that justified the filing-time DEFER is closed. Every scope decision the DEFER named (install path, heal-vs-halt, oracle, arc fence, run budget) now has an operator ruling recorded against it, so DEFER would now be a confidence hedge rather than an evidence gap (T-2144/T-2145).

The inception asked why four green install surfaces missed a blocked user. **It has an answer, and the answer generalised past the installer.** The dominant defect class is *a check that reports success about the wrong object* — eleven instances, of which the last two were produced by this investigation's own instruments and caught in flight. Two of the eleven are reproduced end-to-end dead ends in shipped code, reached by independent routes:

**Date**: 2026-08-02T00:13:52Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-01T10:03:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-02T00:13:52Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The grill is complete — **23 of 23 open questions disposed, zero blank** — and the evidence gap that justified the filing-time DEFER is closed. Every scope decision the DEFER named (install path, heal-vs-halt, oracle, arc fence, run budget) now has an operator ruling recorded against it, so DEFER would now be a confidence hedge rather than an evidence gap (T-2144/T-2145).

The inception asked why four green install surfaces missed a blocked user. **It has an answer, and the answer generalised past the installer.** The dominant defect class is *a check that reports success about the wrong object* — eleven instances, of which the last two were produced by this investigation's own instruments and caught in flight. Two of the eleven are reproduced end-to-end dead ends in shipped code, reached by independent routes:
