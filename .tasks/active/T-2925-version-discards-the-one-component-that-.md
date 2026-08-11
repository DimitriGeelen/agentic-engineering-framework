---
id: T-2925
name: "VERSION discards the one component that makes it decidable — what marker should
  a consumer name"
description: >
  Inception: VERSION discards the one component that makes it decidable — what marker
  should a consumer name

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-11T20:37:11Z
last_update: '2026-08-11T20:45:09Z'
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
  - ts: '2026-08-11T20:39:02Z'
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
  - ts: '2026-08-11T20:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2925: VERSION discards the one component that makes it decidable — what marker should a consumer name

## Problem Statement

`VERSION` is stamped by `agents/git/lib/hooks.sh:886-899` from
`git describe --tags`. Today that describe string is `v1.6.765-71-g4cc5852e9`
and the stamped file reads `1.6.71`: the derivation keeps `major.minor` and
`commits-since-tag` and **discards the base tag's own patch component (`765`)**.

Two consequences, both measured (see `docs/reports/T-2925-version-decidability.md`):

1. The third field is a **distance**, not a patch number. It resets to `0` at
   every tag cut, so two VERSION strings are comparable only when computed
   against the same base tag — and the base tag is recorded nowhere. `sort -V`
   over them is L-550: two operands that are not the same quantity, failing
   silently because the failure looks like an answer.
2. The **decidable** string is computed and thrown away. `v1.6.765-71-g4cc5852e9`
   is totally ordered; 33 tags exist. The marker a consumer needs is not
   missing — it is discarded at stamp time.

**For whom:** consumer projects taking a vendor bump. **Why now:** consumer 832
hit it (rail 537 §3), predicted `fw upgrade` would refuse their apparent
downgrade (`1.6.354` → `1.6.9`), and was proved wrong by T-2713's guard, which
correctly reports the relation *undecidable*. Their first bump is therefore an
act of faith, as is every pre-sentinel consumer's.

This is invisible from inside a single tree: within one tag epoch the stamp is
monotone and the T-1603 pre-push hook is satisfied. It is observable only when
two trees with different base tags compare — the consumer-vendor case, which our
corpus has no instance of.

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

- **IW-1: Is the third field of VERSION intended to be a patch number, or is "distance since nearest tag" the deliberate design?**
  confidence: 3
  disposition: answered
  rationale: `agents/git/lib/hooks.sh:894` — `_stamped="${_major_minor}.${_commits}"` where `_commits` is `git describe`'s commits-since-tag. Distance by construction; `1.6.9` is honest, not a mislabel.

- **IW-2: Does a marker already exist that a consumer could name to decide bump direction?**
  confidence: 3
  disposition: answered
  rationale: Yes — `git describe --tags --match 'v[0-9]*'` yields `v1.6.765-71-g4cc5852e9`, totally ordered; 33 tags in-repo, latest `v1.6.765`. It is computed at stamp time and discarded at `hooks.sh:893` (`${_base%.*}`).

- **IW-3: Should the fix widen VERSION itself, or ship a sibling decidable marker alongside it?**
  confidence: 2
  disposition: deferred
  rationale: Recommending Candidate B (sibling marker) because VERSION is read by the T-1603 pre-push hook, `fw upgrade`'s T-1912 precheck, `fw doctor`, and consumer `.framework.yaml` pins — widening its grammar is a coordinated migration across trees we do not control. Deferred to the operator because it is the one choice with cross-consumer blast radius.

- **IW-4: Once decidability is available, should `fw upgrade` REFUSE an undecidable relation rather than warn?**
  confidence: 2
  disposition: deferred
  rationale: Sovereignty call, not technical — refusing strands every legacy consumer until they re-vendor once. Explicitly out of scope for this inception's GO; named so it is not silently inherited by the build slice. **Consumer input received** (832, rail 539 §2), recorded as input and not as a vote: *"refusing undecidable strands every pre-sentinel consumer until they re-vendor once, and the one bump that cannot be checked is the one that would be refused. Warn-and-proceed plus a recorded `version_sha` converges after a single bump; refusal blocks precisely the population that has no way to comply. I would ship B warning, and revisit refusal once the marker has propagated."* That argument is stronger than the one I filed — the refused set and the non-compliant set are the *same* set, so refusal has no path out of itself. Confidence raised 1→2 on that basis; disposition stays `deferred` because it remains the operator's call, and the party arguing is the party exposed.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** the VERSION stamp derivation (`hooks.sh:886-899`); what marker a
consumer can name to decide bump direction; the readers that would consume it
(`fw upgrade` T-1912 precheck, T-2713 undecidability guard).

**OUT:**
- Changing the tag cadence (33 tags, with a jump `v1.6.10` → `v1.6.761`
  suggesting two regimes — noted as an operator question, not explored here).
- Making `fw upgrade` refuse on undecidable (IW-4 — deferred, sovereignty).
- Any claim that a consumer has actually been downgraded. Not sought, not found.
  The claim is that a consumer *cannot tell*, which is smaller and sufficient.
- T-2713 itself. It is correct and is the reason the undecidability surfaced
  rather than being silently mis-resolved; this builds on it.

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

**Recommendation:** GO

**Rationale:**

Measured: agents/git/lib/hooks.sh:886-899 derives VERSION from 'git describe --tags' (today v1.6.765-71-g4cc5852e9) and keeps only major.minor plus commits-since-tag, discarding the base tag's patch component (765). The third field is therefore a DISTANCE that resets to 0 at every tag cut, not a patch number — so two VERSION strings are comparable only when computed against the same base tag, and nothing records which base tag was used. 33 tags exist; the decidable string is already in hand at stamp time and is thrown away. Consequence surfaced by consumer 832: their vendored 1.6.354 vs our 1.6.9 is undecidable, T-2713 correctly reports it so, and their first vendor bump is an act of faith. GO because the defect is confirmed by measurement rather than suspected, and because the fix is blocked on a design choice (widen VERSION vs ship a sibling decidable marker) that changes every consumer pin and the T-1603 monotonicity hook — which is exactly what an inception is for.

**Evidence:**

- `agents/git/lib/hooks.sh:886-899` — the derivation. Line 893
  (`_major_minor="${_base%.*}"`) is where `765` is discarded; line 894 composes
  `major.minor` with the distance.
- Measured live in this tree: `git describe --tags --match 'v[0-9]*'` →
  `v1.6.765-71-g4cc5852e9`; `cat VERSION` → `1.6.71`. The `765` appears in one
  and not the other.
- `git tag | wc -l` → 33; latest `v1.6.765`. The tag 832 could not find for
  *their* stamped `1.6.354` genuinely does not exist, because `354` was never a
  tag — it was a distance.
- Consumer report: DM rail offset 537 §3 (832). Their `fw upgrade --dry-run`
  from a read-only clone reported the relation undecidable and proceeded —
  T-2713 behaving correctly.
- Recommendation candidates A–D with costs: `docs/reports/T-2925-version-decidability.md` §4.

**Recommendation is Candidate B** (sibling decidable marker, VERSION grammar
unchanged): the only candidate that makes the *first* bump decidable without a
coordinated migration across consumer trees we cannot schedule.

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

### 2026-08-11T20:39:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
