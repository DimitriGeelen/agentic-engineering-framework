---
id: T-2234
name: "incept consumer-update dispatch exercise — fold into AEF"
description: >
  Inception: incept consumer-update dispatch exercise — fold into AEF

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-07T11:45:18Z
last_update: 2026-06-07T11:45:47Z
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
  - ts: '2026-06-07T11:45:47Z'
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
---

# T-2234: incept consumer-update dispatch exercise — fold into AEF

## Problem Statement

A consumer-side dispatch prompt exercise (refactor for vendored-update routing) surfaced 9 threads requiring incorporation into the framework's substrate. The brief routes them as: 5 inception dispositions (A1-A5), 3 Initiative-safe builds (B1 template, B2 upstream-bug filing, B3 do-now-disposed items), and a Sovereign surface (PART C). This inception disposes A1-A5 with file:line evidence, ships B1-B2 under Initiative authority, and surfaces PART C without actioning.

## Assumptions

- Reviewer's prior file:line citations are still valid (no source-file moves since the review report).
- The repo wins on every claim — the brief acknowledges this explicitly.

## Open Questions

- **IW-1: Are `fw update` and `fw upgrade` aliases (one delegates) or divergent implementations of the same re-vendor intent?**
  confidence: 3
  disposition: answered
  rationale: DIVERGENT. lib/update.sh:10 (do_update, 415 LOC, 3 subroutines: do_update + _do_update_vendored + _do_update_git; flags --check --branch --rollback). lib/upgrade.sh:169 (do_upgrade, 1562 LOC, single 10-step function; flags --dry-run --force --strict --no-self-vendor --dedupe-user-hooks --from-upstream --force-downgrade; T-1542 guard w/ T-2232 3-leg fallback at :306-385; post-action _t2094_emit_doctor_advisory at :1527). Top-level dispatch in bin/fw routes them separately (`update)` → sources update.sh; `upgrade)` → sources init.sh + upgrade.sh). Both call do_vendor but via different orchestration. Template uses `fw upgrade` because T-1542 guard message names it and the 10-step process matches consumer-vendored-skewed intent. Disposition for the divergence ITSELF is consolidation debt → Sovereign-gated under arc-004 project-shape-resilience.

- **IW-2: Should `fw_project_context()` (T-1675 §A2 spike) ship as a real `fw shape` verb covering all 4 shapes (incl. consumer-uninitialized + consumer-vendored-skewed)?**
  confidence: 3
  disposition: deferred
  rationale: New top-level CLI route → Sovereign-gated. Evidence: `_detect_fw_mode` (bin/fw:164-187) returns framework-repo|vendored|global|unknown — does NOT distinguish consumer-uninitialized or consumer-vendored-skewed. T-1675 §A2 25-line bash classifier defines all 4 (docs/reports/T-1675-project-shape-resilience-umbrella.md:50-72). Arc-004 project-shape-resilience exists (.context/arcs/project-shape-resilience.yaml, in-progress, headline_mechanic names the 4 shapes). Build slice belongs there. SURFACED to operator for arc-slice scoping.

- **IW-3: Should a `fw --version` floor + network/retry posture become a CROSS-template dispatch-safety preflight convention (one-off vs reusable)?**
  confidence: 3
  disposition: deferred
  rationale: Convention warrants cross-template uptake if confirmed. Evidence: iw-spike-worker.md + iw-slice-worker.md DO have Worker contract sections but NEITHER currently encodes version-floor or network-retry preflight. `fw dispatch-preflight` helper does not exist (`bin/fw help` doesn't show one). Arc-001 dispatch-safety exists (.context/arcs/dispatch-safety.yaml, in-progress). Adopting this would touch agent templates (governance-adjacent) and possibly add a new helper verb. SURFACED to operator under dispatch-safety arc.

- **IW-4: Does the dispatch-safety / shape-resilience loop warrant a canonical envelope schema, or is `fw bus post` (R-NNN, size-gated) the permanent answer?**
  confidence: 2
  disposition: deferred
  rationale: `fw bus post` envelope is in production use (sample .context/bus/results/T-2212/R-001.yaml; schema: id/task_id/agent_type/timestamp/type/summary/size_bytes/payload_ref). No T-1675-specific envelope schema exists in the repo (verified: grep -rn 'evidence.loop\|evidence_loop\|T-1542 evidence' docs/ .context/project/ returns zero). The brief's "feeding a T-1675 evidence loop" presupposed a contract that isn't there. The bus envelope is sufficient substrate; promoting a separate "evidence loop" schema introduces a parallel surface for no clear gain. SURFACED as design question, not pre-judged.

- **IW-5: Does this exercise (a real dispatch template invoking mutating verbs as free text, no gate) constitute F10 motivating evidence for the capability-overlay inception?**
  confidence: 3
  disposition: answered
  rationale: YES. T-2209 capability-overlay inception is in completed/ (status: work-completed, owner: human, workflow_type: inception) but no .context/arcs/capability-overlay.yaml exists — arc Sovereign-blocked on `fw arc create capability-overlay` (per memory). This exercise is an in-the-wild incident of the very pattern the inception would have gated: a dispatch template with free-text instructions to invoke `fw upgrade`, `fw doctor`, `fw upstream report` — all mutating/external verbs — with no capability frontmatter, no tier declaration, no allow-list check. Recorded as evidence in the docs/dispatch-templates/consumer-update-worker.md "Open governance items" section. SURFACED to operator alongside the Sovereign arc-create gate.

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
- [x] PART A — all 5 IW questions disposed with file:line evidence (IW-1 answered, IW-2/3/4 deferred to Sovereign, IW-5 answered)
- [x] PART B1 — refactored consumer-update worker template landed at `docs/dispatch-templates/consumer-update-worker.md` (263 lines), conventions matched to iw-spike-worker.md / iw-slice-worker.md (no frontmatter, opening Worker contract, dispatcher-substituted variables, cited file:line evidence)
- [x] PART B1 — template uses `fw upgrade` (per IW-1 disposition); `fw init --upstream` corrected to plain `fw init` (no such flag exists; auto-detects from framework git remote per lib/init.sh:209-237); MIN_FW_VERSION set to 1.5.0 with rationale
- [x] PART B2 — `--rollback` global-path asymmetry filed via `fw upstream report --label field-report --force`. Issue: https://github.com/DimitriGeelen/agentic-engineering-framework/issues/15
- [x] PART C — Sovereign surface compiled in Recommendation (5 items, each with arc, gate, and recommendation)

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

Brief routes incorporation properly (inception A1-A5 → Initiative-safe B1/B2/B3 → surface C). PART A produces verifiable dispositions per item with file:line evidence; PART B1 is additive doc (new dispatch-template file, conventions matched to iw-*-worker.md); PART B2 files a real defect upstream (lib/update.sh --rollback help/code asymmetry). Sovereign items (A2 shape verb, A3 cross-template preflight, A4 envelope schema, A5 capability-overlay routing, and A1 if divergent) are surfaced not actioned. No new CLI route or governance edit within Initiative scope. Risk low; reversible.

**Evidence:**

- IW-1 verb divergence proven empirically: lib/update.sh:10 (415 LOC, 3 subroutines) vs lib/upgrade.sh:169 (1562 LOC, 10-step single function). Template uses `fw upgrade`.
- IW-2 `_detect_fw_mode` (bin/fw:164-187) returns 3 categories; T-1675 §A2 defines 4 shapes; arc-004 project-shape-resilience exists for the build slice.
- IW-3 iw-spike-worker.md + iw-slice-worker.md verified to lack version-floor preflight; arc-001 dispatch-safety exists for the convention.
- IW-4 `grep -rn 'evidence.loop\|T-1542 evidence' docs/ .context/project/` returns zero. `fw bus post` (.context/bus/results/T-2212/R-001.yaml) is the substrate.
- IW-5 T-2209 in completed/, no .context/arcs/capability-overlay.yaml — Sovereign-blocked on arc create.
- B1 landed at docs/dispatch-templates/consumer-update-worker.md (263 lines, 11.8KB), sibling-conformant.
- B2 issue: https://github.com/DimitriGeelen/agentic-engineering-framework/issues/15 (label-create retry observed but issue created OK).

## PART C — Sovereign surface (operator action required, agent does NOT action)

The brief routes these for human decide. Each below: gate · arc · recommendation.

1. **A1 follow-up — `fw update` / `fw upgrade` consolidation debt**
   - Gate: scoping decision (deprecate one? merge feature sets? document the boundary?)
   - Arc: arc-004 project-shape-resilience
   - Recommendation: **DEFER until v1.7.x sprint** — the divergence is documented in IW-1 disposition + the new template; deprecating either verb is breaking for downstream consumers; merging requires careful semver. Cheap fix now: add a one-line note to each verb's `--help` referencing the other and when to use which.

2. **A2 — Ship `fw_project_context()` as `fw shape` verb (T-1675 §A2 build slice)**
   - Gate: new top-level CLI route → Sovereign `fw arc <slice> create` or directly file build task under arc-004
   - Arc: arc-004 project-shape-resilience
   - Recommendation: **GO** — `_detect_fw_mode` gaps (no consumer-uninitialized / consumer-vendored-skewed distinction) directly cost the template a 4-line `ls`-hand-roll in STEP 1. Build slice is small (25-line bash classifier already specked in T-1675 §A2; promote to `fw shape` verb + 4 bats tests on synthetic fixtures + integration test against this host).

3. **A3 — Cross-template dispatch-safety preflight convention**
   - Gate: governance touch on agent templates + possible new `fw dispatch-preflight` helper
   - Arc: arc-001 dispatch-safety
   - Recommendation: **DEFER until 2 more templates need it** — A3's value is N×M (one convention × N templates); shipping it with only one template (this one) consuming it is premature. When the 2nd dispatch template that needs version-floor + retry-posture appears, promote to convention then.

4. **A4 — Canonical evidence envelope schema?**
   - Gate: design call — extend `fw bus` with `--type` taxonomy for dispatch-loop evidence, or introduce a new envelope?
   - Arc: arc-001 dispatch-safety (or arc-004 if shape-coupled)
   - Recommendation: **NO-GO on a new schema** — `fw bus post` envelope is sufficient; this template uses it. A new schema would be a parallel surface with no demonstrated need. Cheap fix: add a `dispatch-update` / `dispatch-misdispatch` value to the bus envelope's `type:` field if the dispatcher needs to discriminate on the read side.

5. **A5 — Capability-overlay arc create (T-2209 carryover)**
   - Gate: `fw arc create capability-overlay` is Sovereign-only under $CLAUDECODE=1
   - Arc: capability-overlay (does not exist yet)
   - Recommendation: **GO on arc-create** — this exercise is in-the-wild F10 motivating evidence (free-text mutating verbs, no gate). T-2209 inception ALREADY recommended GO and went to completed/. Create the arc + file slices; this template's "Open governance items" §F10 line then has a real arc to point at.

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

### 2026-06-07T11:45:47Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
