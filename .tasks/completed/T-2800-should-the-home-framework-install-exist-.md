---
id: T-2800
name: "should the $HOME framework install exist at all, or is the router plus per-project
  vendoring enough (D-377 total isolation)"
description: >
  Inception: should the $HOME framework install exist at all, or is the router plus
  per-project vendoring enough (D-377 total isolation)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [tests/unit/install_verify_no_cwd_init.bats]
related_tasks: []
created: 2026-08-04T20:34:56Z
last_update: 2026-08-04T21:16:51Z
date_finished: 2026-08-04T21:16:51Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-04T20:36:22Z'
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
  - ts: '2026-08-04T20:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2800: should the $HOME framework install exist at all, or is the router plus per-project vendoring enough (D-377 total isolation)

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

- **IW-1: Must `fw init` work with no network?**
  This is the hinge. `$HOME/.agentic-framework` exists so `fw init` has framework bytes
  to vendor without reaching GitHub. If offline init is not required, the $HOME
  framework can go entirely; if it is, something must hold bytes locally — but that
  something can be an inert cache rather than an installed, runnable framework.
  confidence: 3
  disposition: dissolved
  rationale: The question presumed local bytes are the only offline answer. Operator's
    counter (dialogue round 2, Q3/Q4) — an alternate remote — covers LAN mirror and
    true air-gap alike via `--from <url|path|tarball>`, and `.framework.yaml` already
    carries `upstream_repo:`. No $HOME bytes needed either way.

- **IW-2: Should bare `fw`, outside any project, do anything at all?**
  Today the router falls back to the $HOME install and announces it — that is the
  "no project found above … using global install" line. The alternative is refusing
  with instructions. Refusal removes a whole class of "which framework just ran?"
  confusion, at the cost of `fw init` needing its own bootstrap path.
  confidence: 3
  disposition: answered
  rationale: Refuse with instructions. With no framework in $HOME there is nothing to
    fall back TO, so the fallback branch has no referent — the answer follows from
    IW-1 rather than being a separate preference.

- **IW-3: Should install and init be one step or two?**
  Operator's position (2026-08-04): the installer should set up the directory it is
  called in. Today they are separate and the installer's own closing message says so,
  while its self-test inits the cwd anyway. Merging them is coherent with total
  isolation; keeping them separate is coherent with "install the tool once".
  confidence: 3
  disposition: answered
  rationale: One command per project — and it is FORCED, not chosen. `fw init` is
    framework code, so on a fresh machine nothing can execute it unless the standalone
    installer does (dialogue round 3, exits a/b/c). "No framework in $HOME" REQUIRES
    "the installer sets up the directory you call it in"; the two operator positions
    are one decision. See docs/reports/T-2800-home-install-architecture.md.

- **IW-4: What breaks if `$HOME/.agentic-framework` disappears?**
  Unknown until surveyed. `fw upgrade` syncs to it (L-172), `fw doctor` probes it, the
  router falls back to it, consumer recovery paths reference it. This is a survey, not
  a judgement — it bounds the cost of IW-1/IW-2 rather than answering them.
  confidence: 0
  disposition: deferred
  rationale: Deliberately unanswered — the survey has not run, and running it inside
    this inception would be building, not exploring. It bounds migration cost, so it
    gates the first build slice rather than the GO decision. Naming it deferred rather
    than guessing is the point.

- **IW-5: What promotes a commit into the `stable` channel?**
  Raised in dialogue round 4. A channel that promises stability without gating for it
  is the false-green shape of this whole session under a friendlier name; our tags are
  cut mechanically (`v1.6.764` is 137 commits back, nothing gated it).
  confidence: 3
  disposition: answered
  rationale: Operator chose option 1 — the operator cuts it via `fw release`. Not
    gating on the test suite yet, because it has known reds and files no runner globs
    (OBS-145, T-2696); trusting that green would repeat the session's central mistake.
    Dogfood soak (option 3) is the target once consumer telemetry exists.

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

The $HOME framework is the common factor in T-2793 (split brain), T-2796 (incomparable versions) and T-2797 (Step 2 reads the global), and it is the source of the router's 'using global install' fallback message. D-377 already decided total isolation; T-2793 delivered it for the CLI but left the global framework in place as a bootstrap seed. Recommend GO on removing it: keep the ~100-line router as the only machine-wide artifact, have the installer fetch framework bytes into the target project, and make the router refuse-with-instructions instead of falling back. Needs a spike on the bootstrap path before building.

Four dialogue rounds refined it. The operator's original proposal ("init always pulls
latest online, nothing in $HOME") survived every objection the agent raised, and two of
the operator's counters produced a better design than the agent had proposed: exact-ref
pinning dissolved the reproducibility objection, and a stable/edge channel model
resolved the "every new project is a canary" objection without a default that annoys
experienced users. The bootstrap constraint turned out not to be a refutation but a
consequence — it forces install and init to become one command per project, which is
the operator's own earlier position, arrived at from the other direction.

**Evidence:**

- **352 MB in `$HOME`, of which 169 MB is `.git`** — measured on a fresh install from
  GitHub master under an isolated HOME (2026-08-04), seeding a 28 MB per-project
  vendor. The router that would replace it is 5.5 KB.
- **Four defects this session trace to the $HOME install** — T-2793 (split brain),
  T-2796 (incomparable version counters, 1.6.432 read as newer than 1.6.132), T-2797
  (Step 2 reads the global and recommends skipping), plus the stale-global lag that
  produced all three.
- **`upstream_repo:` and `version_sha:` already exist** in `.framework.yaml` — the
  alternate-source and exact-pin legs are wiring, not new design.
- **The installer already inits the caller's cwd** (`fw doctor` in step 3, output
  swallowed by `&>/dev/null`, reported as a green check) — reproduced live. Under this
  architecture that behaviour becomes the installer's declared purpose; T-2799 fixes
  the unannounced version of it, and that fix is correct under every option here.
- **Full reasoning and dialogue log:** `docs/reports/T-2800-home-install-architecture.md`

**Known gap, stated rather than hidden:** IW-4 (what depends on
`$HOME/.agentic-framework`) is unsurveyed. It bounds migration cost, so it gates the
first build slice — not this decision. Existing installs must keep working; this
changes how new projects are created.

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

**Rationale**: The $HOME framework is the common factor in T-2793 (split brain), T-2796 (incomparable versions) and T-2797 (Step 2 reads the global), and it is the source of the router's 'using global install' fallback message. D-377 already decided total isolation; T-2793 delivered it for the CLI but left the global framework in place as a bootstrap seed. Recommend GO on removing it: keep the ~100-line router as the only machine-wide artifact, have the installer fetch framework bytes into the target project, and make the router refuse-with-instructions instead of falling back. Needs a spike on the bootstrap path before building.

Four dialogue rounds refined it. The operator's original proposal ("init always pulls
latest online, nothing in $HOME") survived every objection the agent raised, and two of
the operator's counters produced a better design than the agent had proposed: exact-ref
pinning dissolved the reproducibility objection, and a stable/edge channel model
resolved the "every new project is a canary" objection without a default that annoys
experienced users. The bootstrap constraint turned out not to be a refutation but a
consequence — it forces install and init to become one command per project, which is
the operator's own earlier position, arrived at from the other direction.

**Date**: 2026-08-04T21:16:51Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-04T20:36:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-04T21:16:51Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** The $HOME framework is the common factor in T-2793 (split brain), T-2796 (incomparable versions) and T-2797 (Step 2 reads the global), and it is the source of the router's 'using global install' fallback message. D-377 already decided total isolation; T-2793 delivered it for the CLI but left the global framework in place as a bootstrap seed. Recommend GO on removing it: keep the ~100-line router as the only machine-wide artifact, have the installer fetch framework bytes into the target project, and make the router refuse-with-instructions instead of falling back. Needs a spike on the bootstrap path before building.

Four dialogue rounds refined it. The operator's original proposal ("init always pulls
latest online, nothing in $HOME") survived every objection the agent raised, and two of
the operator's counters produced a better design than the agent had proposed: exact-ref
pinning dissolved the reproducibility objection, and a stable/edge channel model
resolved the "every new project is a canary" objection without a default that annoys
experienced users. The bootstrap constraint turned out not to be a refutation but a
consequence — it forces install and init to become one command per project, which is
the operator's own earlier position, arrived at from the other direction.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3ece300f
- **Timestamp:** 2026-08-04T21:16:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-27dec2cb
- **Timestamp:** 2026-08-04T21:16:53Z
- **Overall:** CONFIRMED
- **Claims:** 5

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-2800-home-install-architecture.md` | file | ✓ pass |
| `T-2793` | task | ✓ pass |
| `T-2796` | task | ✓ pass |
| `T-2797` | task | ✓ pass |
| `T-2799` | task | ✓ pass |

### 2026-08-04T21:16:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
