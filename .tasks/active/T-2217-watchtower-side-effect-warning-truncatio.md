---
id: T-2217
name: "Watchtower side-effect-warning truncation — RCA + systemic mitigation (G-068
  4th incident)"
description: >
  Inception: Watchtower side-effect-warning truncation — RCA + systemic mitigation
  (G-068 4th incident)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-05T19:52:03Z
last_update: '2026-06-05T20:00:02Z'
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
  - ts: '2026-06-05T19:52:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-05T20:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2217: Watchtower side-effect-warning truncation — RCA + systemic mitigation (G-068 4th incident)

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Should the truncation in `web/blueprints/inception.py:551` be widened (Candidate A), or should the side-effect-warning rendering be replaced with an expandable `<details>` block (Candidate D), or both?**
  confidence: 2
  disposition: answered
  rationale: Candidate A (widen to ~1500 chars) is XS cost and immediately closes today's RC4 visibility. D is UX-leg-only nice-to-have; defer. See `docs/reports/T-2217-watchtower-side-effect-truncation-rca.md` §3.

- **IW-2: Should the G-068 META-fix (e2e contract test, named 2026-05-05 as `(not yet filed)` follow-up) ship as part of this task, or be deferred to a separate slice?**
  confidence: 2
  disposition: answered
  rationale: SHIP as Slice 2 of this task. 4 incidents in 31 days (RC1-RC4 of G-068 class) is sufficient evidence per T-2144 to commit. Strategic-investment frame same as T-2209 Path C-scoped. See §3 Candidate B + §5.

- **IW-3: Should the pre-flight validation (Candidate C — `update-task.sh --dry-run` before recording Decision) be added now, deferred, or rejected?**
  confidence: 3
  disposition: dissolved
  rationale: F8=5.0 (L) cost is over-budget for the marginal value over Candidate B at F8=3.0 (M). C reintroduces the T-1470 failure mode (operator can't record decision when transient side-effect glitches). Rejected for this round; revisit if A+B prove insufficient. See §3 Candidate C strawman.

- **IW-4: How does the immediate T-2209 stuck `started-work` state resolve, independent of this task's mitigation?**
  confidence: 3
  disposition: deferred
  rationale: Operator-Sovereign — either honest fix (add IW-1/IW-2 dispositions to T-2209 then re-click GO) or Tier-2 bypass (`FW_SKIP_DISPOSITION_GATE=1`). Not blocking T-2217. See §7.

<!-- Format reference (do not delete):
     - **IW-N: <question>**
       confidence: 0-3      (0=guess, 3=verified)
       disposition: answered | deferred | dissolved
       rationale: <one-line evidence>
-->

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

**Recommendation:** GO — ship Candidate A + Candidate B jointly

**Rationale:**

Filed initially as DEFER (evidence gap); upgraded to GO after candidate analysis landed in `docs/reports/T-2217-watchtower-side-effect-truncation-rca.md` §3-§6.

- **A alone is insufficient.** RC1-RC3 (T-1744 / 2026-05-05) and RC4 (T-2209 / 2026-06-05) are four independent code-path failures inside the same META-class (G-068). A surgical fix per RC keeps incurring incidents.
- **B alone leaves today's RC4 un-mitigated.** Operator sees the banner-only warning until A also lands.
- **A is XS (F8 0.5).** No reason to defer for B's build.
- **B closes G-068 META** — the 31-day-old `(not yet filed)` follow-up that G-068 itself named. Evidence: 4 incidents, 31 days, named META, named harness (Playwright). Sufficient per T-2144 to commit; this is GO with calibrated confidence, not DEFER.
- **C is over-cost** for the marginal value over B.
- **D is a UX nice-to-have**, deferred to future round if A's wider truncation proves insufficient.

Strategic-investment frame (operator-applied to T-2209 / Path C-scoped) applies here too: foundational control surface, 4th-of-class signal, the cost-per-incident loop only closes when the META lands.

**Evidence:**

- **G-068** in `.context/project/concerns.yaml:2090-2129` — 3 prior RCs + the `(not yet filed)` META-fix
- **`web/blueprints/inception.py:551`** — `(stderr or stdout)[:150]` truncation literal (the source of RC4)
- **`lib/inception.sh:716`** — the `update-task.sh --status work-completed` chain inside `do_inception_decide`
- **`agents/task-create/update-task.sh`** disposition gate (T-2190) — the gate firing on T-2209
- **T-2209 current state** — `.tasks/active/T-2209-*.md`, status started-work, Decision=GO, 0/4 unchecked ACs, IW-1/IW-2 dispositions missing — proves the stuck-state symptom
- **Empirical reproduction** — `bash agents/task-create/update-task.sh T-2209 --status work-completed --skip-sovereignty --reason "diagnostic retry"` returns ERROR with full text at char ~250+
- **31-day gap** — G-068 `created: 2026-05-05`, today 2026-06-05; META-fix `resolution_path: "T-1746 (fix all three RCs + integration test pin); follow-up watchtower.log liveness check (not yet filed) — pattern: 'grep inception decide.*failed watchtower.log' should be a monitored signal"`

**Slicing under §ACD G-062:**

| Slice | Candidate | Scope | F8 | Closes |
|---|---|---|---|---|
| 1 | A | Widen `web/blueprints/inception.py:551` truncation 150→1500; wrap stderr in `<pre>` for newline preservation | 0.5 | RC4 visibility |
| 2 | B | `tests/playwright/test_inception_decide_contract.py` — 3 cases (GO success, GO disposition-blocked, NO-GO success); fixture under-disposed inception; assertions on persistence + actionable-error visibility (≥300 chars + "Options:" recovery block) | 3.0 | G-068 META; RC1-RC4 regression net; pre-empts RC5/RC6 |

**Headline mechanic (§ACD):** *"operator submits GO via Watchtower against a fixture inception with under-disposed Open Questions; CI test fails because the operator-visible HTML truncates the actionable recovery options. The test failing IS the demo that the regression-net works."*

**Recovery for stuck T-2209 (out-of-band, operator-Sovereign):**
1. Add `disposition: …` + `rationale: …` to T-2209's IW-1 and IW-2 Open Questions, then re-click GO at `/inception/T-2209`.
2. OR `FW_SKIP_DISPOSITION_GATE=1 bin/fw task update T-2209 --status work-completed --skip-sovereignty --reason "T-2217 mitigation pending; operator-authorised"` — logged Tier-2.

Either is operator-Sovereign; agent cannot self-authorise.

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

**Rationale**: Filed initially as DEFER (evidence gap); upgraded to GO after candidate analysis landed in `docs/reports/T-2217-watchtower-side-effect-truncation-rca.md` §3-§6.

**Date**: 2026-06-05T20:00:49Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-05T19:52:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5a379f8d
- **Timestamp:** 2026-06-05T19:57:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-05T20:00:49Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Filed initially as DEFER (evidence gap); upgraded to GO after candidate analysis landed in `docs/reports/T-2217-watchtower-side-effect-truncation-rca.md` §3-§6.
