---
id: T-2697
name: "tests/lint/ is wired into no runner and 7 of its invariant tests are red"
description: >
  tests/lint/ (7 invariant test files) is globbed by no runner: fw test unit/integration/governance
  target their own directories, and 'fw test lint' runs shellcheck — a name collision
  that made the orphaning invisible. 7 tests across 4 files are currently red, one
  since 2026-06-10 (T-2307 improved _self_vendor_libs from a lib/*.sh glob to a recursive
  find; the test pinned the old implementation shape rather than the invariant). Wire
  the directory into a runner, then triage each red test as a real regression or a
  test pinned to a shape that legitimately moved.

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
created: 2026-07-31T09:13:51Z
last_update: '2026-07-31T09:15:09Z'
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
  - ts: '2026-07-31T09:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-31T09:15:09Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2697: tests/lint/ is wired into no runner and 7 of its invariant tests are red

## Context

Found while running a test by hand for T-2696. `tests/lint/` holds 7 invariant test files —
the structural guards that exist precisely to catch drift nobody would notice — and **no
runner globs it**. `fw test unit|integration|governance` each target their own directory;
`fw test lint` runs **shellcheck**. That name collision is why the orphaning survived: the
verb that looks like it runs this directory does something else, and its output looks fine.

7 tests across 4 of the 7 files are red right now. One has been red since 2026-06-10.

The guards were built to prevent silent drift, and their own silence was the drift.

## Acceptance Criteria

### Agent
- [x] `tests/lint/` runs from a framework verb, and the verb's name does not collide with an
      existing one that means something else — `fw test invariants` (not `lint`, which is
      shellcheck and was the collision that hid this), plus a stage in `fw test all`
- [x] Each of the 7 red tests is triaged into exactly one of: **real drift** (the invariant
      is broken — file it), or **stale assertion** (the invariant holds but the test pinned
      an implementation shape that legitimately moved — fix the test)
- [x] Stale assertions are re-pointed at the **invariant**, not at the current shape, so the
      next legitimate refactor does not re-break them
- [x] Real drifts are filed as their own tasks with evidence — not fixed inline here, and not
      quietly absorbed to make the suite green
- [x] The suite is green **or** its remaining reds are traceable to a filed task, so wiring
      it in does not hand the next session an unexplained red
- [x] A guard catches the next orphaned test directory: adding `tests/<new>/` without a
      runner should not be able to sit unnoticed for 51 days again

## Triage — 7 reds, 1 stale assertion, 6 real drift

| test | verdict | disposition |
|------|---------|-------------|
| `single-vendor-writer` — self-vendor uses `lib/*.sh` glob | **stale assertion** | fixed here |
| `config-registry-parity` ×3 | real drift | **T-2698** |
| `help-router-parity` — router commands in `show_help` | real drift | **T-2699** |
| `no-bare-fw-in-gate-scripts` ×2 | real drift | **T-2700** |

**The stale one is the instructive case, and it fails in the flattering direction.** It
asserted the literal shape `_sv_src … lib/*.sh`. T-2307 and T-2455 replaced that
non-recursive glob with a recursive `find` covering `*.sh + *.py + *.md`, because the old
glob silently skipped 33 tracked `.md` siblings and 40 `.py` files including
`lib/reviewer/static_scan.py`. **The implementation got strictly better and the test went red
for it.** A test pinned to a mechanism punishes the refactor it exists to protect. Now
re-pointed at the invariant: the file set is *derived* (find or glob) and never *enumerated*.

## Negative controls

| control | mutation | result |
|---------|----------|--------|
| orphan guard | add `tests/newthing/` with a `.bats` and no runner | **red**, names the directory |
| wiring guard | — | passes only when the branch reaches bats and emits per-test lines |
| re-pointed self-vendor test | replace the `find` with a hardcoded 3-file list | **red** |

Two defects in my own guards, both caught by running the controls rather than reading them:

1. The first cut stripped only whole-line comments, so the mutation's trailing
   `# was: find "$FRAMEWORK_ROOT/lib"` satisfied the assertion and the control came back
   green. **L-519 applies to trailing comments, not only comment lines.** Now strips inline.
2. `enumerated=$(… | grep -c …)` under bats `set -e`: `grep -c` exits 1 on zero matches, so
   the *passing* case failed. Needs `|| true`.

And one in the wiring test itself: invoking `fw test invariants` bare from inside
`tests/lint/` re-runs the file that invokes it — it hung until killed. A guard that runs the
suite containing it needs a fixed point; it now names one other file explicitly.

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
# stdin on. `echo "$out"` is small and immediate; grep scans the whole captured
# string anyway, so the tail-3 was cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

out=$(timeout 120 bin/fw test invariants tests/lint/single-vendor-writer.bats 2>&1); echo "$out" | grep -q "Invariant Tests"
out=$(timeout 90 bats tests/lint/no-orphaned-test-dirs.bats 2>&1); echo "$out" | grep -q "^ok 1"
# `grep -qv` would pass on any single non-matching line — count instead.
test "$(timeout 90 bats tests/lint/single-vendor-writer.bats 2>&1 | grep -c '^not ok')" = "0"
test "$(timeout 90 bats tests/lint/no-orphaned-test-dirs.bats 2>&1 | grep -c '^not ok')" = "0"

## RCA

**Symptom:** 7 red tests in `tests/lint/`, one red since 2026-06-10, and nothing reported it.

**Root cause:** no runner globs `tests/lint/`. `fw test unit|integration|governance` each
target their own directory; `fw test all` composes those three plus pytest and playwright.
`tests/lint/` was in none of them.

**Why structurally allowed:** the obvious verb name was already taken by something else.
`fw test lint` means *shellcheck* — so the command an agent or operator would reach for to
run this directory returns green output about a different thing entirely. The collision did
not merely fail to run the tests; it actively reassured. And the failure direction is toward
green: a suite nobody runs cannot report a failure, so its silence is indistinguishable from
health. These are the framework's structural guards — the drift detectors — which makes this
the guard-of-guards blind spot.

**Prevention:** wired in under a non-colliding name (`fw test invariants`) and added to
`fw test all`, plus `tests/lint/no-orphaned-test-dirs.bats`, which fails whenever a
`tests/<dir>/` containing `.bats` files is not referenced by a runner in `bin/fw`. That
guard is directory-level, so it covers the next one somebody adds rather than only this
instance — and it strips comments before matching, so a note *explaining* an orphan cannot
satisfy it (L-519).

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

### 2026-07-31T09:13:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2697-testslint-is-wired-into-no-runner-and-7-.md
- **Context:** Initial task creation
