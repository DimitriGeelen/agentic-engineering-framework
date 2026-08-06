---
id: T-2844
name: "fw init leaves a cron registry its own doctor calls ungenerated"
description: >
  fw init leaves a cron registry its own doctor calls ungenerated

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
created: 2026-08-06T22:36:25Z
last_update: '2026-08-06T22:45:10Z'
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
  - ts: '2026-08-06T22:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T22:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=1 (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2844: fw init leaves a cron registry its own doctor calls ungenerated

## Context

`fw init` into an empty directory, then `fw doctor` in that directory:

```
WARN  Cron registry present but not generated — run: fw cron install
```

A project seconds old is already reporting drift it did nothing to cause. Sibling
to T-2740 (greenfield seed tasks failed `fw audit` on day zero) and to T-2843
(day-zero path-ambiguity WARN, fixed) — the same class on a third surface: `fw init`
seeds state that a downstream check immediately reads as stale.

This is the last remaining project-scope WARN on a greenfield project. After
T-2843, `fw doctor` on a fresh install reports 4 WARNs, of which two are
`[host]`-scoped (git identity, global install size) and one is
session-environmental (unsupervised session). This is the only one the framework
both causes and complains about.

Why it matters beyond tidiness: CLAUDE.md documents cron drift as a three-stage
chain (registry → generated → deployed) with a mandatory Verification command for
any cron-touching task. A brand-new project starts in stage-1 drift, so the
day-zero state of every consumer is indistinguishable from the failure the chain
exists to detect. The operator hit exactly this on their by-hand onboarding run.

**Open question for the fix (resolve before choosing a mechanism):** should
`fw init` generate the cron artefacts, or should it not seed a registry until the
operator opts in? Generating implies installing crontab entries on the host at
init time, which is a side effect outside the project directory and may not be
wanted. Not seeding means the registry appears later, on first `fw cron` use.
Doctor's own advice (`run: fw cron install`) presumes the first.

## Acceptance Criteria

### Agent
- [x] Root cause identified: which init step seeds `.context/cron-registry.yaml`, and why nothing generates from it
- [x] Decision recorded in `## Decisions` on generate-at-init vs seed-on-demand, with the host-side-effect trade-off stated
- [x] `fw init` into an empty directory followed by `fw doctor` emits no cron-related WARN
- [x] Genuine registry→generated drift (edit the registry, don't regenerate) still WARNs — the check keeps the purpose T-1942 gave it
- [x] Regression test committed covering both the greenfield-quiet and drift-still-detected cases, green
- [x] `fw audit` fixed in parity with `fw doctor` — the same defect emitted from both surfaces

**Live evidence** (real `fw init` into an empty directory, then the real checkers):

| Surface | Registry state | Verdict |
|---|---|---|
| `fw doctor` | `jobs: []` (as seeded) | `SKIP  registry declares no jobs (nothing to generate)` |
| `fw doctor` | one job added, not generated | `WARN  Cron registry present but not generated` |
| `fw audit` | `jobs: []` (as seeded) | `INFO  registry declares no jobs (nothing to generate)` |
| `fw audit` | one job added, not generated | `WARN  Cron drift: registry present but not generated` |

Greenfield `fw doctor` WARN count: **4 → 3**, and all three remaining are
`[host]`-scoped or session-environmental. Combined with T-2843 (5 → 4), a freshly
initialised project now reports **zero project-scope warnings**.

**Observed, not fixed here:** greenfield `fw audit` also emits
`WARN CTL-020: No cron audit files in last hour`, which is the same day-zero class
on a third surface — a project minutes old cannot have an hour of audit history.
Left out of scope deliberately (one bug, one task); noted so it is not lost.

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
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

out=$(bats tests/unit/t2844_cron_registry_job_count.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Both cron-touching surfaces were edited, so the CLAUDE.md L-364 cron gate applies.
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"

## RCA

**Symptom:** `fw init` into an empty directory, then `fw doctor` — a project
seconds old reports `WARN Cron registry present but not generated`. `fw audit`
reports the same finding independently.

**Root cause:** The registry→generated→deployed drift checks were gated on the
registry *file existing*, never on it *declaring any jobs*. `fw init` seeds
`jobs: []`; an empty registry has no generated form, so the absence of
`.context/cron/agentic-audit.crontab` is the correct end state rather than drift.
The checks conflated "nothing to generate" with "something to generate that was
not generated".

**Why structurally allowed:** The three-leg cron chain was built incrementally
against real drift incidents — T-1771 (generated→deployed), T-1942/T-1943
(registry→generated, after a job sat undeployed 3+ days). Every one of those was
diagnosed on a *populated* registry, where file-existence and job-existence
coincide, so the distinction never had to be drawn. The empty case only appears
at init, and no suite asserted anything about a freshly initialised project's
doctor output. T-2740 had already fixed the same class for `fw audit`'s seed
tasks — the pattern was known; this surface just wasn't looked at.

**Prevention:** The predicate lives in `lib/cron-registry.sh` with a bats suite
that pins the empty, missing-key, null, populated and malformed cases. The
malformed case is load-bearing: it must return -1 rather than 0, or an unreadable
registry would silently skip drift detection — swapping a false positive for a
false negative, which is the worse trade. Both emitters now share the one
predicate, so the surfaces cannot drift apart again (L-399 producer/consumer
parity).

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

## Decisions

### 2026-08-07 — the filed question had a wrong premise

- **Chose:** Neither generate-at-init nor seed-on-demand. Fix the *checker*, not
  `fw init`.
- **Why:** The Context section above framed this as "should init generate the
  cron artefacts, or not seed a registry at all", and both options presume there
  is something to generate. Inspecting the seeded file settled it: the registry
  contains `jobs: []`. There is no work declared, so `fw cron generate` correctly
  produces nothing, and the missing crontab is the right end state. `fw init` is
  behaving correctly; the drift checks were asking the wrong question. Leaving
  the framing uncorrected would have shipped a fix to a component that had no bug.
- **Rejected — generate at init:** would install crontab entries on the host
  during `fw init`, a side effect outside the project directory that the operator
  has not asked for. Doctor's own advice (`run: fw cron install`) implies this and
  is misleading on an empty registry. That advice is now unreachable when the
  registry is empty, which is the point.
- **Rejected — don't seed a registry:** the seeded file is a useful, documented
  template (it carries the header comments explaining what the file is for) and
  Watchtower's cron page reads it. Removing it to silence a checker bug would
  trade a real affordance for a cosmetic win.
- **Also decided — malformed returns -1, not 0:** so an unparseable registry
  keeps warning instead of silently skipping the drift checks. "We could not tell"
  must not read the same as "we checked and it was fine".

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-06T22:36:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2844-fw-init-leaves-a-cron-registry-its-own-d.md
- **Context:** Initial task creation
