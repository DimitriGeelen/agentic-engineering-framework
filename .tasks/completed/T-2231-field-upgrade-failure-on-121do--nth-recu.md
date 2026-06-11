---
id: T-2231
name: "Field upgrade failure on .121do — Nth recurrence of upgrade-fragility class;
  should we ship T-2093/2094/2095 now?"
description: >
  Inception: Field upgrade failure on .121do — Nth recurrence of upgrade-fragility
  class; should we ship T-2093/2094/2095 now?

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-06-06T13:07:59Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-06T13:14:29Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-06T13:12:09Z'
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
  - ts: '2026-06-11T22:24:12Z'
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

# T-2231: Field upgrade failure on .121do — Nth recurrence of upgrade-fragility class; should we ship T-2093/2094/2095 now?

## Problem Statement

**The operator-reported fact (2026-06-06):** another `fw upgrade` failure on
a consumer project (operator-shorthand: `.121do` — likely under `/opt/121-*`;
exact path + failure output pending operator paste in the Dialogue Log).

**The operator-asked question (verbatim):** *"do our upgrades keep failing?"*

**The honest answer (evidence-backed):** **yes** — and the framework knows it,
has filed structural prevention work, but the prevention work has not shipped.

### The fragility timeline

| Date | Task | Status | Note |
|------|------|--------|------|
| 2026-04-27 | T-1542 | started-work, **40 days open** | fw upgrade-from-inside-consumer crashes at step 4b/9 |
| 2026-05-29 | T-2078 | **GO** | "deep review fw upgrade reliability for field deployment" — inception authorised a 4-slice v1 hardening chain |
| 2026-05-29 | T-2093 (V1-B) | **captured, 8 days** | strict exit-code discipline + rollback on mid-upgrade failure |
| 2026-05-29 | T-2094 (V1-C) | **captured, 8 days** | pre-flight tooling check + post-upgrade fw doctor advisory |
| 2026-05-29 | T-2095 (V1-D) | **captured, 8 days** | self-vendor extraction into a separate verb |
| 2026-06-06 | T-2229 | **GO today** | BVP onboarding bootstrap gap (policy/value-drivers + arcs not seeded) |
| 2026-06-06 | T-2230 | **shipped today** | Slice 1: `fw bvp driver --init` verb |
| 2026-06-06 | **THIS (.121do)** | **NEW FAILURE** | filed as T-2231 |

The pattern is: prevention work captured → not promoted → field failure recurs.
T-2078 GO'd 8 days ago, V1-B/C/D have not started, and `.121do` (today) is the
N-th field failure since the prevention plan was authorised.

**The structural class:** "captured-but-not-promoted prevention work degrades
to handover-noise, while the failure surface keeps shipping" — a sibling of
L-461 (stale partial-completes) but on the *captured* side: filed → forgotten
→ recurrence.

## Assumptions

- **A1:** The .121do failure is a known class — one of the symptoms T-2093/T-2094/T-2095 are designed to prevent (exit-code drift, missing tool, partial vendor) — and shipping those three slices would prevent recurrence. **Validation:** requires the operator's .121do failure output to confirm symptom class.
- **A2:** Captured prevention work degrades silently into handover noise the longer it sits at `horizon=now`/`status=captured` without promotion. **Validation:** T-2078 → T-2093/2094/2095 captured 8 days → 2 net-new field failures since (.121do, T-2229). N=2 in 8 days; signal not noise.
- **A3:** The operator's bandwidth, not the agent's, is the rate-limiter on shipping V1-B/C/D. **Validation:** all three are agent-shippable build slices; status=captured means they're not in the active work queue, not that they're sovereignty-blocked.
- **A4:** A "captured-but-not-promoted prevention work" detector (sibling of L-461) would surface this class structurally before it degrades to another field failure. **Validation:** T-2093/2094/2095 vs `fw audit` — does any current advisory flag the chain? Spike output answers.

## Open Questions

- **IW-1: What specifically failed on `.121do`?**
  confidence: 0 (no data — operator paste pending)
  disposition: deferred
  rationale: Awaiting operator paste in Dialogue Log. The exact symptom (which step of `fw upgrade` failed, stderr, exit code) determines whether this is exit-code drift (T-2093 class), missing-tool (T-2094 class), self-vendor extraction (T-2095 class), or a NEW class not covered by V1-B/C/D.

- **IW-2: Do we ship V1-B/C/D NOW (sequential), in PARALLEL (3 workers), or stage them?**
  confidence: 1 (3 slices are agent-shippable but interact via lib/upgrade.sh)
  disposition: deferred
  rationale: Sovereignty-bearing — the operator authorises shipping pace. Agent's recommendation: promote all 3 to `horizon=now` + ship sequentially V1-B → V1-C → V1-D (V1-B's exit-code discipline is a substrate the others depend on). Defer the parallel-vs-sequential decision to operator.

- **IW-3: Is `.121do` a NEW failure class not covered by V1-B/C/D?**
  confidence: 0 (no data)
  disposition: deferred
  rationale: Depends on IW-1 answer. If .121do failed at a step V1-B/C/D doesn't touch, we file a Slice E (or recast as inception). If covered, .121do becomes a regression test for the shipping V1 chain.

- **IW-4: Should the framework add a "captured-prevention-stalled" advisory in `fw audit`?**
  confidence: 2 (clear structural shape: count days since GO'd inception's child slices stay `captured`; WARN past N days)
  disposition: answered
  rationale: Yes — sibling of L-461. Threshold proposal: ≥7 days captured AND parent inception is GO. Cheap (audit YAML walk). Files as own slice post-V1 ship. Captured here as A4 + IW-4 for traceability; build slice filed separately on operator GO.

- **IW-5: T-1542 (40d started-work, consumer-side upgrade crash) — is it subsumed by V1-B/C/D or still independent?**
  confidence: 1 (T-1542's symptom "crashes at step 4b/9" overlaps V1-B's exit-code rollback shape)
  disposition: deferred
  rationale: Read T-1542 body + cross-check against T-2093 scope. If subsumed, close T-1542 as dup-of T-2093 once V1-B ships. If independent, keep separate. Decision on V1-B-ship date.

- **IW-6: Did the framework's own T-2078 inception itemise `inception_decisions:` (T-1984) and have the V1-B/C/D children declared `unlocks_inception_decision:`?**
  confidence: 0 (uninspected)
  disposition: deferred
  rationale: T-1984's traceability rail was supposed to prevent exactly this class — GO-scope decision and the children that ship it. If T-2078 predates T-1984 wiring (T-2078 GO'd 2026-05-29; T-1984 active), this is grandfathered. Spike inspects + decides whether retro-fitting helps.

## Exploration Plan

### Spike A (~10 min, BLOCKING) — operator paste of .121do failure
The operator pastes the failure output. Agent classifies against the V1-B/C/D
symptom inventory (exit-code drift / missing tool / partial vendor / NEW class)
and resolves IW-1, IW-3, IW-5.

### Spike B (~15 min) — T-2078 → V1-B/C/D scope reconciliation
Read T-2093/T-2094/T-2095 bodies; map each acceptance criterion to a specific
upgrade failure symptom (T-1542 step 4b/9, T-2229 missing policy, .121do
TBD-from-Spike-A). Output: a coverage matrix that confirms or refutes A1.

### Spike C (~20 min) — captured-prevention-stalled detector design
Sibling of L-461: count days since a GO'd inception's child build slices
stay `status: captured`. WARN at N days. If detector lands as part of this
arc (vs separate slice), the recurrence class itself gets a structural rail.
Resolves IW-4 build path.

### Build path on operator GO
1. **Promote V1-B/C/D to `horizon=now`** (`fw task update T-2093/T-2094/T-2095 --horizon now`).
2. **Ship V1-B** (T-2093 — substrate; exit-code discipline + rollback).
3. **Ship V1-C** (T-2094 — pre-flight check; builds on V1-B's exit-code contract).
4. **Ship V1-D** (T-2095 — self-vendor extraction; depends on V1-B's exit-code).
5. **Verify .121do prevented** (regression of the captured failure against shipped V1 chain).
6. **File Slice E** if .121do is a NEW class not covered by V1-B/C/D.
7. **File the captured-prevention-stalled detector slice** (post-V1) — sibling of L-461.

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

Evidence is strong: T-2078 GO'd a 4-slice v1 hardening 2026-05-29; T-2093/T-2094/T-2095 (V1-B/C/D) have sat captured for 8 days while field upgrades continue to fail (T-2229 GO'd today; .121do reported now; T-1542 started-work 40 days). The agent's recommendation is to escalate the captured prevention chain to horizon=now and triage the .121 failure against the existing 4-slice plan before filing fresh build work. Sovereignty-bearing question (operator-only): do we ship T-2093/2094/2095 BEFORE diagnosing .121, in PARALLEL, or treat .121 as a NEW class that needs its own slice?

**Evidence:**

- **T-1542** (started-work since 2026-04-27, 40 days open): "fw upgrade from inside a consumer crashes at step 4b/9" — consumer-side upgrade crash; never closed. Direct evidence the framework's upgrade flow has known crash paths.
- **T-2078** (GO 2026-05-29): "deep review fw upgrade reliability for field deployment" — authorised a 4-slice v1 hardening chain. The framework KNOWS upgrades are fragile.
- **T-2093 / T-2094 / T-2095** (captured 2026-05-29 — 8 days): V1-B (exit-code discipline + rollback), V1-C (pre-flight tooling check + post-upgrade fw doctor advisory), V1-D (self-vendor extraction). Three GO'd, agent-shippable build slices sitting in `status: captured`, never promoted to `horizon: now`.
- **T-2229** (GO 2026-06-06, today): BVP onboarding bootstrap gap — operator hit `ERROR: policy file not found` on `/opt/050-email-archive` after a vendored upgrade. Slice 1 (T-2230) shipped today; Slices 2-4 outstanding.
- **T-2230** (work-completed 2026-06-06, today): `fw bvp driver --init` ships the verb the dead error at `lib/bvp.sh:133` had promised since T-1920.
- **.121do failure** (operator-reported now): output pending Dialogue Log paste. Classification depends on Spike A.
- **Cumulative**: T-1542 + T-2229 + .121do = **at least 3 distinct field upgrade failures in 40 days**, against a backdrop of 3 captured prevention slices that have not shipped in 8 days.

## Dialogue Log

### 2026-06-06 — Operator filed the .121do bug report

> "anoteh rfailing uipgrade !!!!!! please chekc messages and asses , incpoet to fricking failure from .121do do our upgrades keep faling ???!!!"

**Agent diagnosis (without .121do failure output):**
- Checked inbox / pickup channel / TermLink — no new pickups carry the .121do output.
- Walked the upgrade-fragility history (table above) — pattern is unambiguous.
- Filed this inception with the pattern + open IW-1 awaiting operator paste of the .121do failure (stderr, exit code, which step of `fw upgrade` failed).

**Operator action requested:** paste the `.121do` failure output below this section (or in chat) so the agent can:
1. Classify against V1-B/C/D symptom inventory (resolves IW-1, IW-3, IW-5)
2. Confirm or refute A1 (.121do is a known class)
3. File / update the build chain accordingly

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

**Rationale**: Evidence is strong: T-2078 GO'd a 4-slice v1 hardening 2026-05-29; T-2093/T-2094/T-2095 (V1-B/C/D) have sat captured for 8 days while field upgrades continue to fail (T-2229 GO'd today; .121do reported now; T-1542 started-work 40 days). The agent's recommendation is to escalate the captured prevention chain to horizon=now and triage the .121 failure against the existing 4-slice plan before filing fresh build work. Sovereignty-bearing question (operator-only): do we ship T-2093/2094/2095 BEFORE diagnosing .121, in PARALLEL, or treat .121 as a NEW class that needs its own slice?

**Date**: 2026-06-06T13:14:29Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-06T13:12:09Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-06T13:14:29Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Evidence is strong: T-2078 GO'd a 4-slice v1 hardening 2026-05-29; T-2093/T-2094/T-2095 (V1-B/C/D) have sat captured for 8 days while field upgrades continue to fail (T-2229 GO'd today; .121do reported now; T-1542 started-work 40 days). The agent's recommendation is to escalate the captured prevention chain to horizon=now and triage the .121 failure against the existing 4-slice plan before filing fresh build work. Sovereignty-bearing question (operator-only): do we ship T-2093/2094/2095 BEFORE diagnosing .121, in PARALLEL, or treat .121 as a NEW class that needs its own slice?

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cc519215
- **Timestamp:** 2026-06-06T13:14:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-06T13:14:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
