---
id: T-3064
name: "Workflow Designer is never installed by onboarding — consumers get a SKIP,
  not a designer"
description: >
  Workflow Designer is never installed by onboarding — consumers get a SKIP, not a
  designer

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-17T10:42:34Z
last_update: 2026-08-18T09:59:09Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-08-17T10:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=262,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-17T10:45:15Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3064: Workflow Designer is never installed by onboarding — consumers get a SKIP, not a designer

## Context

Make installing the Workflow Designer a standard part of onboarding, instead of
a manual step nobody runs.

**Measured state.** In this repo the designer is present and healthy — `fw
designer` reports `0.8.0`, `PRESENT ✓ (sha256 matches pin)`, vendored at
`vendor/designer/aef-workflow-designer-0.8.0.html`. Everywhere else it does not
exist:

| surface | designer? |
|---|---|
| `lib/setup.sh` (guided onboarding wizard) | no mention |
| `lib/init.sh` (`fw init`) | no mention |
| `agents/context/check-onboarding-gate.py` | no mention |
| `.agentic-framework/vendor/designer/` (what consumers receive) | **absent** |
| `fw upgrade` / `fw vendor self` | no `vendor/designer` reference at all |

So a consumer project onboarded today has `web/blueprints/designer.py` — which
resolves the artifact through `policy/designer-pin.yaml` `vendored_path` — and no
artifact behind it. `fw designer sync --from-tag` is the intake step (T-2616) and
nothing in any onboarding path calls it.

**Why it stayed invisible.** `fw doctor` reports the missing artifact as
`SKIP  designer not yet vendored`, not `WARN`. A SKIP reads as "not applicable
here", which is exactly the wrong reading — the designer *is* applicable, it is
just absent. Drift from the pin is a WARN; total absence is a SKIP. The louder
verdict is on the less serious condition, which is the same false-green shape as
T-3062's killed-vs-blocked push: the state that needs attention is the one
rendered as unremarkable.

**Constraint that shapes the fix (T-2521, T-559).** 832-Workflow-designer is the
single source of truth. AEF vendors a *released single-file build*, never source,
never edits the vendored copy, and verifies sha256 against the pin AND the
upstream MANIFEST at the same tag. Any onboarding step must go through
`fw designer sync`, must keep the sha256 verification, and must not weaken the
rejection-on-mismatch behaviour. An onboarding step that installs an *unverified*
designer is worse than no step.

**Found while scoping (2026-08-18), in scope for A2.** `.agentic-framework/policy/designer-pin.yaml`
is git-tracked in the vendored tree — committed by a wholesale resync under T-2992 —
so consumers do receive the pin. But `designer-pin.yaml` is **not** in
`_self_vendor_policy`'s explicit sync list (`lib/upgrade.sh:297`). The two copies are
byte-identical today purely by accident of that one resync; the next pin bump will not
propagate, and a consumer would then verify the correct artifact against a stale
sha256 and refuse it. Failing closed is the safe direction, but the symptom is "the
designer refuses to install" with no visible cause. The fix belongs with A2, since A2
is what makes the vendored pin load-bearing.

Related: arc-017 (`onboarding-curriculum`) owns the gated-set invariant — a task
added to the gated onboarding set must be agent-clearable. Whatever this adds has
to satisfy that, or sit outside the gate.

## Acceptance Criteria

### Agent
- [x] A1. The designer's absence is a WARN, not a SKIP, in `fw doctor`. Absence
      and pin-drift are both real conditions; today the less serious one is the
      louder one.
      *(bin/fw:1993 — WARN + actionable intake verb + warnings counter incremented.
      `doctor_designer_pin_drift.bats` t3 rewritten to assert the verdict on that
      line specifically; the first version asserted `*"WARN"*<message>*` over the
      whole output and a SKIP mutant survived it, because an earlier doctor check
      had already printed a WARN. Line-scoped form kills the mutant.)*
- [x] A2. Onboarding installs the designer — `fw init` and/or `fw setup` reach
      `fw designer sync` for a project that has none, and a freshly-onboarded
      project ends with the artifact present and sha256-verified against the pin.
      *(`fw vendor` ships the ONE pinned build — bin/fw:do_vendor; `fw vendor self`
      keeps `.agentic-framework/vendor/designer/` fresh — lib/upgrade.sh:_self_vendor_designer;
      `fw init` installs from it — lib/init.sh:fw_init_install_designer →
      `fw designer install` (agents/designer/designer.sh:do_install). Proven e2e:
      `fw init /tmp/t3064-e2e` ends with the artifact at PROJECT_ROOT and
      `fw designer status` reporting PRESENT ✓ sha256 matches pin. Note the path is
      `fw designer install`, NOT `fw designer sync` as the AC text guessed — sync's
      two modes are a delivered file and a network pull-at-tag; neither is what a
      consumer has. install reuses sync's verification, see A3.)*
- [x] A3. The sha256 verification and reject-on-mismatch behaviour is unchanged
      by the new call path. Proven by a deliberate mismatch that must still be
      refused — not by asserting the happy path.
      *(do_install does not re-implement verification — once it has located the
      vendored source it delegates to `do_sync --from`, so the comparison and the
      refusal are the same lines T-2521 shipped. t4/t5 in
      `tests/unit/t3064_designer_onboarding_install.bats` corrupt the vendored
      artifact and assert exit 1, the MISMATCH verdict LINE, and that nothing was
      written to the project. Mutant M4 — swap `do_sync --from` for a direct
      `_install_readonly` — turns both red.)*
- [x] A4. Offline / no-upstream is handled explicitly and visibly. Onboarding
      must not hang on an unreachable 832 remote, and must not silently finish
      claiming success with no artifact installed. State which behaviour was
      chosen and why in `## Decisions`.
      *(Chosen: onboarding never touches the network at all — see the A4 decision
      below. t6 asserts the absent-build case exits 5, writes nothing, and prints a
      line naming the artifact; mutants M5 (return 0) and M5b (drop the path from
      the message) each turn it red.)*
- [x] A5. Consumers reach the designer at all — decide and implement whether the
      artifact ships through `fw vendor self` into `.agentic-framework/` or is
      fetched per-project at onboarding, and record the reasoning. These have
      different blast radii (repo size and sha-provenance vs network dependency
      at install time); the choice is the deliverable, not an implementation
      detail.
- [x] A6. `tests/unit/upgrade_fresh_machine_simulation.bats` stays green — this
      touches `fw init`/`fw upgrade`, which is exactly the consumer-facing
      hygiene rule (T-1633).
      *(11/11 green after the change.)*
- [x] A7. Every load-bearing assertion is mutation-tested: the mutant turns it
      red, the unmutated suite is green (L-616).
      *(10 mutants, each killed, one per load-bearing assertion — log at
      `docs/reports/T-3064-mutation-log.md`. Run against a MIRROR of the tree, not
      the tree, and the driver refuses to report a mutant that failed to apply or
      was a no-op as "survived" — a mutation run that silently applies nothing is
      the same false-green shape this task is about.)*

**Integrator evidence (verified independently, not taken on the worker's report — 2026-08-18):**

- `tests/unit/t3064_designer_onboarding_install.bats` — 14/14 green on a re-run
  from this session. t4/t5 cover the refusal path (corrupted vendored build → exit
  1, MISMATCH named, nothing left in the project), t8 idempotence, t12–t14 the
  three distinct `fw init` renderings (installed-and-verified / refused / absent).
- A3 holds structurally rather than by re-assertion: `do_install` delegates to
  `do_sync --from`, so the sha256 comparison and its refusal are the lines T-2521
  shipped, not a second copy of them.
- A4 has no network anywhere in the onboarding path — the install reads the
  vendored copy. There is nothing to hang on and nothing to fail open.
- A5 is settled by the `## Decisions` entry above and implemented in the same
  change: `fw vendor` ships the one pinned build, `_self_vendor_designer` keeps
  `.agentic-framework/vendor/designer/` fresh, `fw designer install` installs it.
  Vendored artifact verified by hand: sha256 `cab3c751…0935`, matches the pin.
- A7: `docs/reports/T-3064-mutation-log.md` records 13 mutants, 13 killed. Spot-checked
  one independently — M6 (drop `designer-pin.yaml` from `_self_vendor_policy`'s sync
  list) reproduced live and killed t9; `lib/upgrade.sh` restored afterwards. The log
  also records the driver initially reporting three mutants as *survived* when they
  had never applied: a suite green because nothing was mutated is indistinguishable,
  in the driver's output, from a suite green because the assertion is weak. The
  driver now exits 2 unless the file provably changed — this task's own failure
  class, caught inside its own verification.
- The pin-drift defect found while scoping is fixed in the same change:
  `designer-pin.yaml` now appears in `_self_vendor_policy`'s sync list
  (`lib/upgrade.sh:306`), pinned by t9 and t10.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# A1 — the pinned-but-absent state is a WARN, not a SKIP. Asserted through the real
# doctor run rather than by grepping bin/fw, so the check has to actually reach that
# branch. Filtered to t3: the sibling cases each spawn a full ~2-minute doctor run.
bash -n bin/fw
timeout 500 bats tests/unit/doctor_designer_pin_drift.bats --filter "t3"

# A2/A3/A4/A7 — the onboarding install path: the pinned build reaches the vendored
# tree, install verifies it against the vendored pin, a corrupted build is REFUSED
# with nothing written, an absent build exits non-zero and says so, and the two
# live pin copies have not diverged. Guarded per T-2738: a bats run that prints
# "3 failed, 8 passed" satisfies a bare pass-marker grep, so the absence of any
# `not ok` is asserted too.
bash -n lib/upgrade.sh
bash -n agents/designer/designer.sh
out=$(bats tests/unit/t3064_designer_onboarding_install.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

# A6 — consumer-facing hygiene (T-1633). Same guard; ~3 min, it stands up real
# consumers against a real file:// upstream.
out=$(timeout 900 bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

## Decisions

### 2026-08-18 — A5: how the designer reaches a consumer

- **Chose:** vendor the **single pinned build** through `fw vendor self` into
  `.agentic-framework/vendor/designer/`, and have onboarding install from that
  vendored copy. `fw designer sync --from-tag` stays the intake/refresh path in the
  framework repo, not a step in consumer onboarding.
- **Why:**
  - The declaration is *already* vendored and the artifact is not.
    `.agentic-framework/policy/designer-pin.yaml` exists in every consumer today;
    `.agentic-framework/vendor/` does not exist at all. So a consumer already carries
    a pin naming a file it was never given — this closes an existing gap rather than
    opening a new channel.
  - **Offline onboarding keeps working (A4).** 832-Workflow-designer lives on an
    internal OneDev. Fetch-at-onboarding would make every `fw init` depend on a
    remote the consumer may have no route or credentials to, and the failure would
    land at install time — the exact hang-or-silently-succeed shape A4 forbids.
  - **Provenance survives without the network (A3).** The sha256 is in the vendored
    pin, so the consumer verifies the bytes it actually received, locally. The
    stronger check (independent sha256 vs the MANIFEST *at the tag* AND the pin)
    still happens once, at intake in the framework repo, where the remote is
    reachable — verification is not weakened, it is performed where it can be.
- **Rejected:** fetch-at-onboarding (`--from-tag` during `fw init`). Turns an
  install-time network round-trip into a hard dependency for every consumer, and
  puts the one path that *can* fail-open squarely in the path that must not.
- **Rejected:** vendoring `vendor/designer/` wholesale. That directory holds nine
  historical builds totalling ~7.7 MB, of which exactly one (0.8.0) is pinned. Only
  the pinned build ships; the rest are framework-repo history.
- **Blast radius — I got this wrong, corrected 2026-08-18.** I wrote that A1's
  SKIP→WARN would make every consumer start reporting a WARN before the vendoring
  reached them, and called that an accepted fleet-visible cost. It will not happen,
  and the reason matters: doctor resolves the pin as
  `${FW_DESIGNER_PIN_FILE:-$PROJECT_ROOT/policy/designer-pin.yaml}` (`bin/fw`), but a
  consumer's pin lives at `.agentic-framework/policy/designer-pin.yaml`. The
  enclosing `if [ -f "$_dz_pin" ]` is therefore false in every consumer and the check
  does not run at all — verdict SKIP or WARN alike. **A1 is framework-repo-only.**
  Surfaced by the dispatched worker (bus R-001, item 3), verified against `bin/fw`
  directly rather than taken on report.

  So the honest statement is the inverse of what I wrote: the condition A1 was
  written to make loud is precisely the condition consumers are in, and they are the
  one population that cannot see it. Not in scope here — the fix means editing the
  doctor block this dispatch deliberately fenced off — but it is the difference
  between "the rail is louder" and "the rail is louder where it was never quiet".
  Its own task.


### 2026-08-18 — A4: what onboarding does when the designer cannot be installed

- **Chose:** onboarding **never reaches the network**, and every outcome prints a
  line. `fw init` calls `fw designer install`, which reads the build out of the
  consumer's own `.agentic-framework/vendor/designer/` and verifies its sha256
  against the vendored pin. `fw designer sync --from-tag` — the one verb that
  contacts 832's internal OneDev — is not reachable from any onboarding path.
- **Why:** "must not hang on an unreachable remote" is answered structurally
  rather than by a timeout, because there is no remote in the path to hang on. A
  timeout would still have to pick a number, and picking one wrong is how an
  install step becomes a two-minute stall on a machine with no route to 192.168.10.201.
- **The other half, which is the one that actually needed deciding:** an absent
  vendored build must not read like success. `do_install` exits **5** (not 0) and
  names the artifact, the reason, and the fix; `fw_init_install_designer` renders
  that as a `⚠` line and a sha256 refusal as a `✗ REFUSED — nothing was installed`
  line, so "the step ran" and "the designer is installed" cannot be confused.
- **Init is not failed by any of this.** A project without a designer is still a
  governed project; failing onboarding over an optional editor would be a worse
  trade than the one this task is fixing. What changed is that the absence is now
  *stated* at the moment it happens, instead of being discovered later as an error
  page at `/designer`.
- **Rejected:** fetch-on-miss (try the vendored copy, fall back to `--from-tag`).
  It reintroduces the network dependency for exactly the consumers least likely to
  have the route, and it makes the failure mode timing-dependent — the worst kind
  to reproduce.
- **Rejected:** hard-failing `fw init` on a missing designer. That converts an
  advisory gap into an onboarding blocker for every consumer whose framework copy
  predates this change.

### 2026-08-18 — Found during A2: designer-pin.yaml was not in the self-vendor set

- **Not original scope.** `.agentic-framework/policy/designer-pin.yaml` is
  git-tracked (wholesale resync under T-2992), so consumers do receive the pin —
  but `designer-pin.yaml` was absent from `_self_vendor_policy`'s explicit list
  (`lib/upgrade.sh`). The two copies were byte-identical purely by accident of that
  one resync.
- **Why it had to be fixed here:** A2 is what makes the vendored pin load-bearing.
  Before A2 a stale vendored pin was inert; after A2 it is the thing a consumer
  verifies received bytes against. The next pin bump would have moved
  `policy/designer-pin.yaml`, left the vendored copy behind, and made every
  consumer reject the correct artifact against a stale sha256. Failing closed is
  the safe direction — the symptom would have been "the designer refuses to
  install" with no visible cause.
- **Fix:** added to the sync list; parity pinned by t9 (helper syncs it) and t10
  (the two live copies are identical) in
  `tests/unit/t3064_designer_onboarding_install.bats`. Mutants M6 and M8 kill them.


<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-17T10:42:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3064-workflow-designer-is-never-installed-by-.md
- **Context:** Initial task creation
