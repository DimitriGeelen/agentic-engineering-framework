---
id: T-2229
name: "Onboarding bootstrap gap — fw upgrade/init/vendor don't seed policy/value-drivers.yaml
  + .context/arcs/"
description: >
  Inception: Onboarding bootstrap gap — fw upgrade/init/vendor don't seed policy/value-drivers.yaml
  + .context/arcs/

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-06-06T12:13:52Z
last_update: '2026-06-11T22:24:12Z'
date_finished: 2026-06-06T12:29:24Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-06T12:15:03Z'
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
cost_estimate_proposed:
  - ts: '2026-06-06T12:15:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2229: Onboarding bootstrap gap — fw upgrade/init/vendor don't seed policy/value-drivers.yaml + .context/arcs/

## Problem Statement

**The gap (operator-confirmed 2026-06-06):** AEF's onboarding flow (`fw init`,
`fw upgrade`, `fw vendor`) does not bootstrap consumer-side BVP/arc state.
Specifically:

1. `policy/value-drivers.yaml` is per-consumer (each project's value drivers may
   differ — sovereignty boundary), but no onboarding verb creates a default
   policy file. Every consumer's first interaction with `fw bvp` hits:
   ```
   ERROR: policy file not found: <PROJECT>/policy/value-drivers.yaml
          Run T-1917 first (or `fw bvp driver --init` once T-1920 ships).
   ```
2. `.context/arcs/` is per-consumer arc state. Never created at onboarding.
   `fw bvp arcs`, `fw arc create`, `fw arc list` all assume it exists.
3. The error message at `lib/bvp.sh:133` references `fw bvp driver --init` as
   "once T-1920 ships". T-1920 SHIPPED (mutating verbs: weight/driver --add/
   --remove), but the `--init` flag was descoped or never built. The error
   points consumers at a dead command.
4. Existing 12 task files in framework repo with `bvp_scores` frontmatter are
   upstream framework-dev leakage (vendored to consumers as historic data),
   NOT consumer scoring runs — they don't represent consumer intent.

**Live evidence:** `/opt/050-email-archive` (vendored AEF 1.6.260) hits this
exact failure mode: `fw bvp` errors, `.context/arcs/` absent, `fw bvp driver
--init` is not a verb.

**Why now:** Adopting AEF should produce a working system. The current state
means every consumer must manually bootstrap two structural pieces with no
documentation telling them how. This is a Reliability (D2) and Usability (D3)
violation per the four constitutional directives.

**Three onboarding shapes** (each may need different bootstrap behaviour):

| Verb | Use case | Current BVP/arc bootstrap |
|------|----------|---------------------------|
| `fw init` | greenfield new project | none |
| `fw upgrade` | upgrade existing AEF consumer | none |
| `fw vendor` | first-time vendor sync (in-place adoption of existing codebase) | none |

The vendor case is the most subtle — existing codebases being adopted into AEF
governance have NO history to seed value drivers from. The greenfield init case
has the operator's intent fresh; the upgrade case may already have a
consumer-authored policy file that must not be overwritten.

## Assumptions

- **A1**: every consumer wants BVP (could be wrong — some projects may prefer
  to opt out entirely). Register: `fw assumption add 'Every consumer wants
  BVP enabled by default' --task T-2229`
- **A2**: D1-D4 default weights (3,5,5,4 from framework
  `policy/value-drivers.yaml`) are a reasonable starting point for any project
  (could be wrong for domain-specific consumers; D4 portability may matter
  less for a single-machine internal tool)
- **A3**: idempotency is the right default — bootstrap only when the file
  doesn't already exist; never overwrite. Operator-edited weights survive
  every `fw upgrade`
- **A4**: `.context/arcs/` should be created as an empty directory with a
  README explaining the arc concept and pointing at `fw arc create`
- **A5**: `fw upgrade` should be safe to run repeatedly without modifying
  consumer-authored policy — confirmed needed by T-1633/T-1635 (consumer-fresh
  upgrade simulation gate)

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

- **IW-1: Where should the bootstrap call live — one shared verb (`fw bvp driver --init`) called from each onboarding path, or copy-paste into each onboarding script?**
  confidence: 2
  disposition: answered
  rationale: One shared verb. `fw bvp driver --init` was promised by T-1920's error message but never built; ship it now and call from `fw init` / `fw upgrade` / `fw vendor`. Single source of truth for default policy + idempotency check. Sibling to T-1633's consumer-fresh discipline — shared helper, multiple consumers (L-249).

- **IW-2: How should the existing-codebase ingest path differ from greenfield `fw init`?**
  confidence: 1
  disposition: deferred
  rationale: Needs a spike (Spike B). Greenfield has operator intent fresh; ingest may want a "scan + suggest" pass (look at language/framework/test density to bias which drivers matter — e.g. high test density → bump D2 Reliability default). Defer to build-time investigation; for v1 ship the same default for all three verbs, surface the customization affordance as a follow-up.

- **IW-3: Should the bootstrap include `bvp_scores:` defaults for any tasks, or only the policy file?**
  confidence: 3
  disposition: answered
  rationale: Only the policy file. Per-task `bvp_scores:` is a sovereignty boundary (`fw bvp confirm --i-am-human`); the estimator produces `bvp_scores_proposed:` separately. Bootstrap seeds the rubric, not the scores. The 12 leakage entries on existing tasks reinforce this — they're upstream history, not consumer intent.

- **IW-4: Should `.context/arcs/` include a starter arc, or be empty?**
  confidence: 2
  disposition: answered
  rationale: Empty + README. Arc creation is operator-driven (`fw arc create` is Sovereign under $CLAUDECODE=1 per G-062). A starter arc would presume intent; an empty directory + README ("create your first arc via `fw arc create <slug>`") respects sovereignty.

- **IW-5: How does this interact with the `T-1633/T-1635` consumer-fresh upgrade simulation gate?**
  confidence: 2
  disposition: answered
  rationale: This inception's build slices must extend `tests/unit/upgrade_fresh_machine_simulation.bats` to assert (a) `fw upgrade` from a synthetic consumer creates `policy/value-drivers.yaml`, (b) `.context/arcs/` exists, (c) re-running `fw upgrade` does NOT overwrite operator-edited policy. The L-1633 rule ("every consumer-facing flow must run from a clean environment with no developer artifacts") naturally extends to bootstrap.

- **IW-6: Opt-out path — how does a consumer say "I don't want BVP"?**
  confidence: 1
  disposition: deferred
  rationale: Spike C — investigate whether `FW_BVP_DISABLED=1` env (per-session) or `.framework.yaml` config flag (per-project) is the right surface. Most consumers will want BVP; opt-out is a long-tail. Defer to build-time UX decision.

## Exploration Plan

**Spike A (gating Slice 1, ~20 min):** regex audit of `policy/` and
`.context/arcs/` references across `lib/init.sh`, `lib/upgrade.sh`, `bin/fw`
vendor path. Identify every surface that needs the bootstrap call. Output:
list of file:line pairs with current behaviour + insertion point per file.

**Spike B (gating Slice 2 / IW-2 ingest UX, ~30 min):** examine three real
consumers (`/opt/050-email-archive`, `/opt/termlink`, `/opt/003-NTB-ATC-Plugin`)
to understand whether default D1-D4 weights serve their workloads or whether
ingest needs "scan + suggest" bias. Output: weight-distribution analysis +
ingest-shape recommendation.

**Spike C (gating Slice 4 / IW-6 opt-out, ~15 min):** survey existing
`FW_*` env vars + `.framework.yaml` config keys for the opt-out pattern that
fits. Output: chosen surface + rationale.

**Build slices on GO (post-spike):**

- **Slice 1 — `fw bvp driver --init`:** ship the verb that creates
  `policy/value-drivers.yaml` from framework template, idempotent
  (refuses if file exists unless `--force`). Update lib/bvp.sh:133 error
  message to point at the working verb. ~80-120 LoC + bats.

- **Slice 2 — wire into onboarding:** `fw init`, `fw upgrade`, `fw vendor`
  all call `fw bvp driver --init` idempotently. `.context/arcs/` directory
  created with README. ~60-100 LoC across the three surfaces.

- **Slice 3 — consumer-fresh simulation gate extension:** extend
  `tests/unit/upgrade_fresh_machine_simulation.bats` to assert BVP + arc
  bootstrap on fresh consumer. Closes the structural gap that allowed
  T-2229 to ship in the first place. ~40 LoC.

- **Slice 4 — opt-out + ingest UX** (post-Spike B/C): per the deferred
  IW-2 / IW-6 decisions.

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

Every fresh consumer of fw upgrade/init hits ERROR: policy file not found: <PROJECT>/policy/value-drivers.yaml the first time anything touches BVP, and 'fw bvp arcs' silently returns empty because .context/arcs/ never gets created. The error message at lib/bvp.sh:133 also points consumers at 'fw bvp driver --init once T-1920 ships' — T-1920 shipped 2026-06-XX with the mutating verbs (weight/driver --add/--remove) but the --init flag was descoped or never built, so the error is a dead reference. Operator confirmed live: /opt/050-email-archive on a vendored 1.6.260 consumer hits this exact failure mode (12 task files carry bvp_scores frontmatter from upstream framework-dev leakage, not consumer scoring runs). Recommendation GO because: (a) bug is operator-confirmed and structural, every consumer hits it; (b) the fix shape is constrained enough to be evaluable now (idempotent bootstrap in fw init for greenfield + fw upgrade/vendor for adoption); (c) sovereignty-respecting because consumer can opt-out or override drivers post-bootstrap; (d) clean composition with T-1633/T-1635 consumer-fresh-machine simulation gate which would have caught this had it covered the BVP surface. Build slices to negotiate post-GO: (1) ship 'fw bvp driver --init' for explicit consumer bootstrap, (2) wire init/upgrade/vendor to call it idempotently, (3) seed .context/arcs/ directory with a README, (4) fix the stale error message, (5) consider an opt-out flag for projects that don't want BVP at all, (6) treat existing-codebase ingest (non-greenfield fw init) separately from upgrade. Spike A: regex audit of what 'policy/' and '.context/arcs/' references already exist in the upgrade/init code paths to identify all the surfaces that need the bootstrap call.

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

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale:

Every fresh consumer of fw upgrade/init hits ERROR: policy file not found: <PROJECT>/policy/value-drivers.yaml the first time anything touches BVP, and 'fw bvp arcs' silently returns empty because .context/arcs/ never gets created. The error message at lib/bvp.sh:133 also points consumers at 'fw bvp driver --init once T-1920 ships' — T-1920 shipped 2026-06-XX with the mutating verbs (weight/driver --add/--remove) but the --init flag was descoped or never built, so the error is a dead reference. Operator confirmed live: /opt/050-email-archive on a vendored 1.6.260 consumer hits this exact failure mode (12 task files carry bvp_scores frontmatter from upstream framework-dev leakage, not consumer scoring runs). Recommendation GO because: (a) bug is operator-confirmed and structural, every consumer hits it; (b) the fix shape is constrained enough to be evaluable now (idempotent bootstrap in fw init for greenfield + fw upgrade/vendor for adoption); (c) sovereignty-respecting because consumer can opt-out or override drivers post-bootstrap; (d) clean composition with T-1633/T-1635 consumer-fresh-machine simulation gate which would have caught this had it covered the BVP surface. Build slices to negotiate post-GO: (1) ship 'fw bvp driver --init' for explicit consumer bootstrap, (2) wire init/upgrade/vendor to call it idempotently, (3) seed .context/arcs/ directory with a README, (4) fix the stale error message, (5) consider an opt-out flag for projects that don't want BVP at all, (6) treat existing-codebase ingest (non-greenfield fw init) separately from upgrade. Spike A: regex audit of what 'policy/' and '.context/arcs/' references already exist in the upgrade/init code paths to identify all the surfaces that need the bootstrap call.

Evidence:

**Date**: 2026-06-06T12:29:24Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-06T12:17:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-06T12:29:24Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

Every fresh consumer of fw upgrade/init hits ERROR: policy file not found: <PROJECT>/policy/value-drivers.yaml the first time anything touches BVP, and 'fw bvp arcs' silently returns empty because .context/arcs/ never gets created. The error message at lib/bvp.sh:133 also points consumers at 'fw bvp driver --init once T-1920 ships' — T-1920 shipped 2026-06-XX with the mutating verbs (weight/driver --add/--remove) but the --init flag was descoped or never built, so the error is a dead reference. Operator confirmed live: /opt/050-email-archive on a vendored 1.6.260 consumer hits this exact failure mode (12 task files carry bvp_scores frontmatter from upstream framework-dev leakage, not consumer scoring runs). Recommendation GO because: (a) bug is operator-confirmed and structural, every consumer hits it; (b) the fix shape is constrained enough to be evaluable now (idempotent bootstrap in fw init for greenfield + fw upgrade/vendor for adoption); (c) sovereignty-respecting because consumer can opt-out or override drivers post-bootstrap; (d) clean composition with T-1633/T-1635 consumer-fresh-machine simulation gate which would have caught this had it covered the BVP surface. Build slices to negotiate post-GO: (1) ship 'fw bvp driver --init' for explicit consumer bootstrap, (2) wire init/upgrade/vendor to call it idempotently, (3) seed .context/arcs/ directory with a README, (4) fix the stale error message, (5) consider an opt-out flag for projects that don't want BVP at all, (6) treat existing-codebase ingest (non-greenfield fw init) separately from upgrade. Spike A: regex audit of what 'policy/' and '.context/arcs/' references already exist in the upgrade/init code paths to identify all the surfaces that need the bootstrap call.

Evidence:

## Reviewer Verdict (v1.5)

- **Scan ID:** R-30359928
- **Timestamp:** 2026-06-06T12:29:25Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-3
     - evidence: `IW-3 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

### 2026-06-06T12:29:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
