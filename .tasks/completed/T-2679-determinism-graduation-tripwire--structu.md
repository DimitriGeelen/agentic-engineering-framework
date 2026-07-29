---
id: T-2679
name: "determinism graduation tripwire — structural enforcement inception"
description: >
  Inception: determinism graduation tripwire — structural enforcement inception

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-07-29T16:08:10Z
last_update: 2026-07-29T16:42:26Z
date_finished: 2026-07-29T16:42:26Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-07-29T16:10:58Z'
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
  - ts: '2026-07-29T16:15:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2679: determinism graduation tripwire — structural enforcement inception

## Problem Statement

The framework's maturity ladder moves work from **stochastic** (agent initiative,
exploration, judgement) to **deterministic** (scripts, gates, cron). The terminal stage
inverts roles: the framework does the work, and the agent becomes an out-of-band monitor
and **exception manager**. That inversion assumes the deterministic tier **fails loudly**.

Nothing enforces this. A deterministic component encodes a world-assumption at authoring
time — store shape, indentation, anchor uniqueness, file layout — and when the world
drifts it keeps executing the stale assumption, exiting 0 with plausible output. Silent
zero is indistinguishable from legitimately empty, so no exception ever reaches the
exception manager, and the monitoring stage has nothing to monitor.

**For whom:** the operator (whose ladder depends on the deterministic tier being
trustworthy) and every future agent session (which will trust exit-0 output as ground
truth, because it has no way not to).

**Why now:** four instances surfaced in a single week (T-2676, T-2677, T-2672, plus the
promote.sh anchor near-miss). T-2677 establishes the severity ceiling — a component dead
for its entire lifetime with zero signal. The per-site fixes were *mitigation*; per G-019
the gap is not closed until *prevention* exists. Registered as **G-071**.

## Assumptions

Registered via `fw assumption add` (see `.context/project/assumptions.yaml`):

- **A-1** — a probe vocabulary of ~3 primitives (count-floor, uniqueness, shape-match)
  covers ≥80% of the known silent-drift class. *Validated by Spike 1.*
- **A-2** — running ~20 assumption probes adds <2s to the daily audit. *Validated by
  Spike 3.*
- **A-3** — the assumption-rail registry does not collide with T-2652's conformance-rail
  generalization scope. *Validated by Spike 2.*

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

- **IW-1: Does a probe vocabulary of ~3 primitives (count-floor, uniqueness, shape-match) cover the known silent-drift class, or does each site need a bespoke probe?**
  confidence: 3
  disposition: answered
  rationale: Spike 1 — 4/4 known sites expressible with no bespoke probe (T-2676 + T-2677 = count-floor, T-2672 = shape-match round-trip, promote.sh anchor = uniqueness). Adjacent T-2674 vendor-includes case is set-completeness, a DIFFERENT class — explicitly excluded, candidate for a 4th primitive later. See docs/reports/T-2679-*.md §Spike 1.

- **IW-2: Is the assumption-rail registry a generalization of the existing conformance-rail registry (one registry, two primitive families) or a separate surface?**
  confidence: 3
  disposition: answered
  rationale: Spike 2 — SEPARATE surface. tools/conformance-registry.yaml is keyed by map_id (contract: "which corpus map has a rail"); a script with no map has no key in that space. Sibling registry keyed by component/script path, reusing the same checker mechanic + audit-section shape (tools/corpus_conformance.py:78-92).

- **IW-3: Does this collide with or subsume T-2652 (conformance-rail generalization inception, GO'd) — merge, sequence, or independent?**
  confidence: 3
  disposition: dissolved
  rationale: Question presupposed T-2652 was in flight; it is COMPLETED (.tasks/completed/T-2652-conformance-rail-generalization--per-map.md), along with T-2654/T-2658/T-2659/T-2664. No scope contention exists — T-2652 is prior art this follows on from, not a competitor. Bonus finding: its registry already mandates loud-fail ("Empty source extraction is a LOAD ERROR — stale anchor must fail loudly"), so Slice 2 reuses that stance rather than inventing one.

- **IW-4: Should graduation-to-deterministic be gate-enforced (author-time, Candidate B) or adoption-led (register probes voluntarily, audit surfaces unprobed components)?**
  confidence: 2
  disposition: deferred
  rationale: Adoption-led for Slices 1-2 by decision (a gate before probes exist would enforce a proxy — the T-1828/G-040 class this task exists to counter). Gate decision revisits at Slice 3 with real adoption data; deferral is deliberate sequencing, not an evidence gap. Recorded in ## Decisions.

- **IW-5: What is the operator-facing exception surface for a tripped probe — audit WARN only, Watchtower panel, or ntfy push (stage-4 out-of-band monitoring)?**
  confidence: 2
  disposition: answered
  rationale: Audit WARN section, mirroring check_map_conformance — prior art, zero new surface, already on the operator's daily path. Spike 4 (full inventory) not run; escalation to Watchtower panel or ntfy revisits IF WARN-noise proves the channel gets ignored, which is itself the failure mode this task guards against.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

**Spike 1 — probe-vocabulary coverage (time-box 45 min, answers IW-1).** Classify the 5
known sites (T-2672 resolve.sh, T-2676 harvest.sh, T-2677 audit counter, promote.sh
anchor ambiguity, G-001 loud-fail site) against the 3 candidate primitives. Success =
≥4/5 expressible without a bespoke primitive.

**Spike 2 — registry collision check (time-box 30 min, answers IW-2 + IW-3).** Read the
T-2652 rail-registry design + the live registry shape; determine whether a
world-assumption probe is a new primitive inside that registry or a sibling file.
Consult 832 via the DM rail if the map-rail contract is affected (it should not be —
different axis).

**Spike 3 — cost measurement (time-box 20 min, validates A-2).** Prototype 5 probes as
shell one-liners against the live stores; measure wall-clock. Success = <2s total.

**Spike 4 — exception-surface survey (time-box 20 min, answers IW-5).** Inventory how
existing loud signals reach the operator today (audit WARN, doctor, Watchtower
/approvals, ntfy) and pick the cheapest that satisfies "out-of-band, agent-independent".

## Technical Constraints

- **Portability (D4)** — probes must run in POSIX shell / python3 already required by
  the framework. No new runtime dependency, no per-host install.
- **Audit budget** — the daily audit is already multi-section and cron-driven; probe
  execution must stay negligible (A-2, <2s for ~20 probes) or it will be silenced.
- **Consumer safety** — probes ship through `fw vendor`, so a probe that assumes
  framework-repo layout will break consumers (the exact freeze class from T-2674's
  status-transitions.yaml omission). Probes must resolve paths via FRAMEWORK_ROOT /
  PROJECT_ROOT conventions (T-2648 / OBS-097 rule).
- **No false-loud** — a tripwire that WARNs on a legitimately-empty store trains the
  operator to ignore the channel. Probes must distinguish "empty because nothing to
  find" from "empty because the pattern no longer matches"; that distinction is the
  whole design problem (count-floor primitive exists for exactly this).
- **832 boundary** — if the registry generalization touches the shared map-rail
  contract, coordinate via the DM rail; do not edit any cross-repo file.

## Scope Fence

**IN scope for this exploration:**
- The enforceable *form* of the graduation-tripwire rule (registry vs gate vs lint).
- Probe-vocabulary design sufficient to express the 5 known drift sites.
- Where the loud signal surfaces to the operator (IW-5).
- Sequencing against T-2652 (merge / sequence / independent).

**OUT of scope (explicitly):**
- Building any of the three candidates — build slices are separate tasks post-GO.
- Retrofitting probes across the whole `lib/` + `agents/` surface. Seeding the 4-5
  evidence sites is Slice 2; wholesale adoption is a later, separately-scoped effort.
- Re-litigating the per-site fixes already shipped (T-2672/T-2676/T-2677 are closed
  mitigation; this task is the prevention leg only).
- Changing the maturity ladder itself or the map-rail (maps-vs-code) contract. This
  inception adds an axis; it does not redefine existing ones.
- Any change to CLAUDE.md prose as the *primary* remediation (Candidate D — rejected by
  the doctrine). Documentation follows a structural mechanism; it does not substitute.

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
- The drift class is shown to be recurring and structurally unpreventable today — **MET**:
  4 instances in one week, 3 of them months-long blind spots, zero detection surface.
- At least one candidate checks *reality* rather than a proxy artifact — **MET**:
  Candidate A (runtime probes against live state), pattern already proven by the
  conformance rails on the maps-vs-code axis.
- A first slice exists that is small, testable, reversible, and delivers value even if
  the keystone is later reshaped — **MET**: Candidate C (silent-zero lint) retires the
  known grep family standalone.
- Probe cost stays negligible in the daily audit (A-2) — *pending Spike 3*.

**NO-GO if:**
- The class turns out to be one-off rather than systemic (it is not — see evidence).
- Every candidate reduces to a proxy check (artifact-exists rather than behaviour-fires),
  i.e. we would be re-shipping the T-1828/G-040 failure mode under a new name.
- Probe design cannot distinguish "legitimately empty" from "pattern no longer matches",
  making every tripwire a false-loud that trains the operator to ignore the channel.
- Scope collides irreconcilably with T-2652 such that two registries would compete for
  the same authority (Spike 2 — expected independent, different axis).

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

**Recommendation:** GO — Candidate A (assumption-rail registry) as keystone, Candidate C (silent-zero lint) as first slice, Candidate B (author-time gate) deferred.

**Rationale:**

Three proven instances of the silent-drift class in one week (T-2672 resolve.sh, T-2676 harvest greps, T-2677 audit counter — all deterministic scripts silently no-oping for months against a drifted store shape) plus the anchor-ambiguity near-miss; the ladder's stage-4 doctrine (agent as out-of-band exception manager) requires the deterministic tier to fail loudly, and today nothing enforces that at graduation time. Conformance rails already prove the reality-check pattern for maps-vs-code; this extends it to script-vs-world.

Candidate A is the only option that checks reality (live behavior) rather than a proxy artifact — it would have caught all four evidence instances, and the rail mechanic is already proven maintainable in this codebase. Candidate C is a cheap same-week win that retires the known grep family while A's probe vocabulary is designed. Candidate B is proxy-shaped (verifies a test exists, not that assumptions still hold) — the T-1828/G-040 class this inception exists to counter — so it is deferred, revisitable once A's probes make registration a legitimate proxy. Candidate D (prose practice in CLAUDE.md) is rejected by the doctrine itself: advisory prose is the failing layer.

Full candidate analysis, evidence table, and dialogue log: `docs/reports/T-2679-determinism-graduation-tripwire.md`

**Evidence:**

- **T-2676** (`lib/harvest.sh`) — 4-space greps against a 2-space live store: "No learnings found in project" on every run for months; 549:0 match ratio. Fixed + 4 bats pins.
- **T-2677** (`agents/audit/audit.sh` §9) — 2-space-only ID grep counted 0 of 550 learnings; the `>=20` promote-suggest branch, the *only* programmatic caller of `fw promote suggest`, **had never fired in its life**. Now WARNs "550 learnings" for the first time.
- **T-2672** (`agents/healing/lib/resolve.sh`) — same indentation-assumption class, third instance, separate site.
- **2026-07-29 near-miss** — parked rail registry entry for `aef-knowledge-leveling` anchored on `if lid in promoted_ids:`, which occurs 3× in `lib/promote.sh`; occurrence-1 extraction returns ZERO tokens. Caught only because the operator's pair-round forced re-derivation; anchor sharpened to the unique status-ladder line (commit 33a9cf844).
- **Severity ceiling proven:** a deterministic component can be dead for its entire lifetime with zero operator-visible signal (T-2677). Exit 0 + plausible output is indistinguishable from success.
- **Remediation pattern already proven here:** conformance rails (arc-014, T-2621+) do exactly this for the maps-vs-code axis, including honest RED state on `aef-dispatch-loop`. This inception generalizes the mechanic to the script-vs-world axis.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-07-29 — Adoption-led before gate-enforced (IW-4)

- **Chose:** Slices 1-2 are adoption-led (components register probes voluntarily; audit
  reports both tripped probes and, later, unprobed deterministic components). The
  author-time gate (Candidate B) is deferred to Slice 3, decided on real adoption data.
- **Why:** a gate shipped *before* probes exist could only check "did this task ship a
  test file" — verifying an artifact rather than a behaviour, which is precisely the
  T-1828 / G-040 proxy class this task exists to counter. Once probes exist, "is a probe
  registered" becomes a legitimate proxy because the probe itself checks reality.
- **Rejected:** gate-first (proxy-shaped, would re-ship the failure mode under a new
  name); never-gate (adoption alone decays — the same "someone will remember" assumption
  that produced the four evidence instances).

### 2026-07-29 — Sibling registry, not a new primitive in the map registry (IW-2)

- **Chose:** a separate registry keyed by component/script path, reusing
  `corpus_conformance.py`'s checker mechanic and audit-section reporting shape.
- **Why:** `tools/conformance-registry.yaml` is keyed by `map_id` — its entry contract is
  "which corpus map has a rail". A deterministic script with no corpus map has no key in
  that space. Sharing the mechanic gets the proven pattern; sharing the *file* would
  force map identity onto things that are not maps.
- **Rejected:** one registry with two primitive families (key-space collision); wholly
  independent tooling (throws away a working checker + audit integration).

### 2026-07-29 — Probes are shell primitives (Spike 3 constraint)

- **Chose:** probe execution is shell-primitive, or parse-requiring probes are batched
  into a single interpreter process per run.
- **Why:** measured 6 ms per shell grep vs 630 ms per `python3 -c yaml.safe_load`. At 20
  probes that is 0.12 s vs 12.6 s — the latter would get the whole mechanism disabled for
  being slow, making the tripwire the next thing to quietly die.
- **Rejected:** per-probe interpreter (blows the audit budget 6× over target).

## Decision

**Decision**: GO

**Rationale**: Three proven instances of the silent-drift class in one week (T-2672 resolve.sh, T-2676 harvest greps, T-2677 audit counter — all deterministic scripts silently no-oping for months against a drifted store shape) plus the anchor-ambiguity near-miss; the ladder's stage-4 doctrine (agent as out-of-band exception manager) requires the deterministic tier to fail loudly, and today nothing enforces that at graduation time. Conformance rails already prove the reality-check pattern for maps-vs-code; this extends it to script-vs-world.

Candidate A is the only option that checks reality (live behavior) rather than a proxy artifact — it would have caught all four evidence instances, and the rail mechanic is already proven maintainable in this codebase. Candidate C is a cheap same-week win that retires the known grep family while A's probe vocabulary is designed. Candidate B is proxy-shaped (verifies a test exists, not that assumptions still hold) — the T-1828/G-040 class this inception exists to counter — so it is deferred, revisitable once A's probes make registration a legitimate proxy. Candidate D (prose practice in CLAUDE.md) is rejected by the doctrine itself: advisory prose is the failing layer.

Full candidate analysis, evidence table, and dialogue log: `docs/reports/T-2679-determinism-graduation-tripwire.md`

**Date**: 2026-07-29T16:37:03Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-29T16:10:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-07-29T16:37:03Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Three proven instances of the silent-drift class in one week (T-2672 resolve.sh, T-2676 harvest greps, T-2677 audit counter — all deterministic scripts silently no-oping for months against a drifted store shape) plus the anchor-ambiguity near-miss; the ladder's stage-4 doctrine (agent as out-of-band exception manager) requires the deterministic tier to fail loudly, and today nothing enforces that at graduation time. Conformance rails already prove the reality-check pattern for maps-vs-code; this extends it to script-vs-world.

Candidate A is the only option that checks reality (live behavior) rather than a proxy artifact — it would have caught all four evidence instances, and the rail mechanic is already proven maintainable in this codebase. Candidate C is a cheap same-week win that retires the known grep family while A's probe vocabulary is designed. Candidate B is proxy-shaped (verifies a test exists, not that assumptions still hold) — the T-1828/G-040 class this inception exists to counter — so it is deferred, revisitable once A's probes make registration a legitimate proxy. Candidate D (prose practice in CLAUDE.md) is rejected by the doctrine itself: advisory prose is the failing layer.

Full candidate analysis, evidence table, and dialogue log: `docs/reports/T-2679-determinism-graduation-tripwire.md`

## Build Slices Authorised by the GO (2026-07-29)

- **T-2680** (horizon `now`) — Slice 1 / Candidate C: silent-zero store-grep detector
  (audit WARN section + reviewer static-scan pattern). Retires the known grep family.
- **T-2681** (horizon `next`) — Slice 2 / Candidate A keystone: assumption-rail registry
  keyed by component path + probe runner (count-floor, uniqueness, shape-match), seeded
  with the four evidence sites. Shell-primitive execution per the Spike 3 constraint;
  loud-fail stance copied from `tools/conformance-registry.yaml`.
- **Slice 3** (graduation wiring + author-time gate decision) — deliberately NOT filed
  yet, gated on Slice 2 adoption data per the IW-4 disposition.

**G-071 stays OPEN** until Slice 2 ships probes that actually fire — per G-019,
mitigation is not prevention, and an inception GO is not a structural change.

**Spike results (all three assumptions validated pre-decision):** A-047 probe vocabulary
covers 4/4 known sites; A-048 cost passes for shell-primitive probes only (0.12s vs
12.6s for per-probe Python); A-049 no T-2652 collision — it is completed prior art whose
registry already mandates loud-fail. Tables in the artifact §Spike Results.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ac9b4dc2
- **Timestamp:** 2026-07-29T16:42:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-5
     - evidence: `IW-5 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-f03d7baf
- **Timestamp:** 2026-07-29T16:42:27Z
- **Overall:** CONFIRMED
- **Claims:** 10

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-2679-determinism-graduation-tripwire.md` | file | ✓ pass |
| `lib/harvest.sh` | file | ✓ pass |
| `agents/audit/audit.sh` | file | ✓ pass |
| `agents/healing/lib/resolve.sh` | file | ✓ pass |
| `lib/promote.sh` | file | ✓ pass |
| `T-2672` | task | ✓ pass |
| `T-2676` | task | ✓ pass |
| `T-2677` | task | ✓ pass |
| `T-1828` | task | ✓ pass |
| `T-2621` | task | ✓ pass |

### 2026-07-29T16:42:26Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
