---
id: T-2757
name: "fw upgrade does not ship the pinned Workflow Designer to consumers — install
  guidance dead-ends"
description: >
  After fw upgrade, a consumer has no designer build and the only guidance is 'fw
  designer sync --from <delivered-artifact>' with no stated artifact source. Decide
  whether upgrade/vendor should include the pinned designer by default.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-08-03T10:09:39Z
last_update: 2026-08-03T15:26:14Z
date_finished: 2026-08-03T15:26:14Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-08-03T10:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T10:15:12Z'
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

# T-2757: fw upgrade does not ship the pinned Workflow Designer to consumers — install guidance dead-ends

## Problem Statement

A consumer that has just run `fw upgrade` has a `policy/designer-pin.yaml` naming a
build it does not possess. Every `/designer` route serves a placeholder at HTTP 200,
and the only guidance offered is:

    NOT SYNCED — 832 must deliver the build, then: fw designer sync --from <file>

That instruction names no source. The consumer cannot act on it: it does not say where
the artifact lives, how to request it, or when to expect it. `fw designer sync
--from-tag` *does* know the source (`ssh://git@192.168.10.201:6611/workflow-designer`)
but that is a LAN repo — reachable from this host, not from an arbitrary consumer, and
the guidance never states that precondition.

So the question is not "how do we word the message better". It is whether the artifact
should be absent at all.

**Why now:** the two most recent additions to `do_vendor`'s `includes` array are both
the same class of defect — T-2656 (secret-scan pattern files omitted → consumer's
scanner ran patternless, a silent no-op) and T-2674 (`status-transitions.yaml` omitted
→ consumer enums frozen at vendor-seed time). Both were found only after a consumer
degraded silently. The designer is the third instance, still open.

## Assumptions

- **A1 — the pinned build is self-contained.** If it needs network fetches at runtime,
  vendoring the HTML alone would not unblock a consumer.
  *Tested:* `policy/designer-pin.yaml:115` declares offline-hardened (woff2 embedded,
  no external deps). Single-file HTML. **Holds.**
- **A2 — the pin is already reaching consumers.** If not, vendoring the artifact
  without the pin would still leave the consumer unable to resolve which build to serve.
  *Tested:* `policy` IS in the `includes` array (`bin/fw:337`), so
  `policy/designer-pin.yaml` already ships. Only the artifact is missing. **Holds.**
- **A3 — the artifact is small enough to vendor per-consumer.**
  *Tested:* pinned build is 903,600 bytes; sha256 matches the pin exactly
  (`cab3c75183979b0e…`). The full directory is 7.6 MB across 9 builds — so this turns
  on shipping *the pinned build only*, not the directory. **Holds, conditionally.**
- **A4 — vendoring creates no maintenance obligation.** Read-only contract
  (`install -m 0444`), never edited in place, improvements route upstream to 832
  (`vendor/designer/README.md:6-13`). **Holds.**

## Open Questions

- **IW-1: Should `fw upgrade` ship the pinned Designer build to consumers by default?**
  confidence: 3
  disposition: answered
  rationale: Yes. `vendor` is absent from the `includes` array (`bin/fw:332-356`,
  verified — the 4 grep hits in that range are prose inside T-2656/T-2674 comments,
  not entries). The consumer therefore receives the pin but not the artifact it names.
  A1/A2/A4 all hold, so the only cost is bytes, and A3 bounds that at 903.6 KB.

- **IW-2: Ship the whole `vendor/designer/` directory, or the pinned build only?**
  confidence: 3
  disposition: answered
  rationale: Pinned build only — 903.6 KB vs 7.6 MB (measured: `du -sh vendor/designer/`,
  9 `.html` builds). The 8 historical builds serve archival/rollback purposes for the
  framework repo itself; a consumer serves exactly one build at runtime
  (`web/blueprints/designer.py:_serve_bundle` reads `vendored_path` from the pin). A
  blanket directory include would be an 8× payload increase for zero consumer-visible
  capability.

- **IW-3: Does shipping the artifact change the pin-bump workflow?**
  confidence: 2
  disposition: answered
  rationale: No. Framework upgrades already refresh `policy/designer-pin.yaml`; the
  matching artifact becomes a companion of the same refresh. A consumer adopting a
  *newer* pin than its framework still uses `fw designer sync --from-tag`, unchanged.
  Confidence 2 rather than 3: not exercised end-to-end against a real consumer with a
  pin-bump straddling an upgrade — that is build-slice verification work, not an
  inception blocker.

- **IW-4: Should the placeholder guidance be fixed regardless of the vendoring decision?**
  confidence: 3
  disposition: answered
  rationale: Yes, and it is separable. Even with vendoring shipped, the placeholder is
  still reachable (pin bumped ahead of the vendored artifact, or artifact removed).
  A message that names no source is a dead end in every one of those states. This is a
  second, smaller build slice — it does not gate IW-1.

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

## Exploration Plan

Dispatched to an isolated TermLink worker (context-isolation: the sweep reads
`bin/fw`, `agents/designer/`, `web/blueprints/designer.py`, `policy/designer-pin.yaml`
and `vendor/designer/` — a large read set for a yes/no question). Worker report:
`docs/reports/T-2757-designer-consumer-vendoring.md`.

Every load-bearing claim in that report was then re-verified directly in this session
rather than taken on trust:

| Claim | Re-verification | Result |
|-------|-----------------|--------|
| `vendor` absent from `includes` | read `bin/fw:330-360` | confirmed — 4 grep hits are comment prose |
| pin sha / size | `sha256sum` + `ls -la` vs `policy/designer-pin.yaml` | exact match, 903,600 bytes |
| directory cost | `du -sh vendor/designer/`, count `*.html` | 7.6 MB / 9 builds |
| `policy/` already vendored | read `includes` array | confirmed at `bin/fw:337` |

## Technical Constraints

- Consumers cannot be assumed to reach `ssh://git@192.168.10.201:6611/workflow-designer`
  — it is a LAN origin. Any guidance that depends on it must say so.
- The vendored artifact is installed `0444`. A copy step must not assume it can
  overwrite in place without clearing the mode first.
- `vendor/designer/` is a *frozen deliverable* boundary (T-559 class): AEF vendors 832's
  RELEASED build and never its source. Nothing here reads 832's working tree.

## Scope Fence

**IN:** whether `fw upgrade` / `do_vendor` should ship the pinned build; which builds;
whether the not-synced guidance is separable.

**OUT:** changing the pin, changing the designer itself, building a delivery workflow
for consumers that cannot reach the LAN origin, and the `fw designer sync --from-tag`
intake path (already works, unchanged by this decision).

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

**Recommendation:** GO — ship the pinned build only (not the directory)

**Rationale:**

The DEFER this replaces was a genuine evidence gap, and it is now closed. All three
unknowns it named have measured answers: `do_vendor` does not copy `vendor/` (verified
in `bin/fw:332-356`), 903.6 KB is the marginal cost when scoped to the pinned build
(measured), and there is no consumer-reachable artifact source at all — the only one
that exists is a LAN repo.

The decisive evidence is not the size or the convenience. It is that **the consumer
already receives the pin naming a file it does not have.** `policy/` ships;
`vendor/designer/` does not. That is not a missing feature, it is an internally
inconsistent payload — the consumer is handed a pointer and no referent, and the
resulting placeholder returns HTTP 200, so nothing anywhere reports a problem.

This is the third instance of one class, and the previous two are documented in
comments *inside the very array that omits it*:

- **T-2656** — secret-scan pattern files omitted → consumer's scanner ran patternless.
  A silent no-op.
- **T-2674** — `status-transitions.yaml` omitted → consumer enums froze at seed time.
- **T-2757 (this)** — designer artifact omitted → every `/designer` route serves a
  placeholder at 200.

Each shipped a consumer that was structurally incomplete while reporting success. Two
were fixed by adding the missing file to `includes`; the same remedy applies here.

Scoping to the pinned build is what makes this cheap: 903.6 KB against 7.6 MB for the
directory. A consumer serves exactly one build — `_serve_bundle()` resolves
`vendored_path` from the pin — so the other eight are archival weight with no
consumer-visible capability.

**Evidence:**
- `bin/fw:332-356` — `includes` array; `vendor` absent (4 grep hits in range are prose
  in the T-2656/T-2674 comments)
- `bin/fw:337` — `policy` present, so the pin already ships without its referent
- `sha256sum vendor/designer/aef-workflow-designer-0.8.0.html` →
  `cab3c75183979b0e15e23192518f9360ea12fe33b6a4f78641d7e264f6110935`, exact match to
  `policy/designer-pin.yaml:20`; 903,600 bytes, matching the declared `bytes:`
- `du -sh vendor/designer/` → 7.6 MB across 9 `.html` builds
- `web/blueprints/designer.py:100-107` — missing artifact → `_placeholder()` at HTTP 200
- `agents/designer/designer.sh:76` — the sourceless "832 must deliver" guidance
- `vendor/designer/README.md:6-13` — read-only `0444` contract, no maintenance burden
- Worker report: `docs/reports/T-2757-designer-consumer-vendoring.md`

**Proposed build slices on GO:**
1. Add the pinned artifact to the vendor payload — filtered to `vendored_path` from the
   pin, not a blanket `vendor/designer` include. Guard test: a vendored consumer's
   `/designer` serves the real bundle, not the placeholder. This must assert on the
   *served bytes*, not on file presence — the placeholder's 200 is exactly what makes
   presence-only checks vacuous here.
2. Fix the not-synced guidance to name a source and state the LAN-reachability
   precondition (IW-4). Independent of slice 1 — the placeholder stays reachable when a
   pin is bumped ahead of the artifact.

Slice 1 alone closes the reported symptom; slice 2 stops the message dead-ending in the
states that remain.

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

**Rationale**: Recommendation: GO — ship the pinned build only (not the directory)

Rationale:

The DEFER this replaces was a genuine evidence gap, and it is now closed. All three
unknowns it named have measured answers: `do_vendor` does not copy `vendor/` (verified
in `bin/fw:332-356`), 903.6 KB is the marginal cost when scoped to the pinned build
(measured), and there is no consumer-reachable artifact source at all — the only one
that exists is a LAN repo.

The decisive evidence is not the size or the convenience. It is that the consumer
already receives the pin naming a file it does not have. `policy/` ships;
`vendor/designer/` does not. That is not a missing feature, it is an internally
inconsistent payload — the consumer is handed a pointer and no referent, and the
resulting placeholder returns HTTP 200, so nothing anywhere reports a problem.

This is the third instance of one class, and the previous two are documented in
comments inside the very array that omits it:

- T-2656 — secret-scan pattern files omitted → consumer's scanner ran patternless.
  A silent no-op.
- T-2674 — `status-transitions.yaml` omitted → consumer enums froze at seed time.
- T-2757 (this) — designer artifact omitted → every `/designer` route serves a
  placeholder at 200.

Each shipped a consumer that was structurally incomplete while reporting success. Two
were fixed by adding the missing file to `includes`; the same remedy applies here.

Scoping to the pinned build is what makes this cheap: 903.6 KB against 7.6 MB for the
directory. A consumer serves exactly one build — `_serve_bundle()` resolves
`vendored_path` from the pin — so the other eight are archival weight with no
consumer-visible capability.

Evidence:
- `bin/fw:332-356` — `includes` array; `vendor` absent (4 grep hits in range are prose
  in the T-2656/T-2674 comments)
- `bin/fw:337` — `policy` present, so the pin already ships without its referent
- `sha256sum vendor/designer/aef-workflow-designer-0.8.0.html` →
  `cab3c75183979b0e15e23192518f9360ea12fe33b6a4f78641d7e264f6110935`, exact match to
  `policy/designer-pin.yaml:20`; 903,600 bytes, matching the declared `bytes:`
- `du -sh vendor/designer/` → 7.6 MB across 9 `.html` builds
- `web/blueprints/designer.py:100-107` — missing artifact → `_placeholder()` at HTTP 200
- `agents/designer/designer.sh:76` — the sourceless "832 must deliver" guidance
- `vendor/designer/README.md:6-13` — read-only `0444` contract, no maintenance burden
- Worker report: `docs/reports/T-2757-designer-consumer-vendoring.md`

Proposed build slices on GO:
1. Add the pinned artifact to the vendor payload — filtered to `vendored_path` from the
   pin, not a blanket `vendor/designer` include. Guard test: a vendored consumer's
   `/designer` serves the real bundle, not the placeholder. This must assert on the
   served bytes, not on file presence — the placeholder's 200 is exactly what makes
   presence-only checks vacuous here.
2. Fix the not-synced guidance to name a source and state the LAN-reachability
   precondition (IW-4). Independent of slice 1 — the placeholder stays reachable when a
   pin is bumped ahead of the artifact.

Slice 1 alone closes the reported symptom; slice 2 stops the message dead-ending in the
states that remain.

**Date**: 2026-08-03T15:26:14Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-03T11:40:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-03T15:26:14Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — ship the pinned build only (not the directory)

Rationale:

The DEFER this replaces was a genuine evidence gap, and it is now closed. All three
unknowns it named have measured answers: `do_vendor` does not copy `vendor/` (verified
in `bin/fw:332-356`), 903.6 KB is the marginal cost when scoped to the pinned build
(measured), and there is no consumer-reachable artifact source at all — the only one
that exists is a LAN repo.

The decisive evidence is not the size or the convenience. It is that the consumer
already receives the pin naming a file it does not have. `policy/` ships;
`vendor/designer/` does not. That is not a missing feature, it is an internally
inconsistent payload — the consumer is handed a pointer and no referent, and the
resulting placeholder returns HTTP 200, so nothing anywhere reports a problem.

This is the third instance of one class, and the previous two are documented in
comments inside the very array that omits it:

- T-2656 — secret-scan pattern files omitted → consumer's scanner ran patternless.
  A silent no-op.
- T-2674 — `status-transitions.yaml` omitted → consumer enums froze at seed time.
- T-2757 (this) — designer artifact omitted → every `/designer` route serves a
  placeholder at 200.

Each shipped a consumer that was structurally incomplete while reporting success. Two
were fixed by adding the missing file to `includes`; the same remedy applies here.

Scoping to the pinned build is what makes this cheap: 903.6 KB against 7.6 MB for the
directory. A consumer serves exactly one build — `_serve_bundle()` resolves
`vendored_path` from the pin — so the other eight are archival weight with no
consumer-visible capability.

Evidence:
- `bin/fw:332-356` — `includes` array; `vendor` absent (4 grep hits in range are prose
  in the T-2656/T-2674 comments)
- `bin/fw:337` — `policy` present, so the pin already ships without its referent
- `sha256sum vendor/designer/aef-workflow-designer-0.8.0.html` →
  `cab3c75183979b0e15e23192518f9360ea12fe33b6a4f78641d7e264f6110935`, exact match to
  `policy/designer-pin.yaml:20`; 903,600 bytes, matching the declared `bytes:`
- `du -sh vendor/designer/` → 7.6 MB across 9 `.html` builds
- `web/blueprints/designer.py:100-107` — missing artifact → `_placeholder()` at HTTP 200
- `agents/designer/designer.sh:76` — the sourceless "832 must deliver" guidance
- `vendor/designer/README.md:6-13` — read-only `0444` contract, no maintenance burden
- Worker report: `docs/reports/T-2757-designer-consumer-vendoring.md`

Proposed build slices on GO:
1. Add the pinned artifact to the vendor payload — filtered to `vendored_path` from the
   pin, not a blanket `vendor/designer` include. Guard test: a vendored consumer's
   `/designer` serves the real bundle, not the placeholder. This must assert on the
   served bytes, not on file presence — the placeholder's 200 is exactly what makes
   presence-only checks vacuous here.
2. Fix the not-synced guidance to name a source and state the LAN-reachability
   precondition (IW-4). Independent of slice 1 — the placeholder stays reachable when a
   pin is bumped ahead of the artifact.

Slice 1 alone closes the reported symptom; slice 2 stops the message dead-ending in the
states that remain.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bcff13fe
- **Timestamp:** 2026-08-03T15:26:15Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  3. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-6ecedea8
- **Timestamp:** 2026-08-03T15:26:15Z
- **Overall:** CONTRADICTED
- **Claims:** 7

| Claim | Type | Status |
|-------|------|--------|
| `policy/designer-pin.yaml:20` | file_line | ✓ pass |
| `web/blueprints/designer.py:100-107` | file | ✗ fail — file not found at PROJECT_ROOT |
| `agents/designer/designer.sh:76` | file_line | ✓ pass |
| `vendor/designer/README.md:6-13` | file | ✗ fail — file not found at PROJECT_ROOT |
| `docs/reports/T-2757-designer-consumer-vendoring.md` | file | ✓ pass |
| `T-2656` | task | ✓ pass |
| `T-2674` | task | ✓ pass |

### 2026-08-03T15:26:14Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
